import React from "react";
import { createRoot } from "react-dom/client";
import { createStore, Provider, type PrimitiveAtom } from "jotai";
import { Form } from "react-final-form";
import GPay from "../../src/Payments/GPay.bs.js";
import * as Atoms from "../../src/Utilities/JotaiAtoms.bs.js";
import * as CommonHooks from "../../src/Hooks/CommonHooks.bs.js";
import * as Elements from "../../src/hyper-loader/Elements.bs.js";
import * as WebLoggerAdapter from "../../src/Logger/core/WebLoggerAdapter.bs.js";
import * as PaymentHelpers from "../../src/Utilities/PaymentHelpers.bs.js";
import * as LoggerConfig from "../../shared-code/sdk-utils/logging/LoggerConfig.bs.js";
import * as LoggerQueue from "../../shared-code/sdk-utils/logging/LoggerQueue.bs.js";
import clientList from "../recordings/base/client-list.json";

interface EventListenerLog {
  componentType: string;
  eventListeners: string[];
}

interface PaymentContextOptions {
  callbackRegistered?: boolean;
  clientSecret: string;
  publishableKey: string;
  returnUrl: string;
}

export interface PaymentHookOptions extends PaymentContextOptions {
  hook: "intent" | "sync" | "complete" | "handler";
  paymentType: "Card" | "Gpay" | "Applepay" | "Paypal" | "Samsungpay";
  isOneClickWallet?: boolean;
}

interface GooglePayOptions extends PaymentContextOptions {
  button: boolean;
}

interface GooglePayButtonOptions {
  onClick: () => void;
}

type SdkKeys = Omit<typeof CommonHooks.defaultkeys, "clientSecret"> & {
  clientSecret?: string;
};
type PaymentMethodsState =
  | "Loading"
  | {
      TAG: "Loaded";
      _0: (typeof clientList)["routes"][number]["body"];
    };
const keysAtom = Atoms.keys as PrimitiveAtom<SdkKeys>;
const paymentMethodsAtom =
  Atoms.paymentMethodList as PrimitiveAtom<PaymentMethodsState>;
const flushedListenerRows: { event_name: string; value: string }[] = [];

WebLoggerAdapter.configure();
LoggerConfig.configure(true, "");
LoggerQueue.configure((payload: string) => {
  flushedListenerRows.push(...JSON.parse(payload));
  return true;
});

declare global {
  interface Window {
    google: {
      payments: {
        api: {
          PaymentsClient: new () => {
            createButton(options: GooglePayButtonOptions): HTMLButtonElement;
          };
        };
      };
    };
  }
}

export function makeElements() {
  const ownedFrames: HTMLIFrameElement[] = [];
  const registerFrame = (iframe: HTMLIFrameElement | null) => {
    if (iframe) ownedFrames.push(iframe);
  };
  const isTrustedMessage = (event: MessageEvent) =>
    ownedFrames.some(
      (iframe) =>
        iframe.isConnected &&
        event.source === iframe.contentWindow &&
        event.origin === new URL(iframe.src).origin,
    );
  const elements = Elements.make(
    {},
    registerFrame,
    "test-session",
    "pk_snd_test",
    undefined,
    "",
    { shouldUseTopRedirection: false, shouldRemoveBeforeUnloadEvents: false },
    true,
    undefined,
    { contents: false },
    { contents: "pay_test_secret_test" },
    { contents: "" },
    { contents: Promise.resolve({}) },
    { contents: Promise.resolve({}) },
    { contents: Promise.resolve({}) },
    () => Promise.resolve({}),
    () => {},
    isTrustedMessage,
    isTrustedMessage,
    registerFrame,
  );
  return { elements };
}

export function listenerLogs(): EventListenerLog[] {
  return [
    ...flushedListenerRows,
    ...LoggerQueue.rows.map(
      ({ row }: { row: { event_name: string; value: string } }) => row,
    ),
  ]
    .filter(
      (row: { event_name: string }) =>
        row.event_name === "state.payment_element_event_listeners",
    )
    .map((row: { value: string }) => {
      const { component_type, event_listeners } = JSON.parse(row.value).details;
      return { componentType: component_type, eventListeners: event_listeners };
    });
}

