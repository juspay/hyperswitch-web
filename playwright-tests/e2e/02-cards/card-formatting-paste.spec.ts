// Card Number Formatting and Paste Handling Tests
// Tests for auto-formatting, clipboard paste behavior, and input masking.
//
// Hermetic-capable: nothing here reaches /confirm.
import {
  test,
  expect,
  testIds,
  paymentBody,
  stripeCards,
  type Sdk,
} from "../../fixtures";

const body = paymentBody({
  customer_id: "formatting_test_user",
  authentication_type: "no_three_ds",
});

/**
 * Real clipboard paste into the card number field: puts `text` on the (per-context)
 * clipboard and presses Ctrl/Cmd+V in the field, so the browser fires `paste`,
 * then `beforeinput`/`input` with inputType "insertFromPaste" carrying the whole
 * string. The SDK has no paste listener and formats in its React onChange
 * (driven by `input`), so this exercises that handler through the browser's own
 * paste insertion.
 */
const pasteIntoCardNumber = async (sdk: Sdk, text: string) => {
  const { page } = sdk;
  // Chromium rejects clipboard.writeText() without the clipboard permissions.
  // WebKit allows it in a secure context (the demo shop is on localhost) and
  // has no "clipboard-write" permission at all: granting it there fails with
  // "Unknown permission".
  if (page.context().browser()?.browserType().name() === "chromium") {
    await page
      .context()
      .grantPermissions(["clipboard-read", "clipboard-write"]);
  }
  await page.evaluate((value) => navigator.clipboard.writeText(value), text);
  const input = sdk.field(testIds.cardNoInputTestId);
  await input.click();
  // Record the inputType of the next `input` event (listener installed before the keypress).
  await input.evaluate((el) => {
    (el as any).__lastInputType = null;
    el.addEventListener(
      "input",
      (e) => ((el as any).__lastInputType = (e as InputEvent).inputType),
      { once: true },
    );
  });
  await page.keyboard.press("ControlOrMeta+V");
  // Guard: the value must have arrived through a real paste, not some other path.
  await expect
    .poll(() => input.evaluate((el) => (el as any).__lastInputType))
    .toBe("insertFromPaste");
};

/** Card number digits with separators stripped, polled until it settles. */
const cardDigits = (sdk: Sdk, strip: RegExp) =>
  expect.poll(async () =>
    (await sdk.field(testIds.cardNoInputTestId).inputValue()).replace(
      strip,
      "",
    ),
  );

test.describe("Card Number Formatting and Paste Handling", () => {
  test.beforeEach(async ({ checkout, sdk }) => {
    await checkout.open({ body });
    await sdk.waitForReady();
  });

  test.describe("Card Number Auto-Formatting", () => {
    test("should format 16-digit Visa card as XXXX XXXX XXXX XXXX", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "4242424242424242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "4242 4242 4242 4242",
      );
    });

    test("should format 15-digit Amex card as XXXX XXXXXX XXXXX", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "378282246310005");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        /^3782 822463 10005$/,
      );
    });

    test("should format 14-digit Diners Club card correctly", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "36227206271667");

      const val = await sdk.field(testIds.cardNoInputTestId).inputValue();
      expect(val.replace(/\s/g, "")).toBe("36227206271667");
    });

    test("should format 19-digit UnionPay card correctly", async ({ sdk }) => {
      const { cardNo } = stripeCards.unionPay19;

      await sdk.safeType(testIds.cardNoInputTestId, cardNo);

      const val = await sdk.field(testIds.cardNoInputTestId).inputValue();
      expect(val.replace(/\s/g, "")).toBe(cardNo);
    });
  });

  test.describe("Expiry Date Formatting", () => {
    test("should auto-format expiry as MM / YY", async ({ sdk }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await sdk.safeType(testIds.expiryInputTestId, "1230");

      await expect(sdk.field(testIds.expiryInputTestId)).toHaveValue(
        /^12\s*\/\s*30$/,
      );
    });

    test("should auto-prepend 0 when month starts with 2-9", async ({
      sdk,
    }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await sdk.safeType(testIds.expiryInputTestId, "230");

      await expect(sdk.field(testIds.expiryInputTestId)).toHaveValue(
        /^02\s*\/\s*30$/,
      );
    });

    test("should not allow non-numeric characters in expiry field", async ({
      sdk,
    }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await sdk.safeType(testIds.expiryInputTestId, "ab12cd30");

      await expect(sdk.field(testIds.expiryInputTestId)).toHaveValue(
        /^12\s*\/\s*30$/,
      );
    });
  });

  test.describe("Paste Handling", () => {
    test("should accept and format a pasted card number with spaces", async ({
      sdk,
    }) => {
      await pasteIntoCardNumber(sdk, "4242 4242 4242 4242");

      await cardDigits(sdk, /\s/g).toBe("4242424242424242");
    });

    test("should accept and format a pasted card number with dashes", async ({
      sdk,
    }) => {
      await pasteIntoCardNumber(sdk, "4242-4242-4242-4242");

      await cardDigits(sdk, /[\s-]/g).toBe("4242424242424242");
    });
  });

  test.describe("Max Length Enforcement", () => {
    test("should enforce maximum 19 digits for card number", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "42424242424242424242999");

      const val = await sdk.field(testIds.cardNoInputTestId).inputValue();
      expect(val.replace(/\s/g, "").length).toBeLessThanOrEqual(19);
    });

    test("should enforce maximum 3 digits for Visa CVC", async ({ sdk }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await sdk.safeType(testIds.cardCVVInputTestId, "12345");

      const val = await sdk.field(testIds.cardCVVInputTestId).inputValue();
      expect(val.length).toBeLessThanOrEqual(3);
    });

    test("should enforce maximum 4 digits for Amex CVC", async ({ sdk }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.amexCard15.cardNo,
      );

      await sdk.safeType(testIds.cardCVVInputTestId, "123456");

      const val = await sdk.field(testIds.cardCVVInputTestId).inputValue();
      expect(val.length).toBeLessThanOrEqual(4);
    });
  });
});
