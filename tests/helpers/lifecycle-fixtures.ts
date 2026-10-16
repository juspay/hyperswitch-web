import { parseJson } from "./json";
import { vi } from "vitest";
import { defaultLoggerConfig } from "../../src/Utilities/LoggerUtils.bs.js";
export const card = Object.freeze({
  rawCardNumber: "4111111111111111",
  rawCardExpiry: "10/29",
  rawCvc: "123",
  rawCardholderName: "Synthetic Cardholder",
  cardBrand: "Visa"
});
export function logger() {
  return {
    ...defaultLoggerConfig,
    setLogInfo: vi.fn(),
    setLogApi: vi.fn(),
    setLogError: vi.fn()
  };
}

// Boundary double only: it records ownership and sends; it does not simulate
// browser transfer, structured cloning, or the security properties of a port.
export function port() {
  return {
    close: vi.fn<() => void>(),
    postMessage: vi.fn<(message: unknown) => void>(),
    onmessage: null as ((event: Pick<MessageEvent<unknown>, "data">) => void) | null
  };
}
export function installChannels() {
  const channels: { port1: ReturnType<typeof port>; port2: ReturnType<typeof port> }[] = [];
  vi.stubGlobal("MessageChannel", class {
    port1: ReturnType<typeof port>;
    port2: ReturnType<typeof port>;
    constructor() {
      this.port1 = port();
      this.port2 = port();
      channels.push(this);
    }
  });
  return channels;
}
export function message(iframe: HTMLIFrameElement, data: unknown, {
  origin = new URL(iframe.src).origin,
  source = iframe.contentWindow
}: { origin?: string; source?: MessageEventSource | null } = {}) {
  window.dispatchEvent(new MessageEvent("message", {
    data,
    origin,
    source
  }));
}
export function posted(spy: { mock: { calls: readonly (readonly unknown[])[] } }): unknown[] {
  return spy.mock.calls.map(([value]) => typeof value === "string" ? parseJson(value) : value);
}
export function authorization() {
  return btoa("publishable_key=pk_test_unit,payment_method_session_id=pms_unit,customer_id=cus_unit");
}
export function response<T>(body: T, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers(),
    json: async () => body
  };
}
export function mountField(handle: { mount(selector: string): unknown }, name: string) {
  const container = document.createElement("div");
  container.id = `lifecycle-${name}`;
  document.body.appendChild(container);
  handle.mount(`#${container.id}`);
  const iframe = container.querySelector("iframe")!;
  return {
    container,
    iframe,
    post: vi.spyOn(iframe.contentWindow!, "postMessage")
  };
}

// Vendor boundary fixture. The real broker still loads/creates the form,
// validates state, wires callbacks, submits, and tears down field handles.
export function installVgsCollect() {
  const script = document.createElement("script");
  script.setAttribute("data-vgs-script-loaded", "loaded");
  document.head.appendChild(script);
  type Field = { handle: ReturnType<typeof makeField>; events: Map<string, (event: unknown) => void>; container: Element };
  const fields = new Map<string, Field>();
  let onFormState!: (value: unknown) => void;
  function makeField(selector: string, options: { name: string }) {
    const container = document.querySelector(selector)!;
    const iframe = document.createElement("iframe");
    container.appendChild(iframe);
    const events = new Map<string, (event: unknown) => void>();
    const handle = {
      on: vi.fn((event: string, callback: (event: unknown) => void) => events.set(event, callback)),
      focus: vi.fn(),
      blur: vi.fn(),
      clear: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(() => iframe.remove())
    };
    fields.set(options.name, {
      handle,
      events,
      container
    });
    return handle;
  }
  // Only the vendor callback surface exercised by the broker is modeled.
  type Submit = (path: string, payload: unknown, success: (status: number | string | null, data: unknown) => void, failure: (errors: unknown) => void) => unknown;
  const form = { field: vi.fn(makeField), submit: vi.fn<Submit>() };
  const create = vi.fn((_vaultId: string, _environment: string, onChange: (value: unknown) => void) => {
    onFormState = onChange;
    return form;
  });
  vi.stubGlobal("VGSCollect", {
    create
  });
  return {
    create,
    form,
    fields,
    script,
    state: (value: unknown) => onFormState(value)
  };
}
