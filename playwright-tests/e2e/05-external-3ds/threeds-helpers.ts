// Helpers for the external-3DS specs (05-external-3ds/*) only. Cross-group
// helpers (expectConfirmedWith, ...) live in fixtures/helpers.ts.
import { expect, testIds, type Hermetic, type Sdk } from "../../fixtures";

/** A card typed key by key into the payment element; expiry as MMYY. */
export interface TypedCard {
  cardNo: string;
  expiry: string;
  cvc: string;
}

/**
 * Types number, expiry and CVC key by key (no clearing, no delay), asserting
 * the CVC field is visible before typing into it.
 */
export async function typeCard(
  sdk: Sdk,
  { cardNo, expiry, cvc }: TypedCard,
): Promise<void> {
  await sdk.type(testIds.cardNoInputTestId, cardNo);
  await sdk.type(testIds.expiryInputTestId, expiry);
  await expect(sdk.field(testIds.cardCVVInputTestId)).toBeVisible();
  await sdk.type(testIds.cardCVVInputTestId, cvc);
}

/**
 * Hermetic only (no-op live): the SDK called POST /payments/:id/3ds/authentication
 * with the given 3DS-method completion indicator ("Y" after a 3DS method
 * iframe loaded, "U" when the router asked for no 3DS method call).
 */
export async function expectThreeDsAuthenticationCalled(
  hermetic: Hermetic,
  threeDsMethodCompInd: "Y" | "N" | "U",
): Promise<void> {
  if (!hermetic.enabled) return;
  const call = await hermetic.waitForCall("threeDsAuthentication", {
    timeout: 15_000,
  });
  expect(call?.requestBody).toMatchObject({
    device_channel: "BRW",
    threeds_method_comp_ind: threeDsMethodCompInd,
  });
}
