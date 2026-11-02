import type { Page } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  expectConfirmedWith,
  CLIENT_BASE_URL,
  type Hermetic,
} from "../../fixtures";

// createCardForm() splits the card across sibling field iframes and a hidden
// coordinator iframe, which exchange the raw card values over MessagePorts.
// Script running on the merchant page must not be able to read those values:
// not by tapping the channel they travel on, not by handing a field a port of
// its own, and not by asking the coordinator for one.

declare global {
  interface Window {
    cardFormUnderTest: { confirmPayment(): Promise<Record<string, unknown>> };
    cardFormChanges: Record<string, { complete?: boolean }>;
    stolenCardFrames: unknown[];
  }
}

const body = paymentBody({
  customer_id: "card_form_port_isolation_user",
  authentication_type: "no_three_ds",
});
const card = stripeCards.successCard;
const FIELDS = ["cardNumber", "cardExpiry", "cardCvc"] as const;
type Field = (typeof FIELDS)[number];
const INPUTS: Record<Field, string> = {
  cardNumber: "#card-number",
  cardExpiry: "#card-expiry",
  cardCvc: "#card-cvc",
};
// A fast human. With no delay at all, the confirm can overtake the last
// keystrokes on their way to the coordinator, on main as much as here.
const TYPING_DELAY_MS = 30;

const fieldInput = (page: Page, field: Field) =>
  page
    .frameLocator(`#orca-payment-element-iframeRef-card-form-${field}`)
    .locator(INPUTS[field]);

async function mountCardForm(page: Page, clientSecret: string): Promise<void> {
  await page.evaluate(
    ({ clientSecret, fields }) => {
      const hyper = (
        window as unknown as {
          HyperMethod: {
            elements(options: { clientSecret: string }): {
              createCardForm(): Window["cardFormUnderTest"] & {
                create(
                  type: string,
                  options: Record<string, unknown>,
                ): {
                  mount(selector: string): void;
                  on(event: string, cb: (payload: object) => void): void;
                };
              };
            };
          };
        }
      ).HyperMethod;
      const form = hyper.elements({ clientSecret }).createCardForm();
      window.cardFormUnderTest = form;
      window.cardFormChanges = {};
      for (const field of fields) {
        const mount = document.createElement("div");
        mount.id = `card-form-${field}`;
        document.body.appendChild(mount);
        const handle = form.create(field, {});
        handle.on("change", (payload) => {
          window.cardFormChanges[field] = payload;
        });
        handle.mount(`#card-form-${field}`);
      }
    },
    { clientSecret, fields: [...FIELDS] },
  );
  for (const field of FIELDS) {
    await expect(fieldInput(page, field)).toBeVisible();
  }
}

async function typeCardIntoForm(page: Page): Promise<void> {
  const delay = TYPING_DELAY_MS;
  await fieldInput(page, "cardNumber").pressSequentially(card.cardNo, {
    delay,
  });
  await fieldInput(page, "cardExpiry").pressSequentially(card.card_exp_month, {
    delay,
  });
  await fieldInput(page, "cardExpiry").pressSequentially(card.card_exp_year, {
    delay,
  });
  await fieldInput(page, "cardCvc").pressSequentially(card.cvc, { delay });
  // What a merchant waits for before enabling its pay button.
  await expect
    .poll(() =>
      page.evaluate(
        (fields) =>
          fields.every((field) => window.cardFormChanges[field]?.complete),
        [...FIELDS],
      ),
    )
    .toBe(true);
}

// Everything the merchant-page script captured that carries a raw card value.
const stolenCardData = (page: Page) =>
  page.evaluate(() =>
    window.stolenCardFrames
      .map((data) => (typeof data === "string" ? data : JSON.stringify(data)))
      .filter((data) => /rawCardNumber|rawCardExpiry|rawCvc/.test(data ?? "")),
  );

// The confirm only resolves after the card has crossed the iframes, so anything
// the page could capture has been captured by the time the leak check runs.
async function payAndExpectNoLeak(
  page: Page,
  hermetic: Hermetic,
): Promise<void> {
  const result = await page.evaluate(() =>
    window.cardFormUnderTest.confirmPayment(),
  );
  expect(await stolenCardData(page)).toEqual([]);
  expect(result).not.toHaveProperty("error");
  await expectConfirmedWith(hermetic, card.cardNo, `"card_cvc":"${card.cvc}"`);
}

