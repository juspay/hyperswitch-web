import { test, expect, paymentBody } from "../fixtures";
import { SDK_URL, CLIENT_BASE_URL } from "../fixtures/env";
import { load } from "./contract.cjs";
import { sha256 } from "../required-fields-sync/contract.cjs";
const request = load(process.env.RF_VERIFIER_INPUT);
async function evidence(value: unknown) {
  test
    .info()
    .annotations.push({
      type: "observation",
      description: sha256(JSON.stringify(value)),
    });
}
test.beforeEach(async ({ context, mode, browser }) => {
  expect(mode).toBe("hermetic");
  test
    .info()
    .annotations.push({
      type: "browser-version",
      description: browser.version(),
    });
  await context.route("**/*", (route) => {
    const u = new URL(route.request().url());
    if (route.request().method() === "POST" && /\/confirm$/.test(u.pathname))
      return route.abort();
    if (u.pathname.startsWith("/assets/v1/jsons/location/"))
      return route.fulfill({ status: 404, body: "synthetic unavailable" });
    if (
      [SDK_URL, CLIENT_BASE_URL, process.env.RF_FIXTURE_ORIGIN].includes(
        u.origin,
      )
    ) {
      if (
        route.request().method() !== "GET" ||
        (u.pathname.startsWith("/payments") &&
          !["/payments/config", "/payments/urls"].includes(u.pathname))
      )
        return route.abort();
    }
    return route.fallback();
  });
});
for (const [i, c] of request.input.cases.entries()) {
  test(`B-response-${i} actual constructor aggregation and component rendering`, async ({
    browser,
  }) => {
    const context = await browser.newContext({ serviceWorkers: "block" });
    try {
      await context.route("**/*", (r) =>
        new URL(r.request().url()).origin === process.env.RF_FIXTURE_ORIGIN &&
        r.request().method() === "GET"
          ? r.continue()
          : r.abort(),
      );
      const p = await context.newPage();
      await p.goto(process.env.RF_FIXTURE_ORIGIN!);
      await p.waitForFunction(() => !!(window as any).rf);
      await p.evaluate(
        (c: any) =>
          (window as any).rf.mount({
            ...c.input,
            response: JSON.parse(c.response_utf8),
          }),
        c,
      );
      await expect(p.locator("#probe")).toBeVisible();
      const snapshot = await p.evaluate(() => (window as any).rf.snapshot());
      expect(snapshot.context).toEqual(c.expected.context);
      expect(snapshot.connectors).toEqual(c.expected.connectors);
      expect(snapshot.descriptors).toHaveLength(1);
      expect(snapshot.descriptors[0].confirmRequestWritePath).toBe(
        c.expected.path,
      );
      expect(snapshot.descriptors[0].defaultLabelText).toBe(c.expected.label);
      await expect(p.locator('input[name="line1"]')).toBeVisible();
      await evidence({
        snapshot,
        rendered: await p.locator("#root").innerText(),
      });
    } finally {
      await context.close();
    }
  });
  test(`E-response-${i} exact response validation and intercepted checkout payload`, async ({
    context,
    hermetic,
    checkout,
    sdk,
    page,
  }) => {
    let served = 0;
    await context.route("**/v1/sdk/configs/**", (route) => {
      served++;
      return route.fulfill({
        status: 200,
        contentType: "application/json",
        body: c.response_utf8,
      });
    });
    hermetic.override("clientList", c.input.client);
    await checkout.open({ body: paymentBody({ billing: undefined }) });
    await sdk.waitForReady();
    expect(served).toBeGreaterThan(0);
    await expect(sdk.text(c.expected.label)).toBeVisible();
    await sdk.enterCardDetails({
      cardNo: "4242424242424242",
      card_exp_month: "12",
      card_exp_year: "30",
      cvc: "123",
    });
    await sdk.field("line1").focus();
    await sdk.field("line1").blur();
    await expect(sdk.text("This field is mandatory")).toBeVisible();
    await sdk.submit();
    await expect(page.locator("#payment-message")).toHaveText(
      "Please enter valid details",
    );
    await expect(sdk.submitButton).toBeEnabled();
    expect(hermetic.calls("confirm")).toEqual([]);
    await sdk.field("line1").fill(c.expected.value);
    const sent = page.waitForRequest(
      (r) =>
        r.method() === "POST" && /\/confirm$/.test(new URL(r.url()).pathname),
    );
    await sdk.submit();
    const body = (await sent).postDataJSON();
    expect(body.payment_method).toBe("card");
    expect(body.payment_method_data).toEqual({
      card: {
        card_number: "4242424242424242",
        card_exp_month: "12",
        card_exp_year: "2030",
        card_cvc: "123",
        card_network: "Visa",
      },
      billing: { address: { line1: c.expected.value } },
    });
    expect(hermetic.calls("confirm")).toEqual([]);
    await evidence({
      response: c.response_sha256,
      input: c.input_sha256,
      body,
      validation: "required-before-confirm",
      served,
    });
  });
}
test("E-retained existing checkout retains old response while new checkout gets current response", async ({
  context,
  checkout,
  sdk,
  page,
}) => {
  const [before, after] = request.input.cases;
  let body = before.response_utf8;
  await context.route("**/v1/sdk/configs/**", (route) =>
    route.fulfill({ status: 200, contentType: "application/json", body }),
  );
  await checkout.open({ body: paymentBody({ billing: undefined }) });
  await sdk.waitForReady();
  await expect(sdk.text(before.expected.label)).toBeVisible();
  body = after.response_utf8;
  await sdk.field("line1").fill("retained synthetic input");
  await expect(sdk.text(before.expected.label)).toBeVisible();
  await expect(sdk.text(after.expected.label)).toHaveCount(0);
  await page.reload();
  await sdk.waitForReady();
  await expect(sdk.text(after.expected.label)).toBeVisible();
  await expect(sdk.text(before.expected.label)).toHaveCount(0);
  await evidence({
    retained: before.response_sha256,
    fresh: after.response_sha256,
  });
});
