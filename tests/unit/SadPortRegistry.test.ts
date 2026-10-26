import { afterEach, describe, expect, it, vi } from "vitest";
import * as Registry from "../../src/Payments/SadPortRegistry.bs.js";

const port = () => ({ close: vi.fn(), postMessage: vi.fn() });
const listeners: ReturnType<typeof vi.fn>[] = [];
afterEach(() => {
  listeners.splice(0).forEach(Registry.removeChangeListener);
  Object.keys(Registry.registry).forEach(Registry.closePort);
});

describe("SadPortRegistry", () => {
  it("retains the same epoch and closes the previous port on epoch replacement", () => {
    const original = port();
    const ignored = port();
    const replacement = port();
    Registry.installPort("card", 1, original);
    Registry.installPort("card", 1, ignored);
    expect(Registry.getPort("card")).toBe(original);
    expect(original.close).not.toHaveBeenCalled();
    Registry.installPort("card", 2, replacement);
    expect(original.close).toHaveBeenCalledOnce();
    expect(Registry.getPort("card")).toBe(replacement);
    expect(ignored.close).not.toHaveBeenCalled();
  });

  it("notifies active listeners only for changes and supports repeated removal", () => {
    const listener = vi.fn();
    listeners.push(listener);
    Registry.addChangeListener(listener);
    const current = port();
    Registry.installPort("card", 1, current);
    Registry.installPort("card", 1, port());
    expect(listener).toHaveBeenCalledTimes(1);
    Registry.closePort("card");
    Registry.closePort("card");
    expect(current.close).toHaveBeenCalledOnce();
    expect(listener).toHaveBeenCalledTimes(2);
    Registry.removeChangeListener(listener);
    Registry.removeChangeListener(listener);
    Registry.installPort("card", 2, port());
    expect(listener).toHaveBeenCalledTimes(2);
  });

  it("reports absent or failing sends without losing the registered port", () => {
    const current = port();
    const frame = { kind: "doFocus", payload: {} };
    expect(Registry.postFrame("missing", frame)).toBe(false);
    Registry.installPort("card", 1, current);
    expect(Registry.postFrame("card", frame)).toBe(true);
    expect(current.postMessage).toHaveBeenCalledWith(frame);
    current.postMessage.mockImplementation(() => { throw new Error("closed"); });
    expect(Registry.postFrame("card", frame)).toBe(false);
    expect(Registry.getPort("card")).toBe(current);
  });

  it("still replaces and removes ports whose close operation throws", () => {
    const broken = port();
    broken.close.mockImplementation(() => { throw new Error("closed"); });
    Registry.installPort("card", 1, broken);
    const replacement = port();
    Registry.installPort("card", 2, replacement);
    expect(Registry.getPort("card")).toBe(replacement);
    replacement.close.mockImplementation(() => { throw new Error("closed"); });
    expect(() => Registry.closePort("card")).not.toThrow();
    expect(Registry.getPort("card")).toBeUndefined();
  });
});
