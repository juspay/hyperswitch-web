import { afterEach, describe, expect, it, vi } from "vitest";
import * as Manager from "../../src/Utilities/EventListenerManager.bs.js";

const activity = "unit-test-message";
afterEach(() => Manager.removeSmartEventListener("message", activity));

describe("EventListenerManager", () => {
  it("replaces an activity listener so only the latest handler receives events", () => {
    const oldHandler = vi.fn();
    const newHandler = vi.fn();
    Manager.addSmartEventListener("message", oldHandler, activity);
    window.dispatchEvent(new MessageEvent("message", { data: "first" }));
    expect(oldHandler).toHaveBeenCalledOnce();
    Manager.addSmartEventListener("message", newHandler, activity);
    window.dispatchEvent(new MessageEvent("message", { data: "second" }));
    expect(oldHandler).toHaveBeenCalledOnce();
    expect(newHandler).toHaveBeenCalledOnce();
    expect(newHandler.mock.calls[0][0].data).toBe("second");
  });

  it("removes the actual listener and tolerates repeated cleanup", () => {
    const handler = vi.fn();
    Manager.addSmartEventListener("message", handler, activity);
    Manager.removeSmartEventListener("message", activity);
    Manager.removeSmartEventListener("message", activity);
    window.dispatchEvent(new MessageEvent("message"));
    expect(handler).not.toHaveBeenCalled();
    expect(Manager.eventListenerMap).not.toHaveProperty(activity);
  });
});
