import { test, expect } from "../../fixtures";

test.describe("Widget review regressions @hermetic-only", () => {
  for (const types of [
    ["card", "expressCheckout"],
    ["cardNumber", "cardExpiry", "cardCvc", "expressCheckout"],
  ]) {
    test(`card confirmation ignores unrelated wallet readiness: ${types.join("+")}`, async ({
      checkout,
      page,
    }) => {
      const { clientSecret } = await checkout.open({ waitForReady: true });
      await page.evaluate(
        ({ clientSecret, types }) => {
          const w = window as any;
          document.querySelector(".mainContainer")?.remove();
          w.reviewElements = w.HyperMethod.elements({ clientSecret });
          w.reviewReadies = [];
          types.forEach((type, index) => {
            const container = document.createElement("div");
            container.id = `review-${index}`;
            document.body.append(container);
            const widget = w.reviewElements.create(type, {});
            widget.on("ready", () => w.reviewReadies.push(type));
            widget.mount(`#${container.id}`);
          });
        },
        { clientSecret, types },
      );
      await expect
        .poll(() => page.evaluate(() => (window as any).reviewReadies))
        .toEqual(
          expect.arrayContaining(
            types.filter((type) => type !== "expressCheckout"),
          ),
        );
      await page.evaluate(() => {
        const w = window as any;
        w.HyperMethod.confirmPayment({}).then(
          (result: unknown) => {
            w.reviewResult = result;
          },
        );
      });
      await expect
        .poll(() => page.evaluate(() => (window as any).reviewResult), {
          timeout: 5000,
        })
        .toHaveProperty("error.type", "validation_error");
    });
  }

  for (const stage of ["callback", "prefetch"]) {
    for (const replacement of [
      "mounted",
      "removed",
      "replaced",
      "loading",
      "loading-removed",
    ]) {
      test(`updateIntent uses live widgets after ${stage}: ${replacement}`, async ({
        checkout,
        page,
        hermetic,
      }) => {
        await page.addInitScript(() => {
          (window as any).reviewCredentials = [];
          (window as any).reviewAmounts = [];
          window.addEventListener("message", (event) => {
            let data = event.data;
            if (typeof data === "string") {
              try {
                data = JSON.parse(data);
              } catch {
                return;
              }
            }
            if (data?.ElementsUpdate)
              (window as any).reviewCredentials.push(data.sdkAuthorization);
            if (data?.paymentElementCreate)
              (window as any).reviewCredentials.push(
                data.paymentOptions?.sdkAuthorization,
              );
            if (data?.clientList)
              (window as any).reviewAmounts.push(
                data.clientList.intent_data?.amount,
              );
          });
        });
        const { clientSecret } = await checkout.open({ waitForReady: true });
        await page.evaluate((clientSecret) => {
          const w = window as any;
          // Remove the demo's original widget so its ready event cannot satisfy
          // this collection's update when every reviewed widget was removed.
          document.querySelector(".mainContainer")?.remove();
          w.reviewElements = w.HyperMethod.elements({ clientSecret });
          w.reviewWidgets = [];
          w.reviewReadies = [];
          w.reviewMount = (id: string) => {
            const container = document.createElement("div");
            container.id = id;
            document.body.append(container);
            const widget = w.reviewElements.create("payment", {
              displaySavedPaymentMethods: false,
            });
            widget.on("ready", () => w.reviewReadies.push(id));
            widget.mount(`#${id}`);
            w.reviewWidgets.push(widget);
          };
          w.reviewMount("review-original");
        }, clientSecret);
        await expect
          .poll(() => page.evaluate(() => (window as any).reviewReadies))
          .toContain("review-original");
        hermetic.override("clientList", { intent_data: { amount: 7777 } });
        let release!: () => void;
        const held = new Promise<void>((resolve) => {
          release = resolve;
        });
        let requested = false;
        let releaseFrame!: () => void;
        const heldFrame = new Promise<void>((resolve) => {
          releaseFrame = resolve;
        });
        let frameRequested = false;
        if (replacement.startsWith("loading"))
          await page.route(
            "**/index.html?componentName=payment",
            async (route) => {
              frameRequested = true;
              await heldFrame;
              await route.fallback();
            },
          );
        if (stage === "prefetch")
          await page.route("**/payments/*/client**", async (route) => {
            requested = true;
            await held;
            await route.fallback();
          });
        try {
          await page.evaluate((stage) => {
            const w = window as any;
            w.reviewElements
              .updateIntent(() =>
                stage === "callback"
                  ? new Promise((resolve) => {
                      w.reviewRelease = () =>
                        resolve({ sdkAuthorization: "review-refreshed" });
                    })
                  : Promise.resolve({ sdkAuthorization: "review-refreshed" }),
              )
              .then((result: unknown) => {
                w.reviewUpdateResult = result;
              });
          }, stage);
          if (stage === "prefetch")
            await expect.poll(() => requested).toBe(true);
          await page.evaluate((replacement) => {
            const w = window as any;
            if (replacement === "removed" || replacement === "replaced")
              w.reviewWidgets[0].destroy();
            if (replacement !== "removed") w.reviewMount("review-new");
          }, replacement);
          if (replacement.startsWith("loading")) {
            await expect.poll(() => frameRequested).toBe(true);
          } else if (replacement !== "removed") {
            await expect
              .poll(() => page.evaluate(() => (window as any).reviewReadies))
              .toContain("review-new");
          }
          release();
          if (stage === "callback")
            await page.evaluate(() => (window as any).reviewRelease());
          if (replacement.startsWith("loading")) {
            const original = page.frameLocator(
              "#orca-payment-element-iframeRef-review-original",
            );
            await expect
              .poll(() =>
                original
                  .locator("body")
                  .evaluate(() => (window as any).reviewCredentials),
              )
              .toContain("review-refreshed");
            // One current participant is ready, but the new iframe is still loading.
            await expect
              .poll(() =>
                page.evaluate(
                  () =>
                    (window as any).reviewReadies.filter(
                      (id: string) => id === "review-original",
                    ).length,
                ),
              )
              .toBe(2);
            expect(
              await page.evaluate(() => (window as any).reviewUpdateResult),
            ).toBeUndefined();
            if (replacement === "loading-removed")
              await page.evaluate(() =>
                (window as any).reviewWidgets.at(-1).destroy(),
              );
            releaseFrame();
          }
          await expect
            .poll(
              () => page.evaluate(() => (window as any).reviewUpdateResult),
              { timeout: 7000 },
            )
            .toHaveProperty("status", "succeeded");
          if (replacement !== "removed" && replacement !== "loading-removed") {
            const frame = page.frameLocator(
              "#orca-payment-element-iframeRef-review-new",
            );
            await expect
              .poll(() =>
                frame
                  .locator("body")
                  .evaluate(() => (window as any).reviewCredentials),
              )
              .toContain("review-refreshed");
            await expect
              .poll(() =>
                frame
                  .locator("body")
                  .evaluate(() => (window as any).reviewAmounts),
              )
              .toContain(7777);
          }
        } finally {
          release();
          releaseFrame();
          await page.unrouteAll({ behavior: "wait" });
        }
      });
    }
  }

  test("updateIntent settles when its last widget destroys itself on refreshed ready", async ({
    checkout,
    page,
  }) => {
    const { clientSecret } = await checkout.open({ waitForReady: true });
    await page.evaluate((clientSecret) => {
      const w = window as any;
      document.querySelector(".mainContainer")?.remove();
      const container = document.createElement("div");
      container.id = "review-after-commit";
      document.body.append(container);
      w.reviewElements = w.HyperMethod.elements({ clientSecret });
      w.reviewWidget = w.reviewElements.create("payment", {
        displaySavedPaymentMethods: false,
      });
      w.reviewReadyCount = 0;
      w.reviewWidget.on("ready", () => {
        w.reviewReadyCount++;
        if (w.reviewReadyCount === 2) w.reviewWidget.destroy();
      });
      w.reviewWidget.mount("#review-after-commit");
    }, clientSecret);
    await expect
      .poll(() => page.evaluate(() => (window as any).reviewReadyCount))
      .toBe(1);
    await page.evaluate(() => {
      const w = window as any;
      w.reviewElements
        .updateIntent(async () => ({ sdkAuthorization: "after-commit-auth" }))
        .then((result: unknown) => {
          w.reviewResult = result;
        });
    });
    await expect
      .poll(() => page.evaluate(() => (window as any).reviewReadyCount))
      .toBe(2);
    await expect(
      page.locator("#orca-payment-element-iframeRef-review-after-commit"),
    ).toHaveCount(0);
    await expect
      .poll(() => page.evaluate(() => (window as any).reviewResult))
      .toHaveProperty("status", "succeeded");
    // The update lock must also be released after the removed participant settles.
    const retry = await page.evaluate(() =>
      (window as any).reviewElements.updateIntent(async () => ({
        sdkAuthorization: "after-removal",
      })),
    );
    expect(retry).toHaveProperty("status", "succeeded");
  });
});
