import { test, expect } from "../../fixtures/sdk-runtime";

for (const separateCollections of [false, true]) {
  for (const removeFirst of [false, true]) {
    test(`management widgets receive their own collection data (separate: ${separateCollections}, remove first: ${removeFirst}) @hermetic-only`, async ({
      runtimePage,
    }) => {
      const result = await runtimePage.evaluate(
        async ({ separateCollections, removeFirst }) => {
          const first = window.sdkTest.makeManagementElements();
          const second = separateCollections
            ? window.sdkTest.makeManagementElements()
            : first;
          const deliveries: unknown[][] = [[], [], []];
          const send = (frame: HTMLIFrameElement, data: object) =>
            window.dispatchEvent(
              new MessageEvent("message", {
                source: frame.contentWindow,
                origin: new URL(frame.src).origin,
                data,
              }),
            );
          const mount = (
            collection: typeof first,
            id: string,
            index: number,
          ) => {
            const widget = collection.create("paymentMethodsManagement", {});
            widget.mount(`#${id}`);
            const frame = document.querySelector<HTMLIFrameElement>(
              `#orca-payment-methods-management-element-iframeRef-${id}`,
            )!;
            frame.contentWindow!.postMessage = (payload: string) => {
              const data = JSON.parse(payload);
              if (data.paymentManagementMethods)
                deliveries[index].push(data.paymentManagementMethods);
            };
            send(frame, { iframeMounted: true });
            return widget;
          };
          const removed = mount(first, "first", 0);
          mount(second, "second", 1);
          const loaders = [
            ...document.querySelectorAll<HTMLIFrameElement>(
              'iframe[src*="fullscreenType=preMountLoader"]',
            ),
          ];
          for (const loader of loaders)
            send(loader, { preMountLoaderIframeMountedCallback: true });
          await Promise.resolve();
          await Promise.resolve();
          if (removeFirst) removed.destroy();
          for (const [index, loader] of loaders.entries()) {
            send(loader, {
              data: "payment_management_list",
              response: {
                customer_payment_methods: [{ payment_token: `token-${index}` }],
              },
            });
          }
          await Promise.resolve();
          await Promise.resolve();
          await Promise.resolve();
          for (const loader of loaders)
            send(loader, { preMountLoaderIframeUnMount: true });
          // A later mount must use cached data even though prefetch has been removed.
          if (!removeFirst) removed.destroy();
          mount(first, "first", 2);
          await Promise.resolve();
          await Promise.resolve();
          return {
            deliveries,
            loadersLeft: document.querySelectorAll(
              'iframe[src*="fullscreenType=preMountLoader"]',
            ).length,
          };
        },
        { separateCollections, removeFirst },
      );
      expect(result).toEqual({
        deliveries: [
          removeFirst
            ? []
            : [{ customer_payment_methods: [{ payment_token: "token-0" }] }],
          [
            {
              customer_payment_methods: [
                { payment_token: separateCollections ? "token-1" : "token-0" },
              ],
            },
          ],
          [{ customer_payment_methods: [{ payment_token: "token-0" }] }],
        ],
        loadersLeft: 0,
      });
    });
  }
}
