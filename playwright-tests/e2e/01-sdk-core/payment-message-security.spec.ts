import type { Locator, Page } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  slowConfirm,
  expectConfirmedWith,
  PAYMENT_ELEMENT_IFRAME,
  CARD_FIELDS_IFRAME,
  CLIENT_BASE_URL,
  SDK_URL,
  connectorEnum,
  juspayChallengeTestCard,
} from "../../fixtures";

declare global {
  interface Window {
    paymentSecuritySubmitCount: number;
    paymentSecurityRelayedFields: string[][];
  }
}

const body = paymentBody({
  customer_id: "payment_message_security_user",
  authentication_type: "no_three_ds",
});

type SecondaryElement = "split-card" | "payment-management";
type MountableElement = { mount(selector: string): void };
type SecurityTestHyper = {
  elements(options: { clientSecret: string }): {
    createCardForm(): {
      create(type: string, options: Record<string, unknown>): MountableElement;
    };
  };
  paymentMethodsManagementElements(options: { sdkAuthorization: string }): {
    create(type: string, options: Record<string, unknown>): MountableElement;
  };
};

async function mountSecondaryElement(
  page: Page,
  clientSecret: string,
  kind: SecondaryElement,
): Promise<{ id: string; selector: string }> {
  const id = `payment-security-${kind}`;
  await page.evaluate(
    ({ id, clientSecret, kind }) => {
      const mount = document.createElement("div");
      mount.id = id;
      document.body.appendChild(mount);
      const hyper = (window as unknown as { HyperMethod: SecurityTestHyper })
        .HyperMethod;
      const element =
        kind === "split-card"
          ? hyper
              .elements({ clientSecret })
              .createCardForm()
              .create("cardNumber", {})
          : hyper
              .paymentMethodsManagementElements({
                sdkAuthorization: btoa(
                  "payment_method_session_id=pms_payment_message_security",
                ),
              })
              .create("paymentMethodsManagement", {});
      element.mount(`#${id}`);
    },
    { id, clientSecret, kind },
  );
  const prefix =
    kind === "split-card"
      ? "payment-element"
      : "payment-methods-management-element";
  const selector = `#orca-${prefix}-iframeRef-${id}`;
  await expect(page.locator(selector)).toHaveCount(1);
  await expect
    .poll(() =>
      page
        .frames()
        .find((frame) => frame.name() === selector.slice(1))
        ?.url(),
    )
    .toContain(`${SDK_URL}/index.html`);
  await expect(page.frameLocator(selector).locator("body")).toBeAttached();
  return { id, selector };
}

// A message-port round trip observes delivery without relying on a timed sleep.
async function sendFromSibling(
  page: Page,
  sender: Locator,
  payload: Record<string, unknown>,
): Promise<void> {
  const frameIndex = await page
    .locator(PAYMENT_ELEMENT_IFRAME)
    .evaluate((el) =>
      Array.from(window.frames).indexOf(
        (el as HTMLIFrameElement).contentWindow!,
      ),
    );
  await sender.evaluate(
    async (_el, { payload, frameIndex }) => {
      const barrier = (target: Window) =>
        new Promise<void>((resolve) => {
          const channel = new MessageChannel();
          channel.port1.onmessage = () => {
            channel.port1.close();
            resolve();
          };
          target.postMessage({ paymentSecurityBarrier: true }, "*", [
            channel.port2,
          ]);
        });
      window.parent.postMessage(payload, "*");
      await barrier(window.parent);
      await barrier(window.parent.frames[frameIndex]);
    },
    { payload, frameIndex },
  );
}

async function addSibling(page: Page, origin: string): Promise<Locator> {
  const url = `${origin}/payment-security-sender.html`;
  await page.route(url, (route) =>
    route.fulfill({
      contentType: "text/html",
      body: "<!doctype html><body>Sender</body>",
    }),
  );
  await page.evaluate((url) => {
    const iframe = document.createElement("iframe");
    iframe.id = "payment-security-sender";
    iframe.src = url;
    document.body.appendChild(iframe);
  }, url);
  const sender = page.frameLocator("#payment-security-sender").locator("body");
  await expect(sender).toHaveText("Sender");
  return sender;
}

