import { test, expect } from "../../fixtures/sdk-runtime";
import savedCards from "../../recordings/02-cards/07-saved-cards.json";

test.beforeEach(async ({ runtimePage }) => {
  await runtimePage.route("https://fonts.googleapis.com/**", (route) =>
    route.fulfill({ contentType: "text/css", body: "" }),
  );
  await runtimePage.route("**/index.html?componentName=cardCvc", (route) =>
    route.fulfill({
      contentType: "text/html",
      body: `<script>addEventListener("message", event => {
          const data = typeof event.data === "string" ? JSON.parse(event.data) : event.data;
          if (data.sdkConfigs) parent.postMessage({ testSdkConfigs: data.sdkConfigs }, event.origin);
          if (!data.requestCVCConfirm) return;
          parent.postMessage({ testCvcRequest: data.requestCVCConfirm }, event.origin);
          parent.postMessage({
            cvcWidgetRequestId: data.requestCVCConfirm.requestId,
            cvcWidgetConfirmResponse: { data: { status: "routed" } }
          }, event.origin);
        });</script>`,
    }),
  );
  await runtimePage.route("**/payments/*/client**", (route) =>
    route.fulfill({ json: savedCards.routes[0].body }),
  );
});

test("retained collections share fresh prefetch data after their contexts converge @hermetic-only", async ({
  runtimePage,
}) => {
  const marker = await runtimePage.evaluate(async () => {
    const hyper = window.sdkTest.makeHyper();
    const token = (id: string) =>
      btoa(`payment_id=pay_${id},publishable_key=pk_snd_review`);
    const send = (frame: HTMLIFrameElement, data: object) =>
      dispatchEvent(
        new MessageEvent("message", {
          source: frame.contentWindow,
          origin: new URL(frame.src).origin,
          data,
        }),
      );
    const settle = async (marker: string) => {
      const frames = [
        ...document.querySelectorAll<HTMLIFrameElement>(
          'iframe[src*="fullscreenType=preMountLoader"]',
        ),
      ];
      for (const frame of frames)
        send(frame, { preMountLoaderIframeMountedCallback: true });
      await Promise.resolve();
      await Promise.resolve();
      for (const frame of frames)
        for (const data of ["session_tokens", "sdk_configs", "client_list"])
          send(frame, { data, response: { marker } });
    };
    const elementsA = hyper.elements({ sdkAuthorization: token("A") });
    const elementsB = hyper.elements({ sdkAuthorization: token("B") });
    await settle("initial");
    const update = elementsA.updateIntent(async () => ({
      sdkAuthorization: token("B"),
    }));
    await Promise.resolve();
    await settle("updated");
    await update;
    hyper.elements({ sdkAuthorization: token("B") });
    await settle("fresh");
    elementsB.create("cardCvc", {}).mount("#second");
    const frame = document.querySelector<HTMLIFrameElement>(
      "#orca-payment-element-iframeRef-second",
    )!;
    await new Promise((resolve) =>
      frame.addEventListener("load", resolve, { once: true }),
    );
    const received = new Promise((resolve) =>
      addEventListener("message", (event) => {
        if (event.source === frame.contentWindow && event.data?.testSdkConfigs)
          resolve(event.data.testSdkConfigs.marker);
      }),
    );
    send(frame, { iframeMounted: true });
    return received;
  });
  expect(marker).toBe("fresh");
});

