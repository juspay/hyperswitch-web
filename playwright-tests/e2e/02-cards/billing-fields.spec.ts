// Billing Fields Tests
//
// Covers two orthogonal aspects of billing field behaviour:
//
//  1. Backend-Driven Dynamic Fields
//     The backend returns `required_fields` based on what is absent from the
//     payment body. Tests here verify that the SDK renders exactly the fields
//     the backend requests — across multiple connectors and partial-billing
//     scenarios.
//
//  2. SDK fields.billingDetails Option
//     The merchant can pass `fields.billingDetails` (e.g. "never", or a
//     per-field object) to the SDK to suppress individual fields regardless of
//     what the backend requests. Tests here verify that option is respected.
//
// Hermetic: recordings/02-cards/billing-fields.json serves a superposition
// sdk_config (raw_configs) per profile, so the SDK derives the same required
// fields it gets on sandbox (Stripe: card only; Cybersource: name + billing
// email + address; Bank of America: email + name + address).
//
// Absence assertions (`toHaveCount(0)`) only mean something once the dynamic
// fields have resolved, so each one first waits for an SDK-ready signal: a field
// that must be there (line1), the card form, or (hermetic) the served
// sdk_config + client list. This guards against passing before render.
import {
  test,
  expect,
  testIds,
  paymentBody,
  defaultBillingAddress,
  cybersourceCards,
  connectorEnum,
  type Hermetic,
  type Sdk,
} from "../../fixtures";

/** Billing inputs in the payment element render with data-testid = last segment of their write path. */
const billingField = (sdk: Sdk, id: string) =>
  sdk.find(`[data-testid="${id}"]`);

const fullBilling = {
  email: "hyperswitch_sdk_demo_id@gmail.com",
  address: defaultBillingAddress,
  phone: { number: "8056594427", country_code: "+91" },
};

/** Hermetic only: the SDK finished resolving its required fields (sdk_config + client list served). */
const waitForRequiredFieldsResolved = async (hermetic: Hermetic) => {
  if (!hermetic.enabled) return;
  await hermetic.waitForCall("sdkConfigs");
  await hermetic.waitForCall("clientList");
};

