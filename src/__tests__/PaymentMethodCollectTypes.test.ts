import * as PMCollectTypes from "../Types/PaymentMethodCollectTypes.bs.js";

describe("PaymentMethodCollectTypes", () => {
  describe("decodeAmount", () => {
    it("returns amount from dict when present", () => {
      const dict = { amount: "1000" };
      const result = PMCollectTypes.decodeAmount(dict, "0");
      expect(result).toBe("1000");
    });

    it("returns default when amount is not present", () => {
      const dict = {};
      const result = PMCollectTypes.decodeAmount(dict, "0");
      expect(result).toBe("0");
    });

    it("returns default when amount is undefined", () => {
      const dict = { amount: undefined };
      const result = PMCollectTypes.decodeAmount(dict, "500");
      expect(result).toBe("500");
    });
  });

  describe("decodeFlow", () => {
    it("decodes 'PayoutLinkInitiate' flow", () => {
      const dict = { flow: "PayoutLinkInitiate" };
      const result = PMCollectTypes.decodeFlow(dict, "default");
      expect(result).toBe("PayoutLinkInitiate");
    });

    it("decodes 'PayoutMethodCollect' flow", () => {
      const dict = { flow: "PayoutMethodCollect" };
      const result = PMCollectTypes.decodeFlow(dict, "default");
      expect(result).toBe("PayoutMethodCollect");
    });

    it("returns default for unknown flow", () => {
      const dict = { flow: "UnknownFlow" };
      const result = PMCollectTypes.decodeFlow(dict, "default");
      expect(result).toBe("default");
    });

    it("returns default when flow is not present", () => {
      const dict = {};
      const result = PMCollectTypes.decodeFlow(dict, "default");
      expect(result).toBe("default");
    });
  });

  describe("decodeFormLayout", () => {
    it("decodes 'journey' form layout", () => {
      const dict = { formLayout: "journey" };
      const result = PMCollectTypes.decodeFormLayout(dict, "default");
      expect(result).toBe("Journey");
    });

    it("decodes 'tabs' form layout", () => {
      const dict = { formLayout: "tabs" };
      const result = PMCollectTypes.decodeFormLayout(dict, "default");
      expect(result).toBe("Tabs");
    });

    it("returns default for unknown layout", () => {
      const dict = { formLayout: "unknown" };
      const result = PMCollectTypes.decodeFormLayout(dict, "default");
      expect(result).toBe("default");
    });

    it("returns default when formLayout is not present", () => {
      const dict = {};
      const result = PMCollectTypes.decodeFormLayout(dict, "default");
      expect(result).toBe("default");
    });
  });

  describe("decodeCard", () => {
    it("decodes 'credit' card type", () => {
      const result = PMCollectTypes.decodeCard("credit");
      expect(result).toBe("Credit");
    });

    it("decodes 'debit' card type", () => {
      const result = PMCollectTypes.decodeCard("debit");
      expect(result).toBe("Debit");
    });

    it("returns undefined for unknown card type", () => {
      const result = PMCollectTypes.decodeCard("unknown");
      expect(result).toBeUndefined();
    });

    it("returns undefined for empty string", () => {
      const result = PMCollectTypes.decodeCard("");
      expect(result).toBeUndefined();
    });
  });

  describe("decodeTransfer", () => {
    it("decodes 'ach' transfer type", () => {
      const result = PMCollectTypes.decodeTransfer("ach");
      expect(result).toBe("ACH");
    });

    it("decodes 'bacs' transfer type", () => {
      const result = PMCollectTypes.decodeTransfer("bacs");
      expect(result).toBe("Bacs");
    });

    it("decodes 'pix' transfer type", () => {
      const result = PMCollectTypes.decodeTransfer("pix");
      expect(result).toBe("Pix");
    });

    it("decodes 'sepa_bank_transfer' transfer type", () => {
      const result = PMCollectTypes.decodeTransfer("sepa_bank_transfer");
      expect(result).toBe("Sepa");
    });

    it("returns undefined for unknown transfer type", () => {
      const result = PMCollectTypes.decodeTransfer("unknown");
      expect(result).toBeUndefined();
    });
  });

  describe("decodeWallet", () => {
    it("decodes 'paypal' wallet type", () => {
      const result = PMCollectTypes.decodeWallet("paypal");
      expect(result).toBe("Paypal");
    });

    it("decodes 'venmo' wallet type", () => {
      const result = PMCollectTypes.decodeWallet("venmo");
      expect(result).toBe("Venmo");
    });

    it("returns undefined for unknown wallet type", () => {
      const result = PMCollectTypes.decodeWallet("unknown");
      expect(result).toBeUndefined();
    });
  });

  describe("decodeBankRedirect", () => {
    it("decodes 'interac' bank redirect type", () => {
      const result = PMCollectTypes.decodeBankRedirect("interac");
      expect(result).toBe("Interac");
    });

    it("returns undefined for unknown bank redirect type", () => {
      const result = PMCollectTypes.decodeBankRedirect("unknown");
      expect(result).toBeUndefined();
    });

    it("returns undefined for empty string", () => {
      const result = PMCollectTypes.decodeBankRedirect("");
      expect(result).toBeUndefined();
    });
  });

  describe("decodeFieldType", () => {
    it("decodes 'billing.address.city' to AddressCity", () => {
      const result = PMCollectTypes.decodeFieldType("billing.address.city", undefined);
      expect(result).toEqual({ TAG: "BillingAddress", _0: "AddressCity" });
    });

    it("decodes 'billing.address.line1' to AddressLine1", () => {
      const result = PMCollectTypes.decodeFieldType("billing.address.line1", undefined);
      expect(result).toEqual({ TAG: "BillingAddress", _0: "AddressLine1" });
    });

    it("decodes 'billing.address.line2' to AddressLine2", () => {
      const result = PMCollectTypes.decodeFieldType("billing.address.line2", undefined);
      expect(result).toEqual({ TAG: "BillingAddress", _0: "AddressLine2" });
    });

    it("decodes 'billing.address.state' to AddressState", () => {
      const result = PMCollectTypes.decodeFieldType("billing.address.state", undefined);
      expect(result).toEqual({ TAG: "BillingAddress", _0: "AddressState" });
    });

    it("decodes 'billing.address.zip' to AddressPincode", () => {
      const result = PMCollectTypes.decodeFieldType("billing.address.zip", undefined);
      expect(result).toEqual({ TAG: "BillingAddress", _0: "AddressPincode" });
    });

    it("decodes 'billing.phone.country_code' to PhoneCountryCode", () => {
      const result = PMCollectTypes.decodeFieldType("billing.phone.country_code", undefined);
      expect(result).toEqual({ TAG: "BillingAddress", _0: "PhoneCountryCode" });
    });

    it("decodes 'billing.phone.number' to PhoneNumber", () => {
      const result = PMCollectTypes.decodeFieldType("billing.phone.number", undefined);
      expect(result).toEqual({ TAG: "BillingAddress", _0: "PhoneNumber" });
    });

    it("decodes 'payout_method_data.bank.bic' to SepaBic", () => {
      const result = PMCollectTypes.decodeFieldType("payout_method_data.bank.bic", undefined);
      expect(result).toEqual({ TAG: "PayoutMethodData", _0: "SepaBic" });
    });

    it("decodes 'payout_method_data.bank.iban' to SepaIban", () => {
      const result = PMCollectTypes.decodeFieldType("payout_method_data.bank.iban", undefined);
      expect(result).toEqual({ TAG: "PayoutMethodData", _0: "SepaIban" });
    });

    it("decodes 'payout_method_data.card.card_holder_name' to CardHolderName", () => {
      const result = PMCollectTypes.decodeFieldType("payout_method_data.card.card_holder_name", undefined);
      expect(result).toEqual({ TAG: "PayoutMethodData", _0: "CardHolderName" });
    });

    it("decodes 'payout_method_data.card.card_number' to CardNumber", () => {
      const result = PMCollectTypes.decodeFieldType("payout_method_data.card.card_number", undefined);
      expect(result).toEqual({ TAG: "PayoutMethodData", _0: "CardNumber" });
    });

    it("returns undefined for unknown field type", () => {
      const result = PMCollectTypes.decodeFieldType("unknown.field", undefined);
      expect(result).toBeUndefined();
    });
  });

  describe("createCustomOrderMap", () => {
    it("creates a map from array of strings", () => {
      const order = ["a", "b", "c"];
      const map = PMCollectTypes.createCustomOrderMap(order);
      expect(map.get("a")).toBe(0);
      expect(map.get("b")).toBe(1);
      expect(map.get("c")).toBe(2);
    });

    it("returns empty map for empty array", () => {
      const map = PMCollectTypes.createCustomOrderMap([]);
      expect(map.size).toBe(0);
    });

    it("handles single item array", () => {
      const map = PMCollectTypes.createCustomOrderMap(["only"]);
      expect(map.size).toBe(1);
      expect(map.get("only")).toBe(0);
    });
  });

  describe("getCustomIndex", () => {
    it("returns index from map when key exists", () => {
      const map = new Map([["key1", 5]]);
      const result = PMCollectTypes.getCustomIndex("key1", map, 99);
      expect(result).toBe(5);
    });

    it("returns default index when key does not exist", () => {
      const map = new Map([["key1", 5]]);
      const result = PMCollectTypes.getCustomIndex("unknown", map, 99);
      expect(result).toBe(99);
    });

    it("returns default index for empty map", () => {
      const map = new Map();
      const result = PMCollectTypes.getCustomIndex("any", map, 42);
      expect(result).toBe(42);
    });
  });

  describe("sortByCustomOrder", () => {
    it("sorts array by custom order", () => {
      const arr = [
        { pmdMap: "billing.address.city" },
        { pmdMap: "billing.address.first_name" },
        { pmdMap: "billing.address.country" },
      ];
      const getKey = (item: any) => item.pmdMap;
      PMCollectTypes.sortByCustomOrder(arr, getKey, PMCollectTypes.customAddressOrder);
      expect(arr[0].pmdMap).toBe("billing.address.first_name");
      expect(arr[1].pmdMap).toBe("billing.address.city");
      expect(arr[2].pmdMap).toBe("billing.address.country");
    });

    it("places unknown items at the end", () => {
      const arr = [
        { pmdMap: "unknown_field" },
        { pmdMap: "billing.address.first_name" },
      ];
      const getKey = (item: any) => item.pmdMap;
      PMCollectTypes.sortByCustomOrder(arr, getKey, PMCollectTypes.customAddressOrder);
      expect(arr[0].pmdMap).toBe("billing.address.first_name");
      expect(arr[1].pmdMap).toBe("unknown_field");
    });

    it("handles empty array", () => {
      const arr: any[] = [];
      const getKey = (item: any) => item.pmdMap;
      PMCollectTypes.sortByCustomOrder(arr, getKey, PMCollectTypes.customAddressOrder);
      expect(arr.length).toBe(0);
    });
  });

  describe("customAddressOrder", () => {
    it("has expected order", () => {
      expect(PMCollectTypes.customAddressOrder).toEqual([
        "billing.address.first_name",
        "billing.address.last_name",
        "billing.address.line1",
        "billing.address.line2",
        "billing.address.city",
        "billing.address.zip",
        "billing.address.state",
        "billing.address.country",
        "billing.phone.country_code",
        "billing.phone.number",
      ]);
    });
  });

  describe("customPmdOrder", () => {
    it("has expected order", () => {
      expect(PMCollectTypes.customPmdOrder).toEqual([
        "payout_method_data.card.card_number",
        "payout_method_data.card.expiry_month",
        "payout_method_data.card.expiry_year",
        "payout_method_data.card.card_holder_name",
        "payout_method_data.bank.iban",
        "payout_method_data.bank.bic",
      ]);
    });
  });

  describe("emailValidationRegex", () => {
    it("matches valid email format", () => {
      expect(PMCollectTypes.emailValidationRegex.test("test@example.com")).toBe(true);
      expect(PMCollectTypes.emailValidationRegex.test("user.name@domain.org")).toBe(true);
    });

    it("matches partial email input", () => {
      expect(PMCollectTypes.emailValidationRegex.test("test@")).toBe(true);
      expect(PMCollectTypes.emailValidationRegex.test("test@example")).toBe(true);
    });

    it("does not match invalid patterns", () => {
      expect(PMCollectTypes.emailValidationRegex.test("invalid")).toBe(false);
    });
  });

  describe("getFieldOptions", () => {
    it("returns undefined for dict without field_type", () => {
      const dict = {};
      const result = PMCollectTypes.getFieldOptions(dict);
      expect(result).toBeUndefined();
    });

    it("returns undefined for non-object field_type", () => {
      const dict = { field_type: "not an object" };
      const result = PMCollectTypes.getFieldOptions(dict);
      expect(result).toBeUndefined();
    });

    it("returns undefined when user_address_country is missing", () => {
      const dict = { field_type: {} };
      const result = PMCollectTypes.getFieldOptions(dict);
      expect(result).toBeUndefined();
    });

    it("returns undefined when options is missing", () => {
      const dict = {
        field_type: {
          user_address_country: {},
        },
      };
      const result = PMCollectTypes.getFieldOptions(dict);
      expect(result).toBeUndefined();
    });

    it("returns BillingAddress with AddressCountry when valid", () => {
      const dict = {
        field_type: {
          user_address_country: {
            options: ["US", "CA", "GB"],
          },
        },
      };
      const result = PMCollectTypes.getFieldOptions(dict);
      expect(result).toEqual({
        TAG: "BillingAddress",
        _0: {
          TAG: "AddressCountry",
          _0: ["CA", "GB", "US"],
        },
      });
    });

    it("sorts countries alphabetically", () => {
      const dict = {
        field_type: {
          user_address_country: {
            options: ["Zimbabwe", "Argentina", "Brazil"],
          },
        },
      };
      const result = PMCollectTypes.getFieldOptions(dict);
      expect(result!._0._0).toEqual(["Argentina", "Brazil", "Zimbabwe"]);
    });

    it("handles empty options array", () => {
      const dict = {
        field_type: {
          user_address_country: {
            options: [],
          },
        },
      };
      const result = PMCollectTypes.getFieldOptions(dict);
      expect(result).toEqual({
        TAG: "BillingAddress",
        _0: {
          TAG: "AddressCountry",
          _0: [],
        },
      });
    });
  });

  describe("decodePayoutDynamicFields", () => {
    const defaultDynamicPmdFields = { address: undefined, payoutMethodData: [] };

    it("returns default for null input", () => {
      const result = PMCollectTypes.decodePayoutDynamicFields(null, defaultDynamicPmdFields);
      expect(result.address).toBeUndefined();
      expect(result.payoutMethodData).toEqual(defaultDynamicPmdFields);
    });

    it("returns default for non-object input", () => {
      const result = PMCollectTypes.decodePayoutDynamicFields("string", defaultDynamicPmdFields);
      expect(result.address).toBeUndefined();
      expect(result.payoutMethodData).toEqual(defaultDynamicPmdFields);
    });

    it("returns default for empty object", () => {
      const result = PMCollectTypes.decodePayoutDynamicFields({}, defaultDynamicPmdFields);
      expect(result.address).toBeUndefined();
      expect(result.payoutMethodData).toEqual(defaultDynamicPmdFields);
    });

    it("parses billing address field correctly", () => {
      const json = {
        "billing.address.first_name": {
          required_field: "billing.address.first_name",
          display_name: "First Name",
          value: "John",
        },
      };
      const result = PMCollectTypes.decodePayoutDynamicFields(json, defaultDynamicPmdFields);
      expect(result.address).toBeDefined();
      expect(result.address!.length).toBe(1);
      expect(result.address![0].pmdMap).toBe("billing.address.first_name");
      expect(result.address![0].displayName).toBe("First Name");
    });

    it("parses payout method data field correctly", () => {
      const json = {
        "payout_method_data.card.card_number": {
          required_field: "payout_method_data.card.card_number",
          display_name: "Card Number",
          value: "4111111111111111",
        },
      };
      const result = PMCollectTypes.decodePayoutDynamicFields(json, defaultDynamicPmdFields);
      expect(result.payoutMethodData.length).toBe(1);
    });

    it("skips fields missing required_field", () => {
      const json = {
        "billing.address.first_name": {
          display_name: "First Name",
          value: "John",
        },
      };
      const result = PMCollectTypes.decodePayoutDynamicFields(json, defaultDynamicPmdFields);
      expect(result.address).toBeUndefined();
    });

    it("skips fields missing display_name", () => {
      const json = {
        "billing.address.first_name": {
          required_field: "billing.address.first_name",
          value: "John",
        },
      };
      const result = PMCollectTypes.decodePayoutDynamicFields(json, defaultDynamicPmdFields);
      expect(result.address).toBeUndefined();
    });

    it("skips fields with unknown field type", () => {
      const json = {
        "unknown.field": {
          required_field: "unknown.field",
          display_name: "Unknown",
          value: "value",
        },
      };
      const result = PMCollectTypes.decodePayoutDynamicFields(json, defaultDynamicPmdFields);
      expect(result.address).toBeUndefined();
      expect(result.payoutMethodData).toEqual(defaultDynamicPmdFields);
    });
  });

  describe("decodePayoutConfirmResponse", () => {
    it("returns undefined for null input", () => {
      const result = PMCollectTypes.decodePayoutConfirmResponse(null);
      expect(result).toBeUndefined();
    });

    it("returns undefined for non-object input", () => {
      const result = PMCollectTypes.decodePayoutConfirmResponse("string");
      expect(result).toBeUndefined();
    });

    it("returns undefined when status is missing", () => {
      const result = PMCollectTypes.decodePayoutConfirmResponse({});
      expect(result).toBeUndefined();
    });

    it("returns SuccessResponse for valid success response", () => {
      const json = {
        status: "success",
        payout_id: "payout_123",
        merchant_id: "merchant_123",
        customer_id: "customer_123",
        amount: 100.0,
        currency: "USD",
        payout_type: "card",
        connector: "stripe",
      };
      const result = PMCollectTypes.decodePayoutConfirmResponse(json);
      expect(result).toBeDefined();
      expect(result!.TAG).toBe("SuccessResponse");
      expect(result!._0.payoutId).toBe("payout_123");
      expect(result!._0.status).toBe("Success");
    });

    it("decodes all status values correctly", () => {
      const statuses = [
        { input: "cancelled", expected: "Cancelled" },
        { input: "expired", expected: "Expired" },
        { input: "failed", expected: "Failed" },
        { input: "ineligible", expected: "Ineligible" },
        { input: "initiated", expected: "Initiated" },
        { input: "pending", expected: "Pending" },
        { input: "requires_confirmation", expected: "RequiresConfirmation" },
        { input: "requires_creation", expected: "RequiresCreation" },
        { input: "requires_fulfillment", expected: "RequiresFulfillment" },
        { input: "requires_payout_method_data", expected: "RequiresPayoutMethodData" },
        { input: "requires_vendor_account_creation", expected: "RequiresVendorAccountCreation" },
        { input: "reversed", expected: "Reversed" },
        { input: "success", expected: "Success" },
      ];

      statuses.forEach(({ input, expected }) => {
        const json = {
          status: input,
          payout_id: "payout_123",
          merchant_id: "merchant_123",
          customer_id: "customer_123",
          amount: 100.0,
          currency: "USD",
          payout_type: "card",
        };
        const result = PMCollectTypes.decodePayoutConfirmResponse(json);
        expect(result!._0.status).toBe(expected);
      });
    });

    it("returns ErrorResponse for error response", () => {
      const json = {
        type: "invalid_request",
        code: "error_code",
        message: "Error message",
        reason: "Error reason",
      };
      const result = PMCollectTypes.decodePayoutConfirmResponse(json);
      expect(result).toBeDefined();
      expect(result!.TAG).toBe("ErrorResponse");
      expect(result!._0.errorType).toBe("invalid_request");
      expect(result!._0.code).toBe("error_code");
      expect(result!._0.message).toBe("Error message");
    });

    it("returns undefined when required success fields are missing", () => {
      const json = {
        status: "success",
        payout_id: "payout_123",
      };
      const result = PMCollectTypes.decodePayoutConfirmResponse(json);
      expect(result).toBeUndefined();
    });

    it("returns undefined when required error fields are missing", () => {
      const json = {
        type: "error",
      };
      const result = PMCollectTypes.decodePayoutConfirmResponse(json);
      expect(result).toBeUndefined();
    });

    it("includes optional fields in success response", () => {
      const json = {
        status: "success",
        payout_id: "payout_123",
        merchant_id: "merchant_123",
        customer_id: "customer_123",
        amount: 100.0,
        currency: "USD",
        payout_type: "card",
        connector: "stripe",
        error_message: "Some error",
        error_code: "ERR001",
        connector_transaction_id: "txn_123",
      };
      const result = PMCollectTypes.decodePayoutConfirmResponse(json);
      expect(result!._0.connector).toBe("stripe");
      expect(result!._0.errorMessage).toBe("Some error");
      expect(result!._0.errorCode).toBe("ERR001");
      expect(result!._0.connectorTransactionId).toBe("txn_123");
    });
  });

  describe("decodePaymentMethodTypeArray", () => {
    const defaultDynamicPmdFields = (pmt: any) => ({ address: undefined, payoutMethodData: [] });

    it("returns empty arrays for null input", () => {
      const result = PMCollectTypes.decodePaymentMethodTypeArray(null, defaultDynamicPmdFields);
      expect(result).toEqual([[], []]);
    });

    it("returns empty arrays for non-array input", () => {
      const result = PMCollectTypes.decodePaymentMethodTypeArray("not an array", defaultDynamicPmdFields);
      expect(result).toEqual([[], []]);
    });

    it("returns empty arrays for empty array input", () => {
      const result = PMCollectTypes.decodePaymentMethodTypeArray([], defaultDynamicPmdFields);
      expect(result).toEqual([[], []]);
    });

    it("decodes valid payment method types", () => {
      const jsonArray = [
        {
          payment_method: "card",
          payment_method_types_info: [
            {
              payment_method_type: "credit",
              required_fields: {},
            },
          ],
        },
      ];
      const result = PMCollectTypes.decodePaymentMethodTypeArray(jsonArray, defaultDynamicPmdFields);
      expect(result[0].length).toBe(1);
      expect(result[0][0]).toEqual({ TAG: "Card", _0: "Credit" });
    });

    it("skips invalid payment method types", () => {
      const jsonArray = [
        {
          payment_method: "unknown",
          payment_method_types_info: [],
        },
      ];
      const result = PMCollectTypes.decodePaymentMethodTypeArray(jsonArray, defaultDynamicPmdFields);
      expect(result).toEqual([[], []]);
    });

    it("handles multiple payment method types", () => {
      const jsonArray = [
        {
          payment_method: "card",
          payment_method_types_info: [
            { payment_method_type: "credit", required_fields: {} },
            { payment_method_type: "debit", required_fields: {} },
          ],
        },
      ];
      const result = PMCollectTypes.decodePaymentMethodTypeArray(jsonArray, defaultDynamicPmdFields);
      expect(result[0].length).toBe(2);
    });

    it("handles wallet payment method type", () => {
      const jsonArray = [
        {
          payment_method: "wallet",
          payment_method_types_info: [
            { payment_method_type: "paypal", required_fields: {} },
          ],
        },
      ];
      const result = PMCollectTypes.decodePaymentMethodTypeArray(jsonArray, defaultDynamicPmdFields);
      expect(result[0].length).toBe(1);
      expect(result[0][0]).toEqual({ TAG: "Wallet", _0: "Paypal" });
    });

    it("handles bank_redirect payment method type", () => {
      const jsonArray = [
        {
          payment_method: "bank_redirect",
          payment_method_types_info: [
            { payment_method_type: "interac", required_fields: {} },
          ],
        },
      ];
      const result = PMCollectTypes.decodePaymentMethodTypeArray(jsonArray, defaultDynamicPmdFields);
      expect(result[0].length).toBe(1);
      expect(result[0][0]).toEqual({ TAG: "BankRedirect", _0: "Interac" });
    });

    it("handles bank_transfer payment method type", () => {
      const jsonArray = [
        {
          payment_method: "bank_transfer",
          payment_method_types_info: [
            { payment_method_type: "ach", required_fields: {} },
          ],
        },
      ];
      const result = PMCollectTypes.decodePaymentMethodTypeArray(jsonArray, defaultDynamicPmdFields);
      expect(result[0].length).toBe(1);
      expect(result[0][0]).toEqual({ TAG: "BankTransfer", _0: "ACH" });
    });
  });
});
