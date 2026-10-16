import { afterEach, describe, expect, it, vi } from "vitest";
import * as Shared from "../../src/hyper-loader/CardFormGroupShared.bs.js";
import * as Mount from "../../src/hyper-loader/CoordinatorMount.bs.js";
import * as Registry from "../../src/Payments/SadPortRegistry.bs.js";
import { installChannels, port, posted } from "../helpers/lifecycle-fixtures";
// Generated channel defaults omit the mount record assigned by the broker.
const makeChannel = (...args: Parameters<typeof Shared.makeCoordinatorChannel>) =>
  Shared.makeCoordinatorChannel(...args) as Omit<ReturnType<typeof Shared.makeCoordinatorChannel>, "mountRef"> & { mountRef: { contents: { iframe: HTMLIFrameElement } | undefined } };
const iframe = () => document.body.appendChild(document.createElement("iframe"));
afterEach(() => Object.keys(Registry.registry).forEach(Registry.closePort));
describe("CardFormGroupShared channel lifecycle", () => {
  it("requires the exact source window and origin and tolerates absent frames", () => {
    const frame = iframe();
    const source = frame.contentWindow;
    expect(Shared.isFromIframe({
      source,
      origin: "https://sdk.test"
    }, frame, "https://sdk.test")).toBe(true);
    expect(Shared.isFromIframe({
      source: window,
      origin: "https://sdk.test"
    }, frame, "https://sdk.test")).toBe(false);
    expect(Shared.isFromIframe({
      source,
      origin: "https://attacker.test"
    }, frame, "https://sdk.test")).toBe(false);
    expect(Shared.isFromIframe({
      source,
      origin: "https://sdk.test"
    }, undefined, "https://sdk.test")).toBe(false);
    expect(Shared.eventDataJson({
      data: {
        harmless: true
      }
    })).toEqual({
      harmless: true
    });
    expect(Shared.eventDataJson({
      get data() {
        throw new Error("unreadable");
      }
    })).toBeNull();
  });
  it("queues commands until mount and readiness, then flushes in order exactly once", () => {
    const channel = makeChannel("group");
    Shared.postCoordinatorCommand(channel, [["command", "first"]]);
    Shared.flushPendingCoordinatorCommands(channel);
    channel.mountRef.contents = {
      iframe: iframe()
    };
    const spy = vi.spyOn(channel.mountRef.contents!.iframe.contentWindow!, "postMessage");
    Shared.postCoordinatorCommand(channel, [["command", "second"]]);
    Shared.flushPendingCoordinatorCommands(channel);
    expect(spy).not.toHaveBeenCalled();
    channel.readyRef.contents = true;
    Shared.flushPendingCoordinatorCommands(channel);
    Shared.flushPendingCoordinatorCommands(channel);
    Shared.postCoordinatorCommand(channel, [["command", "third"]]);
    expect(posted(spy)).toEqual([{
      command: "first"
    }, {
      command: "second"
    }, {
      command: "third"
    }]);
    expect(channel.pendingCommandsRef.contents).toEqual([]);
    spy.mockImplementation(() => {
      throw new Error("closed frame");
    });
    expect(() => Shared.postCoordinatorCommand(channel, [["command", "fails"]])).not.toThrow();
    expect(() => Shared.postToCoordinator({
      get iframe() {
        throw new Error("removed");
      }
    }, [])).not.toThrow();
  });
  it("forwards pending ports with monotonically increasing epochs when the coordinator becomes ready", () => {
    const channels = installChannels();
    const channel = makeChannel("group");
    const field = iframe();
    const fieldPost = vi.spyOn(field.contentWindow!, "postMessage");
    Shared.openFieldPort(channel, field, {
      field: "cardNumber"
    }, "cardNumber");
    Shared.openFieldPort(channel, field, {
      field: "cardNumber"
    }, "cardNumber");
    expect(channel.portEpochCounterRef.contents).toBe(2);
    expect(channel.pendingPortsRef.contents.map(({
      epoch
    }) => epoch)).toEqual([1, 2]);
    expect(posted(fieldPost)).toEqual([{
      field: "cardNumber",
      portKey: "group:cardNumber",
      portEpoch: 1
    }, {
      field: "cardNumber",
      portKey: "group:cardNumber",
      portEpoch: 2
    }]);
    // DOM overload inference selects the options form; the SDK uses the transfer-list overload.
    expect((fieldPost.mock.calls[0] as unknown as [unknown, unknown, unknown])[2]).toEqual([channels[0].port2]);
    channel.mountRef.contents = {
      iframe: iframe()
    };
    const post = vi.spyOn(channel.mountRef.contents!.iframe.contentWindow!, "postMessage");
    Shared.flushPendingPorts(channel);
    expect(post).not.toHaveBeenCalled();
    channel.readyRef.contents = true;
    Shared.flushPendingPorts(channel);
    Shared.flushPendingPorts(channel);
    expect(posted(post)).toEqual([{
      cardFieldPort: true,
      portKey: "group:cardNumber",
      portEpoch: 1
    }, {
      cardFieldPort: true,
      portKey: "group:cardNumber",
      portEpoch: 2
    }]);
    // The third argument is the transferred port list in this SDK call.
    expect((post.mock.calls[0] as unknown as [unknown, unknown, unknown])[2]).toEqual([channels[0].port1]);
    expect(channel.pendingPortsRef.contents).toEqual([]);
    const installed = port();
    Registry.installPort("group:cardNumber", 2, installed);
    Shared.closeInstalledPorts(channel);
    Shared.closeInstalledPorts(channel);
    expect(installed.close).toHaveBeenCalledOnce();
    expect(channel.installedPortKeysRef.contents).toEqual([]);
  });
  it("tears down pending ports even if one close throws, and removes the mount", () => {
    const mount = Mount.create(document.body, "lifecycle", "cardFormCoordinator", "vault", "group", "https://sdk.test");
    const broken = port();
    broken.close.mockImplementation(() => {
      throw new Error("already closed");
    });
    const pending = port();
    Mount.teardown(mount, [{
      port: broken
    }, {
      port: pending
    }]);
    Mount.teardown(mount, []);
    expect(broken.close).toHaveBeenCalledOnce();
    expect(pending.close).toHaveBeenCalledOnce();
    expect(mount.container.isConnected).toBe(false);
  });
  it("merges valid subscriptions once and chooses nonempty field appearance", () => {
    const subscriptions = {
      contents: ["ready"]
    };
    expect(Shared.mergeSubscriptionEvents(subscriptions, {
      subscriptionEvents: ["change", false, "ready", "change"]
    })).toBe(true);
    expect(subscriptions.contents).toEqual(["ready", "change"]);
    for (const value of [{}, {
      subscriptionEvents: [false, "ready"]
    }, {
      subscriptionEvents: "change"
    }]) {
      expect(Shared.mergeSubscriptionEvents(subscriptions, value)).toBe(false);
    }
    const group = {
      theme: "night"
    };
    for (const appearance of [undefined, null, {}, false, []]) {
      expect(Shared.resolveFieldAppearance({
        appearance
      }, group)).toBe(group);
    }
    expect(Shared.resolveFieldAppearance({
      appearance: {
        theme: "stripe"
      }
    }, group)).toEqual({
      theme: "stripe"
    });
    const options = {
      placeholder: "Synthetic"
    };
    expect(Shared.optionsWithAppearance(options, group)).toEqual({
      ...options,
      appearance: group
    });
    expect(options).not.toHaveProperty("appearance");
  });
  it("builds the field mount envelope and forwards only documented updates", () => {
    const appearance = {
      theme: "night"
    };
    const paymentOptions = Shared.buildPaymentOptions(appearance, "en", [["clientSecret", "pi_unit_secret_test"]]);
    expect(paymentOptions).toEqual({
      appearance,
      locale: "en",
      fonts: [],
      clientSecret: "pi_unit_secret_test"
    });
    const config = Shared.buildFieldMountConfig(paymentOptions, {}, "field", "pk_test_unit", [["endpoint", "https://api.sdk.test"]], "sdk_unit", "unit", "Visa", undefined);
    expect(config).toMatchObject({
      iframeId: "field",
      endpoint: "https://api.sdk.test",
      paymentOptions,
      sdkSessionId: "sdk_unit",
      savedCardBrand: "Visa",
      cardCollectionMode: "tokenise",
      blockConfirm: false,
      redirectionFlags: {
        shouldUseTopRedirection: false,
        shouldRemoveBeforeUnloadEvents: false
      }
    });
    const frame = iframe();
    const post = vi.spyOn(frame.contentWindow!, "postMessage");
    const options = {
      savedCard: {
        paymentToken: "tok_test",
        paymentMethodData: {
          card: {
            cardNetwork: "Visa"
          }
        }
      }
    };
    expect(Shared.postFieldUpdate({
      contents: frame
    }, options)).toEqual(options.savedCard);
    expect(posted(post)).toEqual([{
      paymentElementsUpdate: true,
      options
    }, {
      savedCardBrand: "Visa"
    }]);
    Shared.postFieldUpdate({
      contents: frame
    }, {});
    expect(posted(post).at(-1)).toEqual({
      paymentElementsUpdate: true,
      options: {}
    });
    const fields = {
      contents: {}
    };
    Shared.registerField(fields, "field", "cardCvc", [["test", true]]);
    expect(fields.contents).toEqual({
      field: {
        id: "field",
        type: "cardCvc",
        test: true
      }
    });
    expect(Shared.uniqueId("unit")).toMatch(/^unit-\d+-\d+/);
  });
});