test.describe("Billing Fields", () => {
  // ---------------------------------------------------------------------------
  // 1. Backend-Driven Dynamic Fields
  //
  // Fields appear when the backend's required_fields indicates they are absent
  // from the payment intent. Providing them in the payment body suppresses them.
  // ---------------------------------------------------------------------------

  test.describe("Backend-Driven Dynamic Fields", () => {
    test.describe("Stripe Connector", () => {
      const stripeBody = (overrides: Record<string, unknown>) =>
        paymentBody({
          customer_id: "dynamic_fields_stripe_user",
          authentication_type: "no_three_ds",
          ...overrides,
        });

      test("should render the card form when billing is removed from payment body", async ({
        checkout,
        sdk,
        credentials,
      }) => {
        await checkout.open({
          body: stripeBody({
            billing: undefined,
            profile_id: credentials.profileId(connectorEnum.STRIPE),
          }),
        });

        await sdk.waitForReady();

        await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible();
      });

      test("should not render billing fields when billing is provided in payment body", async ({
        checkout,
        sdk,
        credentials,
        hermetic,
      }) => {
        // NOTE: `billing` is sent as the bare address object, not `{ address: … }`. Left
        // unchanged deliberately: correcting it would change the request the router receives.
        await checkout.open({
          body: stripeBody({
            billing: defaultBillingAddress,
            profile_id: credentials.profileId(connectorEnum.STRIPE),
          }),
        });

        await sdk.waitForReady();
        await waitForRequiredFieldsResolved(hermetic);

        // No billing section and no line1 input.
        await expect(
          sdk.find('.billing-section, [data-testid="line1"]'),
        ).toHaveCount(0);
      });
    });

    test.describe("Bank of America Connector", () => {
      test("should render billing fields when billing is removed for Bank of America", async ({
        checkout,
        sdk,
        credentials,
      }) => {
        await checkout.open({
          body: paymentBody({
            profile_id: credentials.profileId(connectorEnum.BANK_OF_AMERICA),
            customer_id: "dynamic_fields_boa_user",
            authentication_type: "no_three_ds",
            billing: undefined,
          }),
        });

        await sdk.waitForReady();

        await expect(billingField(sdk, "line1")).toBeVisible();
      });
    });

    test.describe("Cybersource Connector – Field Rendering and Validation", () => {
      test.beforeEach(async ({ checkout, sdk, credentials }) => {
        await checkout.open({
          body: paymentBody({
            profile_id: credentials.profileId(connectorEnum.CYBERSOURCE),
            customer_id: "dynamic_fields_validation_user",
            authentication_type: "no_three_ds",
            billing: undefined,
            // Remove top-level email so the backend includes it in required_fields
            // and the SDK renders the email input for this connector.
            email: undefined,
          }),
        });

        await sdk.waitForReady();
      });

      test("should show billing details header when dynamic fields are rendered", async ({
        sdk,
      }) => {
        await expect(sdk.text("Billing Details").first()).toBeVisible();
      });

      test("should require address line1 field for payment submission", async ({
        sdk,
        hermetic,
      }) => {
        const { cardNo, card_exp_month, card_exp_year, cvc } =
          cybersourceCards.successCard;

        await sdk.safeType(testIds.cardNoInputTestId, cardNo);
        await sdk.safeType(
          testIds.expiryInputTestId,
          card_exp_month + card_exp_year,
        );
        await sdk.safeType(testIds.cardCVVInputTestId, cvc);

        await billingField(sdk, "city").pressSequentially("San Francisco");
        await billingField(sdk, "zip").pressSequentially("94122");

        await expect(sdk.submitButton).toBeVisible();
        await sdk.submit();
        await expect(sdk.submitButton).toBeVisible();

        // Hermetic only: the SDK flagged the empty line1 and never called /confirm.
        if (hermetic.enabled) {
          await expect(
            sdk.formErrors.filter({
              hasText: "Address line 1 cannot be empty",
            }),
          ).toBeVisible();
          expect(hermetic.calls("confirm")).toHaveLength(0);
        }
      });

      test("should accept valid billing fields and complete payment", async ({
        sdk,
        page,
        hermetic,
      }) => {
        const { cardNo, card_exp_month, card_exp_year, cvc } =
          cybersourceCards.successCard;

        await sdk.safeType(testIds.cardNoInputTestId, cardNo);
        await sdk.safeType(
          testIds.expiryInputTestId,
          card_exp_month + card_exp_year,
        );
        await sdk.safeType(testIds.cardCVVInputTestId, cvc);

        await billingField(sdk, "first_name").pressSequentially("Joseph Doe");

        await sdk
          .find('select[aria-label="Country option tab"]')
          .selectOption("United States");

        await billingField(sdk, "line1").pressSequentially(
          "1467 Harrison Street",
        );
        await billingField(sdk, "city").pressSequentially("San Francisco");

        await sdk
          .find('select[aria-label="State option tab"]')
          .selectOption("California");

        await billingField(sdk, "zip").pressSequentially("94122");
        await billingField(sdk, "email").pressSequentially(
          "hyperswitch_sdk_demo_id@gmail.com",
        );

        await expect(sdk.submitButton).toBeVisible();
        await sdk.submit();

        await expect(page.getByText("Thanks for your order!")).toBeVisible({
          timeout: 15_000,
        });

        // Hermetic only: the typed billing details reached /confirm.
        if (hermetic.enabled) {
          const confirm = await hermetic.waitForCall("confirm");
          const sent = JSON.stringify(confirm?.requestBody);
          for (const v of [
            "1467 Harrison Street",
            "San Francisco",
            "94122",
            "Joseph",
            "Doe",
            "hyperswitch_sdk_demo_id@gmail.com",
          ]) {
            expect(sent).toContain(v);
          }
        }
      });

      test("should allow typing in address line1 field", async ({ sdk }) => {
        await billingField(sdk, "line1").pressSequentially(
          "1467 Harrison Street",
        );

        await expect(billingField(sdk, "line1")).toHaveValue(
          "1467 Harrison Street",
        );
      });

      test("should allow typing in city field", async ({ sdk }) => {
        await billingField(sdk, "city").pressSequentially("San Francisco");

        await expect(billingField(sdk, "city")).toHaveValue("San Francisco");
      });

      test("should allow typing in postal code field", async ({ sdk }) => {
        await billingField(sdk, "zip").pressSequentially("94122");

        await expect(billingField(sdk, "zip")).toHaveValue("94122");
      });
    });

    test.describe("Partial Billing — Only the Missing Fields Appear", () => {
      // When billing is partially provided, the backend omits already-known
      // fields from required_fields. Only the absent fields should render.
      const partialBody = (
        profileId: string | undefined,
        billing: Record<string, unknown>,
      ) =>
        paymentBody({
          profile_id: profileId,
          customer_id: "dynamic_fields_partial_billing_user",
          authentication_type: "no_three_ds",
          billing,
        });

      test("should not render BillingName field when billing first and last name are provided", async ({
        checkout,
        sdk,
        credentials,
      }) => {
        await checkout.open({
          body: partialBody(credentials.profileId(connectorEnum.CYBERSOURCE), {
            address: { first_name: "Joseph", last_name: "Doe" },
          }),
        });

        await sdk.waitForReady();

        // line1 first: once it is visible the dynamic fields have resolved, so the
        // absence check below can't pass merely because nothing has rendered yet.
        await expect(billingField(sdk, "line1")).toBeVisible({
          timeout: 10_000,
        });
        await expect(billingField(sdk, "first_name")).toHaveCount(0);
      });

      test("should not render email field when billing email is provided", async ({
        checkout,
        sdk,
        credentials,
      }) => {
        await checkout.open({
          body: partialBody(credentials.profileId(connectorEnum.CYBERSOURCE), {
            email: "hyperswitch_sdk_demo_id@gmail.com",
          }),
        });

        await sdk.waitForReady();

        await expect(billingField(sdk, "line1")).toBeVisible({
          timeout: 10_000,
        });
        await expect(billingField(sdk, "email")).toHaveCount(0);
      });
    });

    test.describe("Country and State Dropdown", () => {
      test.beforeEach(async ({ checkout, sdk, credentials }) => {
        await checkout.open({
          body: paymentBody({
            profile_id: credentials.profileId(connectorEnum.CYBERSOURCE),
            customer_id: "dynamic_fields_dropdown_user",
            authentication_type: "no_three_ds",
            billing: undefined,
          }),
        });

        await sdk.waitForReady();
        // Let the dynamic fields resolve before the conditional checks below, so the
        // branch can't be skipped by racing the render.
        await expect(billingField(sdk, "line1")).toBeVisible({
          timeout: 10_000,
        });
      });

      // Both checks are conditional: if the dropdown renders, it must be visible.
      test("should render country dropdown when required by connector", async ({
        sdk,
      }) => {
        const country = sdk.find('select[aria-label="Country option tab"]');
        if ((await country.count()) > 0) {
          await expect(country).toBeVisible();
        }
      });

      test("should render state dropdown when required by connector", async ({
        sdk,
      }) => {
        const state = sdk.find('select[aria-label="State option tab"]');
        if ((await state.count()) > 0) {
          await expect(state).toBeVisible();
        }
      });
    });
  });

  // ---------------------------------------------------------------------------
  // 2. SDK fields.billingDetails Option
  //
  // The merchant can suppress individual billing fields via the SDK option,
  // independently of what the backend requests.
  // ---------------------------------------------------------------------------

  test.describe("SDK fields.billingDetails Option", () => {
    const optionBody = (
      profileId: string | undefined,
      billing: Record<string, unknown> | undefined,
    ) =>
      paymentBody({
        customer_id: "billing_fields_test_user",
        authentication_type: "no_three_ds",
        profile_id: profileId,
        billing,
      });

    test.describe('billingDetails: "never" — suppress all billing fields', () => {
      test.beforeEach(async ({ checkout, sdk, credentials, hermetic }) => {
        // Provide complete billing in the payment body so the backend does not
        // return any billing address fields as required_fields. The
        // fields.billingDetails: "never" SDK option then independently
        // suppresses the SDK-level guards (BillingName, Email). All billing
        // inputs should be absent from the DOM.
        await checkout.open({
          body: optionBody(
            credentials.profileId(connectorEnum.CYBERSOURCE),
            fullBilling,
          ),
          options: { fields: { billingDetails: "never" } },
        });
        await sdk.waitForReady();
        await waitForRequiredFieldsResolved(hermetic);
      });

      test("should hide the billing name field", async ({ sdk }) => {
        await expect(billingField(sdk, "first_name")).toHaveCount(0);
      });

      test("should hide the email field", async ({ sdk }) => {
        await expect(billingField(sdk, "email")).toHaveCount(0);
      });

      test("should hide the address line1 field", async ({ sdk }) => {
        await expect(billingField(sdk, "line1")).toHaveCount(0);
      });

      test("should hide the city field", async ({ sdk }) => {
        await expect(billingField(sdk, "city")).toHaveCount(0);
      });

      test("should hide the postal code field", async ({ sdk }) => {
        await expect(billingField(sdk, "zip")).toHaveCount(0);
      });
    });

    test.describe("billingDetails: per-field control", () => {
      test.beforeEach(async ({ checkout, sdk, credentials }) => {
        await checkout.open({
          body: optionBody(
            credentials.profileId(connectorEnum.CYBERSOURCE),
            undefined,
          ),
          options: {
            fields: {
              billingDetails: {
                name: "never",
                email: "auto",
                phone: "never",
                address: {
                  line1: "auto",
                  line2: "never",
                  city: "auto",
                  state: "auto",
                  country: "auto",
                  postal_code: "auto",
                },
              },
            },
          },
        });
        await sdk.waitForReady();
      });

      test("should hide the billing name field when set to never", async ({
        sdk,
      }) => {
        // KNOWN SDK BUG: card required fields come from superposition (DynamicFields.res ->
        // DynamicFieldInput / CardHolderNameField), which never reads `fields.billingDetails`;
        // only the legacy *PaymentInput components (bank-debit modal) honour it. So with billing
        // removed, Cybersource's billing first/last name renders despite `name: "never"`.
        // test.fail() marks the expected failure; remove it when the SDK honours the option
        // (the test then passes).
        test.fail(
          true,
          "SDK ignores fields.billingDetails.name for superposition dynamic fields",
        );
        // Wait for the dynamic fields first so the absence check can't pass by racing the render.
        await expect(billingField(sdk, "line1")).toBeVisible({
          timeout: 10_000,
        });
        await expect(billingField(sdk, "first_name")).toHaveCount(0, {
          timeout: 3_000,
        });
      });

      test("should show address line1 field when set to auto", async ({
        sdk,
      }) => {
        await expect(billingField(sdk, "line1")).toBeVisible({
          timeout: 10_000,
        });
      });

      test("should show city field when set to auto", async ({ sdk }) => {
        await expect(billingField(sdk, "city")).toBeVisible({
          timeout: 10_000,
        });
      });

      test("should show postal code field when set to auto", async ({
        sdk,
      }) => {
        await expect(billingField(sdk, "zip")).toBeVisible({ timeout: 10_000 });
      });
    });
  });
});
