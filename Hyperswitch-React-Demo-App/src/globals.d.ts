// Webpack DefinePlugin globals (from webpack.common.js)
declare const ENDPOINT: string;
declare const SCRIPT_SRC: string;
declare const SELF_SERVER_URL: string;
declare const SDK_VERSION: string;

// Window augmentation for dynamically loaded Hyper SDK
interface Window {
  Hyper: (
    options: { publishableKey: string; profileId?: string },
    config?: { customBackendUrl?: string }
  ) => HyperInstance;
}

// Forward-declare HyperInstance at global scope so Window.Hyper can reference it.
// The full definition lives in the @juspay-tech/hyper-js ambient module below.
type HyperInstance = import("@juspay-tech/hyper-js").HyperInstance;

// Asset modules
declare module "*.svg" {
  const content: string;
  export default content;
}
declare module "*.png" {
  const content: string;
  export default content;
}
declare module "*.css" {}

// ---------------------------------------------------------------------------
// @juspay-tech/hyper-js — subset used by the demo app
//
// TODO: These ambient module declarations are TEMPORARY. They exist because the
// published npm packages (@juspay-tech/hyper-js, @juspay-tech/react-hyper-js)
// do not yet ship .d.ts files. Once PRs juspay/hyper-js#18 and
// juspay/react-hyper-js#11 are merged and released, DELETE these declare module
// blocks — the real .d.ts files from node_modules will take over automatically.
// ---------------------------------------------------------------------------
declare module "@juspay-tech/hyper-js" {
  export interface HyperInstance {
    confirmPayment(params: any): Promise<any>;
    elements(options: any): Element;
    confirmCardPayment(
      clientSecret: string,
      data?: object,
      options?: object
    ): Promise<object>;
    retrievePaymentIntent(paymentIntentId: string): Promise<any>;
    widgets(options: any): Element;
    paymentRequest(options: object): object;
  }

  export interface Element {
    getElement(componentName: string): any;
    update(options: any): void;
    fetchUpdates(): Promise<object>;
    create(componentType: string, options?: object): any;
  }
}

// ---------------------------------------------------------------------------
// @juspay-tech/react-hyper-js — subset used by the demo app
//
// TODO: Same as above — delete this block once juspay/react-hyper-js#11 ships.
// ---------------------------------------------------------------------------
declare module "@juspay-tech/react-hyper-js" {
  import type { ReactNode } from "react";
  import type { HyperInstance } from "@juspay-tech/hyper-js";

  export interface UseHyperReturn {
    clientSecret: string;
    confirmPayment(params: any): Promise<any>;
    confirmCardPayment(
      clientSecret: string,
      data?: any,
      options?: any
    ): Promise<any>;
    retrievePaymentIntent(paymentIntentId: string): Promise<any>;
    paymentRequest(options: any): any;
  }

  export interface UseWidgetsReturn {
    options: Record<string, any>;
    update(options: any): void;
    getElement(componentName: string): any | null;
    fetchUpdates(): Promise<any>;
    create(componentType: string, options: any): any;
  }

  export function useHyper(): UseHyperReturn;
  export function useWidgets(): UseWidgetsReturn;

  export function HyperElements(props: {
    hyper: Promise<HyperInstance>;
    options: Record<string, any>;
    children: ReactNode;
  }): JSX.Element | null;

  export function PaymentElement(props: {
    id?: string;
    options?: Record<string, any>;
    onChange?: (data?: any) => void;
    onReady?: (data?: any) => void;
    onFocus?: (data?: any) => void;
    onBlur?: (data?: any) => void;
    onClick?: (data?: any) => void;
  }): JSX.Element | null;
}
