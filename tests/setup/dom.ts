import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createRoot } from "react-dom/client";
import { beforeEach, vi } from "vitest";
import { registerTestCleanup, rejectUnexpectedRequest } from "./sdk-config";

// React and user-event install event infrastructure once per document. Establish
// it before tracking fixture listeners, so cleanup keeps later roots functional.
createRoot(document.createElement("div")).unmount();
userEvent.setup();

type Listener = [EventTarget["removeEventListener"], string, EventListenerOrEventListenerObject | null, boolean | AddEventListenerOptions | undefined];
const listeners: Listener[] = [];
const eventTargets = [window, document].map((target) => ({
  target,
  add: target.addEventListener.bind(target),
  remove: target.removeEventListener.bind(target),
}));
const initialHead = document.head.innerHTML;

function installBrowserGuards() {
  vi.spyOn(XMLHttpRequest.prototype, "send").mockImplementation(function () {
    return rejectUnexpectedRequest("XMLHttpRequest", "send");
  });
  // jsdom does not provide sendBeacon; make expected calls mockable per test.
  Object.defineProperty(navigator, "sendBeacon", {
    configurable: true,
    writable: true,
    value: vi.fn((url) => rejectUnexpectedRequest("sendBeacon", url)),
  });
  for (const { target, add, remove } of eventTargets) {
    vi.spyOn(target, "addEventListener").mockImplementation((type, listener, options) => {
      listeners.push([remove, type, listener, options]);
      return add(type, listener, options);
    });
  }
}

installBrowserGuards();
beforeEach(installBrowserGuards);

registerTestCleanup(() => {
  cleanup();
  for (const [remove, type, listener, options] of listeners.splice(0)) {
    remove(type, listener, options);
  }
  localStorage.clear();
  sessionStorage.clear();
  window.history.replaceState(null, "", "/checkout");
  document.body.replaceChildren();
  document.head.innerHTML = initialHead;
  for (const cookie of document.cookie.split(";")) {
    document.cookie = `${cookie.split("=")[0].trim()}=; Max-Age=0; path=/`;
  }
});