test.describe("Card form port isolation @hermetic-only", () => {
  test("a merchant-page MessageChannel wrapper sees no card data", async ({
    checkout,
    page,
    hermetic,
  }) => {
    // Installed before any SDK code runs, and only in the merchant's document:
    // every channel created there is relayed through the page, which records it.
    await page.addInitScript((merchantOrigin) => {
      if (location.origin !== merchantOrigin) return;
      window.stolenCardFrames = [];
      const NativeChannel = window.MessageChannel;
      window.MessageChannel = class {
        port1: MessagePort;
        port2: MessagePort;
        constructor() {
          const a = new NativeChannel();
          const b = new NativeChannel();
          a.port2.onmessage = (event) => {
            window.stolenCardFrames.push(event.data);
            b.port1.postMessage(event.data);
          };
          b.port1.onmessage = (event) => {
            window.stolenCardFrames.push(event.data);
            a.port2.postMessage(event.data);
          };
          this.port1 = a.port1;
          this.port2 = b.port2;
        }
      } as unknown as typeof MessageChannel;
    }, new URL(CLIENT_BASE_URL).origin);

    const { clientSecret } = await checkout.open({ body, waitForReady: true });
    await mountCardForm(page, clientSecret);
    await typeCardIntoForm(page);

    await payAndExpectNoLeak(page, hermetic);
  });

  test("a merchant-page script cannot hand a card field its own port", async ({
    checkout,
    page,
    hermetic,
  }) => {
    const { clientSecret } = await checkout.open({ body, waitForReady: true });
    await mountCardForm(page, clientSecret);

    // Both the page-relayed handshake and the sibling handshake, sent from the page.
    await page.evaluate(
      (fields) => {
        window.stolenCardFrames = [];
        const coordinator = document.querySelector<HTMLIFrameElement>(
          'iframe[src*="componentName=cardFormCoordinator"]',
        )!;
        const groupId = new URL(coordinator.src).searchParams.get("groupId");
        for (const fieldName of fields) {
          const iframe = document.querySelector<HTMLIFrameElement>(
            `#orca-payment-element-iframeRef-card-form-${fieldName}`,
          )!;
          const handshakes = [
            JSON.stringify({
              cardFieldPort: true,
              portKey: `${groupId}:${fieldName}`,
              portEpoch: 424242,
            }),
            { cardFormFieldPort: true, groupId, fieldName },
          ];
          for (const handshake of handshakes) {
            const channel = new MessageChannel();
            channel.port1.onmessage = (event) =>
              window.stolenCardFrames.push(event.data);
            iframe.contentWindow!.postMessage(
              handshake,
              new URL(iframe.src).origin,
              [channel.port2],
            );
          }
        }
      },
      [...FIELDS],
    );
    await typeCardIntoForm(page);

    await payAndExpectNoLeak(page, hermetic);
  });

  test("the coordinator does not hand the merchant page a field's port", async ({
    checkout,
    page,
    hermetic,
  }) => {
    const { clientSecret } = await checkout.open({ body, waitForReady: true });
    await mountCardForm(page, clientSecret);

    // Asks for each field's port as if the page were that field.
    await page.evaluate(
      (fields) => {
        window.stolenCardFrames = [];
        window.addEventListener("message", (event) => {
          if (event.ports.length === 0) return;
          window.stolenCardFrames.push("port handed to the page");
          event.ports[0].onmessage = (frame) =>
            window.stolenCardFrames.push(frame.data);
        });
        const coordinator = document.querySelector<HTMLIFrameElement>(
          'iframe[src*="componentName=cardFormCoordinator"]',
        )!;
        const groupId = new URL(coordinator.src).searchParams.get("groupId");
        for (const fieldName of fields) {
          coordinator.contentWindow!.postMessage(
            {
              cardFormFieldHello: true,
              groupId,
              fieldName,
              fieldInstanceId: "merchant-page",
            },
            new URL(coordinator.src).origin,
          );
        }
      },
      [...FIELDS],
    );
    await typeCardIntoForm(page);

    await payAndExpectNoLeak(page, hermetic);
    expect(
      await page.evaluate(() =>
        window.stolenCardFrames.filter((f) => f === "port handed to the page"),
      ),
    ).toEqual([]);
  });
});