for (const updater of ["elements", "session"] as const) {
  for (const companion of ["after", "before", "during"] as const) {
    test(`${updater} A→B update shares existing CVC widgets with a companion created ${companion} the update @hermetic-only`, async ({
      runtimePage,
    }) => {
      const result = await runtimePage.evaluate(
        async ({ updater, companion }) => {
          const hyper = window.sdkTest.makeHyper();
          const token = (id: string) =>
            btoa(`payment_id=pay_${id},publishable_key=pk_snd_review`);
          const send = (frame: HTMLIFrameElement, data: object) =>
            dispatchEvent(
              new MessageEvent("message", {
                source: frame.contentWindow,
                origin: new URL(frame.src).origin,
                data,
              }),
            );
          const settlePrefetch = async () => {
            const frames = [
              ...document.querySelectorAll<HTMLIFrameElement>(
                'iframe[src*="fullscreenType=preMountLoader"]',
              ),
            ];
            for (const frame of frames)
              send(frame, { preMountLoaderIframeMountedCallback: true });
            await Promise.resolve();
            await Promise.resolve();
            for (const frame of frames)
              for (const data of [
                "session_tokens",
                "sdk_configs",
                "client_list",
              ])
                send(frame, { data, response: {} });
          };
          const requests: { id: string; sdkAuthorization: string }[] = [];
          addEventListener("message", (event) => {
            if (!event.data?.testCvcRequest) return;
            const frame = [
              ...document.querySelectorAll<HTMLIFrameElement>("iframe"),
            ].find((frame) => frame.contentWindow === event.source)!;
            requests.push({
              id: frame.id.replace("orca-payment-element-iframeRef-", ""),
              sdkAuthorization: event.data.testCvcRequest.sdkAuthorization,
            });
          });
          const mount = async (elements: any, id: string) => {
            elements.create("cardCvc", {}).mount(`#${id}`);
            const frame = document.querySelector<HTMLIFrameElement>(
              `#orca-payment-element-iframeRef-${id}`,
            )!;
            await new Promise((resolve) =>
              frame.addEventListener("load", resolve, { once: true }),
            );
          };
          // The old client secret intentionally stays present after SDK auth changes.
          const elements = hyper.elements({
            clientSecret: "pay_A_secret_test",
            sdkAuthorization: token("A"),
          });
          await mount(elements, "first");
          await settlePrefetch();
          const originalSession = hyper.initPaymentSession({
            sdkAuthorization: token("A"),
          });
          let companionSession: any;
          const createCompanion = () => {
            companionSession = hyper.initPaymentSession({
              sdkAuthorization: token("B"),
            });
          };
          if (companion === "before") createCompanion();
          const updated = (
            updater === "elements" ? elements : originalSession
          ).updateIntent(async () => {
            if (companion === "during") createCompanion();
            return { sdkAuthorization: token("B") };
          });
          await Promise.resolve();
          await settlePrefetch();
          const updateResult = await updated;
          if (companion === "after") createCompanion();
          const methods =
            await companionSession.getCustomerSavedPaymentMethods();
          const confirmed =
            await methods.confirmWithCustomerDefaultPaymentMethod({
              id: "first",
              redirect: "if_required",
            });
          const oldMethods = await hyper
            .initPaymentSession({ clientSecret: "pay_A_secret_test" })
            .getCustomerSavedPaymentMethods();
          const stale =
            await oldMethods.confirmWithCustomerDefaultPaymentMethod({
              id: "first",
            });
          const foreignMethods = await window.sdkTest
            .makeHyper("pk_snd_foreign", { isForceInit: true })
            .initPaymentSession({ sdkAuthorization: token("B") })
            .getCustomerSavedPaymentMethods();
          const foreign =
            await foreignMethods.confirmWithCustomerDefaultPaymentMethod({
              id: "first",
            });
          // A retained companion must keep sharing credentials and newly mounted
          // frames when it initiates the next intent change itself.
          await mount(elements, "second");
          const nextUpdate = companionSession.updateIntent(async () => ({
            sdkAuthorization: token("C"),
          }));
          await Promise.resolve();
          await settlePrefetch();
          const nextUpdateResult = await nextUpdate;
          const retained =
            await methods.confirmWithCustomerDefaultPaymentMethod({
              id: "second",
              redirect: "if_required",
            });
          const newestMethods = await hyper
            .initPaymentSession({ sdkAuthorization: token("C") })
            .getCustomerSavedPaymentMethods();
          const newest =
            await newestMethods.confirmWithCustomerDefaultPaymentMethod({
              id: "first",
              redirect: "if_required",
            });
          return {
            updateResult,
            confirmed,
            stale,
            foreign,
            requests,
            nextUpdateResult,
            retained,
            newest,
            tokenB: token("B"),
            tokenC: token("C"),
          };
        },
        { updater, companion },
      );
      expect(result.updateResult).toEqual({ status: "succeeded" });
      expect(result.confirmed).toEqual({ status: "routed" });
      expect(result.requests).toEqual([
        { id: "first", sdkAuthorization: result.tokenB },
        { id: "second", sdkAuthorization: result.tokenC },
        { id: "first", sdkAuthorization: result.tokenC },
      ]);
      expect(result.stale).toHaveProperty("error.type", "cvc_widget_not_found");
      expect(result.foreign).toHaveProperty(
        "error.type",
        "cvc_widget_not_found",
      );
      expect(result.nextUpdateResult).toEqual({ status: "succeeded" });
      expect(result.retained).toEqual({ status: "routed" });
      expect(result.newest).toEqual({ status: "routed" });
    });
  }

  test(`${updater} failed A→B prefetch preserves the original payment context @hermetic-only`, async ({
    runtimePage,
  }) => {
    const result = await runtimePage.evaluate(async (updater) => {
      const hyper = window.sdkTest.makeHyper();
      const token = (id: string) =>
        btoa(`payment_id=pay_${id},publishable_key=pk_snd_review`);
      const elements = hyper.elements({
        clientSecret: "pay_A_secret_test",
        sdkAuthorization: token("A"),
      });
      elements.create("cardCvc", {}).mount("#first");
      const frame = document.querySelector<HTMLIFrameElement>(
        "#orca-payment-element-iframeRef-first",
      )!;
      await new Promise((resolve) =>
        frame.addEventListener("load", resolve, { once: true }),
      );
      await window.sdkTest.resolvePreMount();
      const sessionA = hyper.initPaymentSession({
        sdkAuthorization: token("A"),
      });
      const sessionB = hyper.initPaymentSession({
        sdkAuthorization: token("B"),
      });
      const pending = (
        updater === "elements" ? elements : sessionA
      ).updateIntent(async () => ({ sdkAuthorization: token("B") }));
      await Promise.resolve();
      const loaders = [
        ...document.querySelectorAll<HTMLIFrameElement>(
          'iframe[src*="fullscreenType=preMountLoader"]',
        ),
      ];
      const send = (loader: HTMLIFrameElement, data: object) =>
        dispatchEvent(
          new MessageEvent("message", {
            source: loader.contentWindow,
            origin: new URL(loader.src).origin,
            data,
          }),
        );
      for (const loader of loaders)
        send(loader, { preMountLoaderIframeMountedCallback: true });
      await Promise.resolve();
      await Promise.resolve();
      for (const loader of loaders)
        for (const data of ["session_tokens", "sdk_configs", "client_list"])
          send(loader, {
            data,
            response:
              data === "client_list"
                ? { error: { message: "prefetch failed" } }
                : {},
          });
      const update = await pending;
      const original = await hyper
        .initPaymentSession({ sdkAuthorization: token("A") })
        .getCustomerSavedPaymentMethods();
      const originalResult =
        await original.confirmWithCustomerDefaultPaymentMethod({
          id: "first",
          redirect: "if_required",
        });
      const other = await sessionB.getCustomerSavedPaymentMethods();
      const otherResult = await other.confirmWithCustomerDefaultPaymentMethod({
        id: "first",
      });
      return { update, originalResult, otherResult };
    }, updater);
    expect(result.update).toHaveProperty("error.type", "update_intent_error");
    expect(result.originalResult).toEqual({ status: "routed" });
    expect(result.otherResult).toHaveProperty(
      "error.type",
      "cvc_widget_not_found",
    );
  });
}