export function notifyMounted(id: string): void {
  notifyElementMessage(id, { iframeMounted: true });
}

export function notifyElementMessage(
  id: string,
  data: Record<string, unknown>,
): void {
  const iframe = document.querySelector<HTMLIFrameElement>(
    `#orca-payment-element-iframeRef-${id}`,
  );
  if (!iframe) throw new Error(`Missing mounted iframe: ${id}`);
  window.dispatchEvent(
    new MessageEvent("message", {
      data,
      source: iframe.contentWindow,
      origin: new URL(iframe.src).origin,
    }),
  );
}

function paymentStore({
  callbackRegistered = true,
  clientSecret,
  publishableKey,
  returnUrl,
}: PaymentContextOptions) {
  const store = createStore();
  store.set(Atoms.isCompleteCallbackUsed, callbackRegistered);
  store.set(keysAtom, {
    ...CommonHooks.defaultkeys,
    clientSecret,
    publishableKey,
    iframeId: "test-payment",
    parentURL: window.location.origin,
  });
  store.set(paymentMethodsAtom, {
    TAG: "Loaded",
    _0: clientList.routes[0].body,
  });
  const options = store.get(Atoms.optionAtom);
  store.set(Atoms.optionAtom, {
    ...options,
    wallets: { ...options.wallets, walletReturnUrl: returnUrl },
  });
  return store;
}

export function mountPaymentHook(
  options: PaymentHookOptions,
): Promise<() => void> {
  const {
    hook,
    paymentType,
    isOneClickWallet,
    clientSecret,
    publishableKey,
    returnUrl,
  } = options;
  const store = paymentStore(options);
  const confirmParam = {
    publishableKey,
    return_url: returnUrl,
    redirect: "if_required",
  };
  return new Promise<() => void>((resolve, reject) => {
    function PaymentHook() {
      const intent = PaymentHelpers.usePaymentIntent(
        isOneClickWallet,
        paymentType,
      );
      const sync = PaymentHelpers.usePaymentSync(isOneClickWallet, paymentType);
      const complete = PaymentHelpers.useCompleteAuthorize(
        isOneClickWallet,
        paymentType,
      );
      const handler =
        PaymentHelpers.useCompleteAuthorizeHandler(isOneClickWallet);
      React.useEffect(() => {
        resolve(() => {
          if (hook === "intent") intent(false, [], confirmParam);
          else if (hook === "sync") sync(false, confirmParam);
          else if (hook === "complete") complete(false, [], confirmParam);
          else
            handler(
              clientSecret,
              [],
              confirmParam,
              "test-payment",
              false,
              paymentType,
              true,
            );
        });
      }, []);
      return null;
    }
    createRoot(document.getElementById("root")!, {
      onUncaughtError: reject,
    }).render(
      React.createElement(
        Provider,
        { store },
        React.createElement(PaymentHook),
      ),
    );
  });
}

export function mountGooglePay(options: GooglePayOptions): Promise<void> {
  const store = paymentStore(options);
  window.google = {
    payments: {
      api: {
        PaymentsClient: class {
          createButton({ onClick }: GooglePayButtonOptions) {
            const button = document.createElement("button");
            button.textContent = "Google Pay";
            button.onclick = onClick;
            return button;
          }
        },
      },
    },
  };
  return new Promise<void>((resolve, reject) => {
    function WalletHost() {
      React.useEffect(() => resolve(), []);
      return React.createElement(Form, {
        onSubmit: () => {},
        render: () =>
          React.createElement(GPay, {
            sessionObj: undefined,
            thirdPartySessionObj: undefined,
            walletOptions: options.button ? ["google_pay"] : [],
          }),
      });
    }
    createRoot(document.getElementById("root")!, {
      onUncaughtError: reject,
    }).render(
      React.createElement(Provider, { store }, React.createElement(WalletHost)),
    );
  });
}
