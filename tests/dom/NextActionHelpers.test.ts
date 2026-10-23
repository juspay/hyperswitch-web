import { describe, expect, it, vi } from "vitest";
import { handleDDC } from "../../src/Utilities/NextActionHelpers.bs.js";
import { executionLogger } from "../helpers/execution-fixtures";
function executionDdc({
  data = {
    status: "requires_customer_action"
  },
  ddc = {
    iframeUrl: "https://ddc.test/execution",
    timeoutMs: 500
  },
  session = true
} = {}) {
  const resolve = vi.fn();
  const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
  const remove = vi.spyOn(window, "removeEventListener");
  handleDDC(ddc, "frame_execution", session, resolve, data, executionLogger(), "CARD");
  return {
    resolve,
    post,
    remove,
    data
  };
}
const complete = {
  next_action: {
    type: "redirect_to_url",
    url: "https://merchant.test/complete",
    redirect_mode: "if_required"
  }
};
describe("DDC next action lifecycle", () => {
  it("settles session completion and removes iframe, listener and timeout", () => {
    vi.useFakeTimers();
    const fixture = executionDdc();
    expect(document.querySelector("#ddc-iframe")).toHaveAttribute("src", "https://ddc.test/execution");
    window.dispatchEvent(new MessageEvent("message", {
      data: {
        unrelated: true
      }
    }));
    expect(fixture.resolve).not.toHaveBeenCalled();
    window.dispatchEvent(new MessageEvent("message", {
      data: complete
    }));
    expect(fixture.resolve).toHaveBeenCalledExactlyOnceWith(fixture.data);
    expect(document.querySelector("#ddc-iframe")).toBeNull();
    expect(fixture.remove).toHaveBeenCalledWith("message", expect.any(Function));
    expect(vi.getTimerCount()).toBe(0);
    window.dispatchEvent(new MessageEvent("message", {
      data: complete
    }));
    expect(fixture.resolve).toHaveBeenCalledOnce();
  });
  it("posts if-required completion to merchant host", () => {
    vi.useFakeTimers();
    const fixture = executionDdc({
      session: false
    });
    window.dispatchEvent(new MessageEvent("message", {
      data: complete
    }));
    expect(fixture.post).toHaveBeenCalledWith({
      openurl_if_required: "https://merchant.test/complete"
    }, "*");
    expect(document.querySelector("#ddc-iframe")).toBeNull();
    expect(vi.getTimerCount()).toBe(0);
  });
  it("posts required redirect after cleanup", () => {
    vi.useFakeTimers();
    const fixture = executionDdc();
    window.dispatchEvent(new MessageEvent("message", {
      data: {
        next_action: {
          ...complete.next_action,
          redirect_mode: "required"
        }
      }
    }));
    expect(fixture.post).toHaveBeenCalledWith({
      openurl: "https://merchant.test/complete"
    }, "*");
    expect(document.querySelector("#ddc-iframe")).toBeNull();
    expect(vi.getTimerCount()).toBe(0);
  });
  it.each([{
    type: "unsupported"
  }, {
    type: "redirect_to_url",
    url: ""
  }])("fails malformed next action and clears resources: %j", next_action => {
    vi.useFakeTimers();
    const fixture = executionDdc({
      session: false
    });
    window.dispatchEvent(new MessageEvent("message", {
      data: {
        next_action
      }
    }));
    expect(fixture.resolve).toHaveBeenCalledExactlyOnceWith({
      error: {
        type: "error",
        message: "Something went wrong"
      }
    });
    expect(fixture.post.mock.calls.map(([data]) => data)).toContainEqual(expect.objectContaining({
      submitSuccessful: false
    }));
    expect(document.querySelector("#ddc-iframe")).toBeNull();
    expect(vi.getTimerCount()).toBe(0);
  });
  it("handles message parse exceptions and cleans up", () => {
    vi.useFakeTimers();
    const fixture = executionDdc();
    const malformed = Object.defineProperty({}, "next_action", {
      get() {
        throw new Error("execution malformed");
      }
    });
    window.dispatchEvent(new MessageEvent("message", {
      data: malformed
    }));
    expect(fixture.resolve).toHaveBeenCalledExactlyOnceWith({
      error: {
        type: "error",
        message: "Something went wrong"
      }
    });
    expect(document.querySelector("#ddc-iframe")).toBeNull();
    expect(vi.getTimerCount()).toBe(0);
  });
  it("times out once and ignores later completion", async () => {
    vi.useFakeTimers();
    const fixture = executionDdc();
    await vi.advanceTimersByTimeAsync(499);
    expect(fixture.resolve).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(fixture.resolve).toHaveBeenCalledExactlyOnceWith({
      error: {
        type: "error",
        message: "Something went wrong"
      }
    });
    window.dispatchEvent(new MessageEvent("message", {
      data: complete
    }));
    expect(fixture.resolve).toHaveBeenCalledOnce();
    expect(document.querySelector("#ddc-iframe")).toBeNull();
    expect(vi.getTimerCount()).toBe(0);
  });
  it.each([undefined, {
    iframeUrl: "",
    timeoutMs: 1
  }])("fails empty iframe config without adding resources: %j", ddc => {
    vi.useFakeTimers();
    const resolve = vi.fn();
    vi.spyOn(window, "postMessage").mockImplementation(() => {});
    handleDDC(ddc, "execution-frame", true, resolve, {}, undefined, "CARD");
    expect(resolve).toHaveBeenCalledExactlyOnceWith({
      error: {
        type: "error",
        message: "Something went wrong"
      }
    });
    expect(document.querySelector("iframe")).toBeNull();
    expect(vi.getTimerCount()).toBe(0);
  });
});
