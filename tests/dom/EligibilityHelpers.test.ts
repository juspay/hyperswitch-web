import { describe, expect, it, vi } from "vitest";
import * as Eligibility from "../../src/Utilities/EligibilityHelpers.bs.js";
import { executionDeferred, executionLogger, executionSecret, executionState } from "../helpers/execution-fixtures";
const surcharge = {
  surcharge: {
    type: "percentage",
    value: 2
  },
  tax_on_surcharge: 1,
  display_surcharge_amount: 2,
  display_tax_on_surcharge_amount: 1,
  display_total_surcharge_amount: 3
};
const offers = {
  uplifted_offer_quote_ids: ["", "offer_execution"],
  eligible_offers: [{
    offer_quote_id: ""
  }, {
    offer_quote_id: "offer_execution",
    offer_amount: 100,
    currency: "USD",
    code: "SAVE",
    title: "Save",
    description: "Execution offer"
  }]
};
describe("eligibility response and request state", () => {
  it.each([[{}, undefined], [{
    sdk_next_action: {
      next_action: "deny"
    }
  }, ""], [{
    sdk_next_action: {
      next_action: {
        deny: {
          message: "Card unavailable"
        }
      }
    }
  }, "Card unavailable"], [{
    sdk_next_action: {
      next_action: "allow"
    }
  }, undefined], [{
    sdk_next_action: {
      next_action: 4
    }
  }, undefined], [{
    sdk_next_action: {
      next_action: true
    }
  }, undefined], [{
    sdk_next_action: {
      next_action: {}
    }
  }, undefined], [{
    sdk_next_action: {
      next_action: null
    }
  }, undefined]])("parses deny variants: %j", (json, result) => {
    expect(Eligibility.parseSdkNextActionError(json)).toBe(result);
  });
  it("parses surcharge and filters empty offers without losing amounts", () => {
    expect(Eligibility.parseEligibilityResponse({
      surcharge_details: surcharge,
      offer_details: offers,
      amount_details: {
        total_amount: 1000,
        net_amount: 900,
        currency: "USD"
      }
    })).toEqual({
      eligibilityError: undefined,
      surchargeDetails: {
        surcharge: {
          type: "percentage",
          value: 2
        },
        taxOnSurcharge: 1,
        displaySurchargeAmount: 2,
        displayTaxOnSurchargeAmount: 1,
        displayTotalSurchargeAmount: 3
      },
      offerDetails: {
        offerQuoteIds: ["offer_execution"],
        eligibleOffers: [{
          offerQuoteId: "offer_execution",
          offerAmount: 100,
          currency: "USD",
          code: "SAVE",
          title: "Save",
          description: "Execution offer"
        }],
        amountDetails: {
          totalAmount: 1000,
          netAmount: 900,
          currency: "USD"
        }
      }
    });
  });
  it("handles missing, malformed and zero-value optional response fields", () => {
    for (const json of [null, {}, {
      surcharge_details: {}
    }, {
      surcharge_details: {
        display_total_surcharge_amount: -1
      },
      offer_details: {}
    }, {
      offer_details: {
        eligible_offers: [{
          offer_quote_id: ""
        }]
      }
    }]) {
      expect(Eligibility.parseEligibilityResponse(json)).toEqual({
        eligibilityError: undefined,
        surchargeDetails: undefined,
        offerDetails: undefined
      });
    }
    expect(Eligibility.parseEligibilitySurchargeDetails({
      surcharge_details: {
        ...surcharge,
        tax_on_surcharge: "invalid"
      }
    }).taxOnSurcharge).toBeUndefined();
    expect(Eligibility.parseEligibilityAmountDetails({
      amount_details: {}
    })).toEqual({
      totalAmount: 0,
      netAmount: 0,
      currency: ""
    });
    expect(Eligibility.parseEligibilityOfferDetails({
      offer_details: {
        eligible_offers: [{
          offer_quote_id: "only"
        }]
      }
    }).eligibleOffers[0]).toEqual({
      offerQuoteId: "only",
      offerAmount: 0,
      currency: "",
      code: "",
      title: "",
      description: ""
    });
  });
  it.each([undefined, "", "Specific restriction"])("provides translated fallback or custom message: %s", error => {
    expect(Eligibility.getCardEligibilityErrorText(error, {
      cardNotEligibleText: "Translated fallback"
    })).toBe(error || "Translated fallback");
  });
  it.each([false, true])("aborts predecessor and settles request state (reject=%s)", async reject => {
    const old = new AbortController();
    const ref = {
      current: old
    };
    const pending = executionState(false),
      charge = executionState<{ old?: boolean; displayTotalSurchargeAmount?: number } | undefined>({
        old: true
      }),
      offer = executionState({
        old: true
      }),
      error = executionState("old");
    const logger = executionLogger();
    const fetchEligibility = vi.fn(async (...args) => {
      expect(old.signal.aborted).toBe(true);
      expect(args[7]).toBe(ref.current!.signal);
      expect(pending.value).toBe(true);
      expect(charge.value).toBeUndefined();
      expect(offer.value).toBeUndefined();
      if (reject) {
        throw new Error("execution offline");
      }
      return {
        sdk_next_action: {
          next_action: "deny"
        },
        surcharge_details: surcharge
      };
    });
    await Eligibility.startEligibilityCheck(ref, executionSecret, "pk_execution", logger, "pod_execution", [], undefined, "https://api.sdk.test", pending.set, charge.set, offer.set, error.set, "Execution failed", fetchEligibility);
    expect(pending.history).toEqual([true, false]);
    expect(error.value).toBe(reject ? undefined : "");
    expect(charge.value?.displayTotalSurchargeAmount).toBe(reject ? undefined : 3);
    expect(logger.setLogError).toHaveBeenCalledTimes(reject ? 1 : 0);
  });
  it("clears pending without fetching when no client secret exists, including optional error setter", async () => {
    const pending = executionState(true);
    const fetchEligibility = vi.fn();
    await Eligibility.startEligibilityCheck({
      current: undefined as AbortController | undefined
    }, undefined, "pk", executionLogger(), "", [], undefined, "", pending.set, vi.fn(), vi.fn(), undefined, "", fetchEligibility);
    expect(pending.value).toBe(false);
    expect(fetchEligibility).not.toHaveBeenCalled();
    await Eligibility.performEligibilityCheck("secret", "pk", executionLogger(), "", [], undefined, "", new AbortController().signal, pending.set, vi.fn(), vi.fn(), undefined, "", async () => ({}));
    expect(pending.value).toBe(false);
  });
  it("ignores older responses after a replacement request completes", async () => {
    const ref = {
      current: undefined as AbortController | undefined
    };
    const old = executionDeferred(),
      current = executionDeferred();
    const pending = executionState(false),
      charge = executionState(),
      offer = executionState(),
      error = executionState();
    const args = [ref, executionSecret, "pk_execution", executionLogger(), "", [], undefined, "https://api.sdk.test", pending.set, charge.set, offer.set, error.set, "Execution failure"];
    const first = Eligibility.startEligibilityCheck(...args, () => old.promise);
    const oldSignal = ref.current!.signal;
    const second = Eligibility.startEligibilityCheck(...args, () => current.promise);
    expect(oldSignal.aborted).toBe(true);
    current.resolve({
      sdk_next_action: {
        next_action: {
          deny: {
            message: "Current card restriction"
          }
        }
      }
    });
    await second;
    old.resolve({
      sdk_next_action: {
        next_action: {
          deny: {
            message: "Stale restriction"
          }
        }
      }
    });
    await first;
    expect(error.value).toBe("Current card restriction");
    expect(pending.value).toBe(false);
  });
  it("does not clear newer pending state or log an error when an aborted request rejects", async () => {
    const ref = {
      current: undefined as AbortController | undefined
    };
    const old = executionDeferred(),
      current = executionDeferred();
    const pending = executionState(false),
      error = executionState("current");
    const logger = executionLogger();
    const args = [ref, executionSecret, "pk_execution", logger, "", [], undefined, "", pending.set, vi.fn(), vi.fn(), error.set, "Execution failure"];
    const first = Eligibility.startEligibilityCheck(...args, () => old.promise);
    const second = Eligibility.startEligibilityCheck(...args, () => current.promise);
    old.reject(new DOMException("Aborted", "AbortError"));
    await first;
    expect(pending.value).toBe(true);
    expect(error.value).toBe("current");
    expect(logger.setLogError).not.toHaveBeenCalled();
    current.resolve({});
    await second;
  });
});