test.describe("Payment message sender validation @hermetic-only", () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      window.paymentSecuritySubmitCount = 0;
      window.addEventListener("message", (event) => {
        let data = event.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (data?.paymentSecurityBarrier) event.ports[0]?.postMessage(true);
        if (data?.doSubmit === true) window.paymentSecuritySubmitCount++;
      });
    });
  });

  for (const [name, origin] of [
    ["foreign-origin", "https://untrusted.example.test"],
    ["SDK-origin", SDK_URL],
  ]) {
    test(`rejects SDK confirmation from an unregistered ${name} sibling`, async ({
      checkout,
      sdk,
      page,
      hermetic,
    }) => {
      await checkout.open({ body, waitForReady: true });
      await sdk.enterCardDetails(stripeCards.successCard);
      const sender = await addSibling(page, origin);
      slowConfirm(hermetic, 2_000);

      await sendFromSibling(page, sender, {
        handleSdkConfirm: { confirmParams: { return_url: CLIENT_BASE_URL } },
      });

      expect(
        await sdk.paymentElement
          .locator("body")
          .evaluate(() => window.paymentSecuritySubmitCount),
      ).toBe(0);
      expect(hermetic.calls("confirm")).toHaveLength(0);

      slowConfirm(hermetic, 0);
      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible();
      await expectConfirmedWith(hermetic, stripeCards.successCard.cardNo);
    });
  }

  test("rejects confirmation with the registered iframe source but a different origin", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    await checkout.open({ body, waitForReady: true });
    await page.evaluate((selector) => {
      const iframe = document.querySelector<HTMLIFrameElement>(selector)!;
      window.dispatchEvent(
        new MessageEvent("message", {
          source: iframe.contentWindow,
          origin: "https://untrusted.example.test",
          data: {
            handleSdkConfirm: {
              confirmParams: { return_url: location.origin },
            },
          },
        }),
      );
    }, PAYMENT_ELEMENT_IFRAME);

    expect(
      await sdk.paymentElement
        .locator("body")
        .evaluate(() => window.paymentSecuritySubmitCount),
    ).toBe(0);
    expect(hermetic.calls("confirm")).toHaveLength(0);
  });

  test("rejects card submission from the parent window with a different origin", async ({
    checkout,
    sdk,
  }) => {
    await checkout.open({ body, waitForReady: true });
    await sdk.paymentElement.locator("body").evaluate(async (_el, selector) => {
      window.dispatchEvent(
        new MessageEvent("message", {
          source: window.parent,
          origin: "https://untrusted.example.test",
          data: JSON.stringify({ doSubmit: true }),
        }),
      );
      const inner = document.querySelector<HTMLIFrameElement>(selector)!;
      await new Promise<void>((resolve) => {
        const channel = new MessageChannel();
        channel.port1.onmessage = () => {
          channel.port1.close();
          resolve();
        };
        inner.contentWindow!.postMessage(
          { paymentSecurityBarrier: true },
          "*",
          [channel.port2],
        );
      });
    }, CARD_FIELDS_IFRAME);

    expect(
      await sdk.cardFields
        .locator("body")
        .evaluate(() => window.paymentSecuritySubmitCount),
    ).toBe(0);
  });

  test("ignores forged submit results while a legitimate payment is pending", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    await checkout.open({ body, waitForReady: true });
    await sdk.enterCardDetails(stripeCards.successCard);
    const sender = await addSibling(page, "https://untrusted.example.test");
    slowConfirm(hermetic, 2_000);
    const confirmRequest = page.waitForRequest(
      (request) =>
        request.method() === "POST" &&
        /\/payments\/[^/]+\/confirm$/.test(new URL(request.url()).pathname),
    );
    await sdk.submit();
    await confirmRequest;

    await sendFromSibling(page, sender, {
      submitSuccessful: true,
      data: { status: "succeeded" },
    });

    await expect(sdk.submitButton).toBeDisabled();
    await expect(page.getByText("Thanks for your order!")).not.toBeVisible();
    await expect(page.getByText("Thanks for your order!")).toBeVisible();
  });

  test("accepts confirmation from the genuine SDK pay button", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    const returnUrl = `${CLIENT_BASE_URL}/payment-security-complete`;
    await page.route(`${returnUrl}**`, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: "<!doctype html><body>SDK payment completed</body>",
      }),
    );
    await checkout.open({
      body,
      waitForReady: true,
      options: {
        sdkHandleConfirmPayment: {
          handleConfirm: true,
          buttonText: "Pay securely",
          confirmParams: { return_url: returnUrl },
        },
      },
    });
    await sdk.enterCardDetails(stripeCards.successCard);
    await sdk.paymentElement
      .getByRole("button", { name: "Pay securely", exact: true })
      .click();

    await expect(page.getByText("SDK payment completed")).toBeVisible();
    await expectConfirmedWith(hermetic, stripeCards.successCard.cardNo);
  });

  test("rejects untrusted polling instructions before they can relay a result", async ({
    checkout,
    page,
  }) => {
    await checkout.open({ body, waitForReady: true });
    const sender = await addSibling(page, "https://untrusted.example.test");
    const retrievals: string[] = [];
    page.on("request", (request) => {
      if (
        request.method() === "GET" &&
        /\/payments\/pay_[^/]+$/.test(new URL(request.url()).pathname)
      ) {
        retrievals.push(request.url());
      }
    });

    await sendFromSibling(page, sender, {
      openurl_if_required: CLIENT_BASE_URL,
    });

    expect(retrievals).toHaveLength(0);
    await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
  });

  test("rejects untrusted requests to create an SDK overlay", async ({
    checkout,
    page,
  }) => {
    await checkout.open({ body, waitForReady: true });
    const sender = await addSibling(page, "https://untrusted.example.test");
    const id = await page.locator(PAYMENT_ELEMENT_IFRAME).getAttribute("id");

    await sendFromSibling(page, sender, {
      fullscreen: true,
      param: "voucher",
      iframeId: id!.replace("orca-payment-element-iframeRef-", ""),
      metadata: {},
    });

    await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
  });

  for (const kind of ["split-card", "payment-management"] as const) {
    test.describe(`${kind} overlays`, () => {
      test.beforeEach(({ hermetic }) => {
        hermetic.use({
          name: "paymentManagementList",
          path: "/v1/payment-method-sessions/pms_payment_message_security/list-payment-methods",
          body: { payment_methods: [] },
        });
      });

      for (const [name, origin] of [
        ["foreign-origin", "https://untrusted.example.test"],
        ["SDK-origin", SDK_URL],
      ]) {
        test(`rejects overlay creation from an unregistered ${name} sibling`, async ({
          checkout,
          page,
        }) => {
          const intent = await checkout.open({ body, waitForReady: true });
          const { id } = await mountSecondaryElement(
            page,
            intent.clientSecret,
            kind,
          );
          const sender = await addSibling(page, origin);

          await sendFromSibling(page, sender, {
            fullscreen: true,
            param: "voucher",
            iframeId: id,
            metadata: {},
          });

          await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
        });
      }

      test("rejects overlay creation with the registered source but a different origin", async ({
        checkout,
        page,
      }) => {
        const intent = await checkout.open({ body, waitForReady: true });
        const { id, selector } = await mountSecondaryElement(
          page,
          intent.clientSecret,
          kind,
        );
        await page.evaluate(
          ({ id, selector }) => {
            const iframe = document.querySelector<HTMLIFrameElement>(selector)!;
            window.dispatchEvent(
              new MessageEvent("message", {
                source: iframe.contentWindow,
                origin: "https://untrusted.example.test",
                data: {
                  fullscreen: true,
                  param: "voucher",
                  iframeId: id,
                  metadata: {},
                },
              }),
            );
          },
          { id, selector },
        );

        await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
      });

      test("accepts its own iframe overlay request and overlay completion", async ({
        checkout,
        page,
      }) => {
        const intent = await checkout.open({ body, waitForReady: true });
        const { id, selector } = await mountSecondaryElement(
          page,
          intent.clientSecret,
          kind,
        );
        await page
          .frameLocator(selector)
          .locator("body")
          .evaluate((_el, id) => {
            window.parent.postMessage(
              {
                fullscreen: true,
                param: "voucher",
                iframeId: id,
                metadata: {},
              },
              "*",
            );
          }, id);

        await expect(page.locator("#orca-fullscreen")).toHaveCount(1);
        await expect
          .poll(() =>
            page
              .frames()
              .find((frame) => frame.name() === "fullscreen")
              ?.url(),
          )
          .toContain(`${SDK_URL}/fullscreenIndex.html`);
        const sender = await addSibling(page, "https://untrusted.example.test");
        await sendFromSibling(page, sender, { fullscreen: false });
        await expect(page.locator("#orca-fullscreen")).toHaveCount(1);
        await page
          .frameLocator("#orca-fullscreen")
          .locator("body")
          .evaluate(() => {
            window.parent.postMessage({ fullscreen: false }, "*");
          });
        await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
      });
    });
  }

  test.describe("3DS result relay", () => {
    test.use({ hermeticFixtures: ["05-external-3ds/03-juspay-3ds.json"] });

    test("relays only allowlisted fields from the authentication frame", async ({
      checkout,
      credentials,
      sdk,
      page,
    }) => {
      await checkout.open({
        body: paymentBody({
          profile_id: credentials.profileId(connectorEnum.JUSPAY),
          request_external_three_ds_authentication: true,
          authentication_type: "three_ds",
        }),
        waitForReady: true,
      });
      await sdk.enterCardDetails({
        cardNo: juspayChallengeTestCard,
        card_exp_month: "04",
        card_exp_year: "44",
        cvc: "1234",
      });
      await sdk.submit();
      const acs = await sdk.nestedIFrame("#threeDsAuthFrame");
      await expect(acs.locator("#otp")).toBeVisible();
      const probeUrl = `${CLIENT_BASE_URL}/payment-relay-probe`;
      await page.evaluate((probeUrl) => {
        window.paymentSecurityRelayedFields = [];
        window.addEventListener("message", (event) => {
          if (event.data?.openurl_if_required === probeUrl) {
            window.paymentSecurityRelayedFields.push(Object.keys(event.data));
          }
        });
      }, probeUrl);

      await page
        .frameLocator("#orca-fullscreen")
        .locator("body")
        .evaluate(async (_el, probeUrl) => {
          const child =
            document.querySelector<HTMLIFrameElement>("#threeDsAuthFrame")!;
          window.dispatchEvent(
            new MessageEvent("message", {
              source: child.contentWindow,
              origin: "https://untrusted.example.test",
              data: { openurl_if_required: probeUrl },
            }),
          );
          const channel = new MessageChannel();
          const delivered = new Promise<void>((resolve) => {
            channel.port1.onmessage = () => {
              channel.port1.close();
              resolve();
            };
          });
          window.parent.postMessage({ paymentSecurityBarrier: true }, "*", [
            channel.port2,
          ]);
          await delivered;
        }, probeUrl);
      expect(
        await page.evaluate(() => window.paymentSecurityRelayedFields),
      ).toEqual([]);

      await acs.locator("body").evaluate((_el, probeUrl) => {
        window.parent.postMessage(
          {
            openurl_if_required: probeUrl,
            submitSuccessful: true,
            data: { status: "succeeded" },
          },
          "*",
        );
      }, probeUrl);

      await expect
        .poll(() => page.evaluate(() => window.paymentSecurityRelayedFields))
        .toEqual([["openurl_if_required"]]);
      await expect(page.getByText("Thanks for your order!")).not.toBeVisible();
    });
  });
});
