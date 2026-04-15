import * as APIUtils from "../Utilities/APIHelpers/APIUtils.bs.js";

describe("APIUtils", () => {
  describe("CommonUtils.buildQueryParams", () => {
    it("returns empty string for empty list", () => {
      const result = APIUtils.CommonUtils.buildQueryParams(undefined as any);
      expect(result).toBe("");
    });

    it("builds query string with single param", () => {
      const params = {
        hd: ["key", "value"],
        tl: undefined as any,
      };
      const result = APIUtils.CommonUtils.buildQueryParams(params);
      expect(result).toBe("?key=value");
    });

    it("builds query string with multiple params", () => {
      const params = {
        hd: ["key1", "value1"],
        tl: {
          hd: ["key2", "value2"],
          tl: undefined as any,
        },
      };
      const result = APIUtils.CommonUtils.buildQueryParams(params);
      expect(result).toBe("?key1=value1&key2=value2");
    });

    it("handles empty param list (zero)", () => {
      const result = APIUtils.CommonUtils.buildQueryParams(0 as any);
      expect(result).toBe("");
    });

    it("builds query with three params", () => {
      const params = {
        hd: ["a", "1"],
        tl: {
          hd: ["b", "2"],
          tl: {
            hd: ["c", "3"],
            tl: undefined as any,
          },
        },
      };
      const result = APIUtils.CommonUtils.buildQueryParams(params);
      expect(result).toBe("?a=1&b=2&c=3");
    });

    it("encodes param values correctly", () => {
      const params = {
        hd: ["client_secret", "cs_test_123"],
        tl: undefined as any,
      };
      const result = APIUtils.CommonUtils.buildQueryParams(params);
      expect(result).toBe("?client_secret=cs_test_123");
    });

    it("handles numeric-like values as strings", () => {
      const params = {
        hd: ["amount", "1000"],
        tl: undefined as any,
      };
      const result = APIUtils.CommonUtils.buildQueryParams(params);
      expect(result).toBe("?amount=1000");
    });
  });

  describe("generateApiUrlV1", () => {
    const baseUrl = "https://api.test.com";

    describe("FetchPaymentMethodList", () => {
      it("should generate URL for FetchPaymentMethodList with client_secret", () => {
        const params = {
          clientSecret: "pay_abc123_secret_xyz",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchPaymentMethodList");
        expect(result).toBe(`${baseUrl}/account/payment_methods?client_secret=pay_abc123_secret_xyz`);
      });

      it("should generate URL without client_secret when not provided", () => {
        const params = {
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchPaymentMethodList");
        expect(result).toBe(`${baseUrl}/account/payment_methods`);
      });

      it("should not include client_secret when sdkAuthorization is provided", () => {
        const params = {
          clientSecret: "pay_abc123_secret_xyz",
          sdkAuthorization: "Bearer token123",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchPaymentMethodList");
        expect(result).toBe(`${baseUrl}/account/payment_methods`);
      });
    });

    describe("FetchCustomerPaymentMethodList", () => {
      it("should generate URL for FetchCustomerPaymentMethodList", () => {
        const params = {
          clientSecret: "pay_test_secret_abc",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchCustomerPaymentMethodList");
        expect(result).toBe(`${baseUrl}/customers/payment_methods?client_secret=pay_test_secret_abc`);
      });
    });

    describe("RetrievePaymentIntent", () => {
      it("should generate URL for RetrievePaymentIntent with payment ID", () => {
        const params = {
          clientSecret: "pay_abc123_secret_xyz",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "RetrievePaymentIntent");
        expect(result).toBe(`${baseUrl}/payments/pay_abc123?client_secret=pay_abc123_secret_xyz`);
      });

      it("should include force_sync when provided and true", () => {
        const params = {
          clientSecret: "pay_abc123_secret_xyz",
          forceSync: "true",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "RetrievePaymentIntent");
        expect(result).toContain("force_sync=true");
      });

      it("should not include force_sync for other apiCallTypes", () => {
        const params = {
          clientSecret: "pay_abc123_secret_xyz",
          forceSync: "true",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchPaymentMethodList");
        expect(result).not.toContain("force_sync");
      });
    });

    describe("FetchBlockedBins", () => {
      it("should generate URL for FetchBlockedBins with data_kind param", () => {
        const params = {
          clientSecret: "pay_test_secret_abc",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchBlockedBins");
        expect(result).toContain(`${baseUrl}/blocklist`);
        expect(result).toContain("data_kind=card_bin");
        expect(result).toContain("client_secret=pay_test_secret_abc");
      });
    });

    describe("FetchSessions", () => {
      it("should generate URL for FetchSessions", () => {
        const params = {
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchSessions");
        expect(result).toBe(`${baseUrl}/payments/session_tokens`);
      });
    });

    describe("FetchThreeDsAuth", () => {
      it("should generate URL for FetchThreeDsAuth with payment ID", () => {
        const params = {
          clientSecret: "pay_xyz789_secret_token",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchThreeDsAuth");
        expect(result).toBe(`${baseUrl}/payments/pay_xyz789/3ds/authentication`);
      });
    });

    describe("CalculateTax", () => {
      it("should generate URL for CalculateTax with payment ID", () => {
        const params = {
          clientSecret: "pay_tax123_secret_abc",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "CalculateTax");
        expect(result).toBe(`${baseUrl}/payments/pay_tax123/calculate_tax`);
      });
    });

    describe("CreatePaymentMethod", () => {
      it("should generate URL for CreatePaymentMethod", () => {
        const params = {
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "CreatePaymentMethod");
        expect(result).toBe(`${baseUrl}/payment_methods`);
      });
    });

    describe("CallAuthLink", () => {
      it("should generate URL for CallAuthLink", () => {
        const params = {
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "CallAuthLink");
        expect(result).toBe(`${baseUrl}/payment_methods/auth/link`);
      });
    });

    describe("CallAuthExchange", () => {
      it("should generate URL for CallAuthExchange", () => {
        const params = {
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "CallAuthExchange");
        expect(result).toBe(`${baseUrl}/payment_methods/auth/exchange`);
      });
    });

    describe("RetrieveStatus", () => {
      it("should generate URL for RetrieveStatus with poll ID", () => {
        const params = {
          pollId: "poll_abc123",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "RetrieveStatus");
        expect(result).toBe(`${baseUrl}/poll/status/poll_abc123`);
      });
    });

    describe("ConfirmPayout", () => {
      it("should generate URL for ConfirmPayout with payout ID", () => {
        const params = {
          payoutId: "payout_xyz789",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "ConfirmPayout");
        expect(result).toBe(`${baseUrl}/payouts/payout_xyz789/confirm`);
      });
    });

    describe("FetchEnabledAuthnMethodsToken", () => {
      it("should generate URL for FetchEnabledAuthnMethodsToken with authentication ID", () => {
        const params = {
          authenticationId: "auth_abc123",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchEnabledAuthnMethodsToken");
        expect(result).toBe(`${baseUrl}/authentication/auth_abc123/enabled_authn_methods_token`);
      });
    });

    describe("FetchEligibilityCheck", () => {
      it("should generate URL for FetchEligibilityCheck with authentication ID", () => {
        const params = {
          authenticationId: "auth_xyz789",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchEligibilityCheck");
        expect(result).toBe(`${baseUrl}/authentication/auth_xyz789/eligibility-check`);
      });
    });

    describe("FetchAuthenticationSync", () => {
      it("should generate URL for FetchAuthenticationSync with merchant ID and authentication ID", () => {
        const params = {
          merchantId: "merchant_123",
          authenticationId: "auth_abc456",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchAuthenticationSync");
        expect(result).toBe(`${baseUrl}/authentication/merchant_123/auth_abc456/sync`);
      });
    });

    describe("edge cases", () => {
      it("should handle empty clientSecret by including it in query params", () => {
        const params = {
          clientSecret: "",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchPaymentMethodList");
        expect(result).toBe(`${baseUrl}/account/payment_methods?client_secret=`);
      });

      it("should handle clientSecret without _secret_ delimiter", () => {
        const params = {
          clientSecret: "pay_abc123",
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "RetrievePaymentIntent");
        expect(result).toContain("/payments/");
      });

      it("should handle undefined optional params", () => {
        const params = {
          customBackendBaseUrl: baseUrl,
        };
        const result = APIUtils.generateApiUrlV1(params, "FetchPaymentMethodList");
        expect(result).toBe(`${baseUrl}/account/payment_methods`);
      });
    });
  });
});
