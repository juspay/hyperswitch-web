import React from "react";
import { createRoot } from "react-dom/client";
import { createStore, Provider, type PrimitiveAtom } from "jotai";
import { Form } from "react-final-form";
import GPay from "../../src/Payments/GPay.bs.js";
import * as Atoms from "../../src/Utilities/JotaiAtoms.bs.js";
import * as CommonHooks from "../../src/Hooks/CommonHooks.bs.js";
import * as Elements from "../../src/hyper-loader/Elements.bs.js";
import * as LoggerUtils from "../../src/Utilities/LoggerUtils.bs.js";
import * as PaymentHelpers from "../../src/Utilities/PaymentHelpers.bs.js";
import clientList from "../recordings/base/client-list.json";

export { makeOneClickHandlerPromise as requestOneClickDecision } from "../../src/Utilities/Utils.bs.js";
export { handleApplePayBraintreePaymentSession as startBraintreeApplePay } from "../../src/Utilities/ApplePayHelpers.bs.js";

export interface EventListenerLog {
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
  const logs: EventListenerLog[] = [];
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
  const logger = {
    ...LoggerUtils.defaultLoggerConfig,
    setLogInfo(value: string, eventName: string) {
      if (eventName === "PAYMENT_ELEMENT_EVENT_LISTENERS") {
        logs.push(JSON.parse(value));
      }
    },
  };
  const elements = Elements.make(
    {},
    registerFrame,
    "test-session",
    "pk_snd_test",
    logger,
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
    () => ({
      isCurrent: () => true,
      onSubmitResponse: () => {},
      hasConfirmation: false,
    }),
    isTrustedMessage,
    isTrustedMessage,
    registerFrame,
  );
  return { elements, logs };
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
        undefined,
        paymentType,
      );
      const sync = PaymentHelpers.usePaymentSync(
        isOneClickWallet,
        undefined,
        paymentType,
      );
      const complete = PaymentHelpers.useCompleteAuthorize(
        isOneClickWallet,
        undefined,
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
              undefined,
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
