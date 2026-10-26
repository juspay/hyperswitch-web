// Narrow only the observed command envelopes consumed below; posted() stays unknown[].
type CoordinatorCommand = { cardFormCoordinatorCommand?: string; confirmId: string };
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import * as Group from "../../src/hyper-loader/PaymentsGroup.bs.js";
import { card, installChannels, logger, message, mountField, posted, response } from "../helpers/lifecycle-fixtures";
const forms: ReturnType<typeof Group.makeCardForm>[] = [];
function make() {
  const log = logger();
  const form = Group.makeCardForm({
    clientSecret: "pi_unit_secret_test",
    sdkAuthorization: "",
    publishableKey: "pk_test_unit",
    logger: log
  });
  forms.push(form);
  return {
    form,
    log
  };
}
const coordinator = () => document.querySelector<HTMLIFrameElement>('iframe[src*="componentName=cardFormCoordinator"]')!;
beforeEach(() => vi.stubGlobal("fetch", vi.fn().mockResolvedValue(response({
  payment_methods: []
}))));
afterEach(() => forms.splice(0).forEach(form => form.deinit()));
describe("PaymentsGroup public confirmation lifecycle", () => {
  it("relays keyboard submission only from its frames and suppresses relay during a confirm", async () => {
    installChannels();
    const {
      form
    } = make();
    const handle = form.create("cardNumber", {});
    const field = mountField(handle, "submit-number");
    const iframe = coordinator();
    const post = vi.spyOn(iframe.contentWindow!, "postMessage");
    message(iframe, {
      iframeMounted: true
    });
    post.mockClear();
    message(field.iframe, {
      doSubmit: true
    }, {
      source: window
    });
    message(field.iframe, {
      doSubmit: true
    }, {
      origin: "https://attacker.test"
    });
    expect(post).not.toHaveBeenCalled();
    message(field.iframe, {
      doSubmit: true
    });
    expect(posted(post)).toEqual([{
      cardFormCoordinatorCommand: "initiateConfirm",
      flow: "payments"
    }]);
    const pending = form.confirmPayment();
    const command = posted(post).at(-1) as CoordinatorCommand;
    const count = post.mock.calls.length;
    message(field.iframe, {
      doSubmit: true
    });
    expect(post).toHaveBeenCalledTimes(count);
    message(iframe, {
      confirmId: command.confirmId,
      submitSuccessful: true,
      data: {
        id: "pi_keyboard"
      }
    });
    await expect(pending).resolves.toEqual({
      id: "pi_keyboard"
    });
    message(iframe, {
      doSubmit: true
    });
    expect(posted(post).at(-1)).toEqual({
      cardFormCoordinatorCommand: "initiateConfirm",
      flow: "payments"
    });
    form.deinit();
    const afterDeinit = post.mock.calls.length;
    message(field.iframe, {
      doSubmit: true
    });
    expect(post).toHaveBeenCalledTimes(afterDeinit);
  });
  it("relays CVC keyboard submission only when the saved-card token is present", () => {
    installChannels();
    const {
      form
    } = make();
    const field = form.create("cardCvc", {});
    const mounted = mountField(field, "submit-cvc");
    const iframe = coordinator();
    const post = vi.spyOn(iframe.contentWindow!, "postMessage");
    message(iframe, {
      iframeMounted: true
    });
    post.mockClear();
    message(mounted.iframe, {
      doSubmit: true
    });
    expect(post).not.toHaveBeenCalled();
    field.update({
      savedCard: {
        paymentToken: "tok_keyboard_saved"
      }
    });
    message(mounted.iframe, {
      doSubmit: true
    });
    expect(posted(post).at(-1)).toEqual({
      cardFormCoordinatorCommand: "initiateConfirm",
      flow: "savedCardCvc",
      paymentToken: "tok_keyboard_saved"
    });
  });
  it("emits group readiness when all mounted fields complete and emits again after invalidation", () => {
    const {
      form
    } = make();
    const ready = vi.fn();
    form.on("ready", ready);
    const mounted = ["cardNumber", "cardExpiry", "cardCvc"].map(type => {
      const handle = form.create(type, {});
      const frame = mountField(handle, `payments-${type}`);
      return {
        ...frame,
        handle
      };
    });
    const change = vi.fn();
    mounted[0].handle.on("change", change);
    const complete = {
      cardStateUpdate: {
        ...card,
        fieldStatus: {
          complete: true,
          empty: false,
          isCardValid: true
        }
      }
    };
    message(mounted[0].iframe, complete, {
      origin: "https://attacker.test"
    });
    expect(change).not.toHaveBeenCalled();
    message(mounted[0].iframe, complete);
    message(mounted[1].iframe, complete);
    expect(ready).not.toHaveBeenCalled();
    message(mounted[2].iframe, complete);
    expect(ready).toHaveBeenCalledWith({
      elementType: "paymentsGroup"
    });
    expect(change).toHaveBeenCalledWith({
      elementType: "cardNumber",
      complete: true,
      empty: false,
      valid: true,
      brand: "Visa"
    });
    message(mounted[2].iframe, complete);
    expect(ready).toHaveBeenCalledOnce();
    message(mounted[2].iframe, {
      cardStateUpdate: {
        fieldStatus: {
          complete: false
        }
      }
    });
    message(mounted[2].iframe, complete);
    expect(ready).toHaveBeenCalledTimes(2);
    form.update({
      appearance: {
        theme: "night"
      }
    });
    expect(posted(mounted[0].post).at(-1)).toEqual({
      paymentElementsUpdate: true,
      options: {
        appearance: {
          theme: "night"
        }
      }
    });
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const count = mounted[0].post.mock.calls.length;
    form.update({
      clientSecret: "different"
    });
    expect(warn).toHaveBeenCalledOnce();
    expect(mounted[0].post).toHaveBeenCalledTimes(count);
  });
  it("reports invalid field sets and missing saved card token via its public promise", async () => {
    const {
      form
    } = make();
    await expect(form.confirmPayment()).resolves.toMatchObject({
      error: {
        code: "validation_error",
        message: "No card fields are mounted"
      }
    });
    form.create("cardCvc", {});
    await expect(form.confirmPayment()).resolves.toMatchObject({
      error: {
        code: "validation_error",
        message: expect.stringContaining("paymentToken")
      }
    });
    form.create("cardholderName", {});
    await expect(form.confirmPayment()).resolves.toMatchObject({
      error: {
        code: "validation_error",
        message: expect.stringContaining("cardNumber")
      }
    });
  });
  it("queues confirm until trusted readiness, rejects duplicates, and retries after validation failure", async () => {
    const {
      form,
      log
    } = make();
    form.create("cardNumber", {});
    const iframe = coordinator();
    const post = vi.spyOn(iframe.contentWindow!, "postMessage");
    const first = form.confirmPayment();
    await expect(form.confirmPayment()).resolves.toMatchObject({
      error: {
        code: "confirm_in_progress"
      }
    });
    message(iframe, {
      iframeMounted: true
    }, {
      origin: "https://attacker.test"
    });
    message(iframe, {
      iframeMounted: true
    }, {
      source: window
    });
    expect(post).not.toHaveBeenCalled();
    message(iframe, {
      iframeMounted: true
    });
    const command = (posted(post) as CoordinatorCommand[]).find(value => value.cardFormCoordinatorCommand)!;
    expect(command).toMatchObject({
      flow: "payments",
      cardFormCoordinatorCommand: "initiateConfirm"
    });
    message(iframe, {
      confirmId: "wrong",
      submitSuccessful: true,
      data: {
        id: "wrong"
      }
    });
    await expect(form.confirmPayment()).resolves.toMatchObject({
      error: {
        code: "confirm_in_progress"
      }
    });
    message(iframe, {
      confirmId: command.confirmId,
      paymentConfirmFail: true,
      errorMessage: "cardExpiry is required"
    });
    await expect(first).resolves.toMatchObject({
      error: {
        code: "validation_error",
        message: "cardExpiry is required"
      }
    });
    const retry = form.confirmPayment();
    const next = posted(post).at(-1) as CoordinatorCommand;
    expect(next.confirmId).not.toBe(command.confirmId);
    message(iframe, {
      confirmId: next.confirmId,
      submitSuccessful: true,
      data: {
        id: "pi_test",
        status: "succeeded"
      }
    });
    await expect(retry).resolves.toEqual({
      id: "pi_test",
      status: "succeeded"
    });
    for (const raw of Object.values(card)) expect(JSON.stringify(log.setLogInfo.mock.calls)).not.toContain(raw);
  });
  it("dispatches saved-card CVC flow with the token, and settles in-flight work on repeated deinit", async () => {
    const {
      form,
      log
    } = make();
    form.create("cardCvc", {
      savedCard: {
        paymentToken: "tok_saved_test"
      }
    });
    const iframe = coordinator();
    const post = vi.spyOn(iframe.contentWindow!, "postMessage");
    message(iframe, {
      iframeMounted: true
    });
    const pending = form.confirmPayment();
    expect(posted(post).at(-1)).toMatchObject({
      flow: "savedCardCvc",
      paymentToken: "tok_saved_test"
    });
    form.deinit();
    form.deinit();
    await expect(pending).resolves.toMatchObject({
      error: {
        code: "group_deinitialized",
        message: expect.stringContaining("may still have gone through")
      }
    });
    expect(form.fields.contents).toEqual({});
    expect(coordinator()).toBeNull();
    expect(JSON.stringify(log.setLogInfo.mock.calls)).not.toContain("tok_saved_test");
  });
  it("only invokes group change callbacks for the coordinator source and origin", () => {
    const {
      form
    } = make();
    form.create("cardNumber", {});
    const iframe = coordinator();
    const change = vi.fn();
    form.on("change", change);
    for (const options of [{
      origin: "https://attacker.test"
    }, {
      source: window
    }]) message(iframe, {
      eventName: "cardDetailsChange"
    }, options);
    expect(change).not.toHaveBeenCalled();
    message(iframe, {
      eventName: "cardDetailsChange",
      cardInfo: {
        last4: "1111"
      }
    });
    expect(change).toHaveBeenCalledOnce();
    form.deinit();
    message(iframe, {
      eventName: "cardDetailsChange"
    });
    expect(change).toHaveBeenCalledOnce();
  });
  it("readiness requires every core field snapshot, ignores optional name, and falls when incomplete", () => {
    const entries: { contents: Record<string, { fieldType: string; lastStateRef: { contents: { fieldStatus: { complete: boolean } } | undefined } }> } = {
      contents: {}
    };
    expect(Group.computeGroupReadiness(entries)).toBe(false);
    for (const fieldType of ["cardNumber", "cardExpiry", "cardCvc"]) {
      entries.contents[fieldType] = {
        fieldType,
        lastStateRef: {
          contents: undefined
        }
      };
    }
    expect(Group.computeGroupReadiness(entries)).toBe(false);
    for (const entry of Object.values(entries.contents)) entry.lastStateRef.contents = {
      fieldStatus: {
        complete: true
      }
    };
    entries.contents.name = {
      fieldType: "cardholderName",
      lastStateRef: {
        contents: undefined
      }
    };
    expect(Group.computeGroupReadiness(entries)).toBe(true);
    entries.contents.cardCvc.lastStateRef.contents = {
      fieldStatus: {
        complete: false
      }
    };
    expect(Group.computeGroupReadiness(entries)).toBe(false);
  });
});
