// ---------------------------------------------------------------------------
// Immutable payment-body builders.
//
// Files (and, in the hermetic tier, tests) run in parallel workers, so every
// test builds its own body instead of mutating a shared one:
//
//   paymentBody()                                        // DEFAULT_PAYMENT_BODY
//   paymentBody({ customer_id: "card_validation_test_user" })
//   paymentBody({ amount: 0, setup_future_usage: "off_session" })
//   paymentBody({ billing: undefined, email: undefined }) // undefined REMOVES the key
//   withoutKeys(paymentBody(), "billing")                 // same, explicit
//
// profile_id is left empty on purpose: checkout.createPaymentIntent() fills in
// the Stripe profile unless the test sets one, e.g.
// paymentBody({ profile_id: credentials.profileId(connectorEnum.TRUSTPAY) }).
// ---------------------------------------------------------------------------
import { CLIENT_BASE_URL } from "./env";

export interface Address {
  line1?: string;
  line2?: string;
  line3?: string;
  city?: string;
  state?: string;
  zip?: string;
  country?: string;
  first_name?: string;
  last_name?: string;
}

export interface Phone {
  number?: string;
  country_code?: string;
}

export interface PaymentBody {
  currency: string;
  amount: number;
  order_details?: Array<{
    product_name: string;
    quantity: number;
    amount: number;
  }>;
  confirm?: boolean;
  capture_method?: string;
  authentication_type?: string;
  customer_id?: string;
  email?: string;
  request_external_three_ds_authentication?: boolean;
  description?: string;
  shipping?: { address?: Address; phone?: Phone };
  metadata?: Record<string, unknown>;
  profile_id?: string;
  billing?: { email?: string; address?: Address; phone?: Phone };
  setup_future_usage?: string;
  [key: string]: unknown;
}

/** Overrides for paymentBody(): any key; `undefined` removes the key. */
export type PaymentBodyOverrides = {
  [K in keyof PaymentBody]?: PaymentBody[K] | undefined;
} & {
  [key: string]: unknown;
};

export const defaultBillingAddress: Readonly<Address> = Object.freeze({
  line1: "1467",
  line2: "Harrison Street",
  line3: "Harrison Street",
  city: "San Francisco",
  state: "California",
  zip: "94122",
  country: "US",
  first_name: "joseph",
  last_name: "Doe",
});

const defaultPhone: Phone = { number: "8056594427", country_code: "+91" };

const deepFreeze = <T>(o: T): T => {
  if (o && typeof o === "object") {
    Object.values(o as Record<string, unknown>).forEach(deepFreeze);
    Object.freeze(o);
  }
  return o;
};

/** Default POST /payments body: $29.99 USD, no 3DS, automatic capture, billing + shipping. Frozen. */
export const DEFAULT_PAYMENT_BODY: Readonly<PaymentBody> = deepFreeze({
  currency: "USD",
  amount: 2999,
  order_details: [
    { product_name: "Apple iPhone 15", quantity: 1, amount: 2999 },
  ],
  confirm: false,
  capture_method: "automatic",
  authentication_type: "no_three_ds",
  customer_id: "hyperswitch_sdk_demo_id",
  email: "hyperswitch_sdk_demo_id@gmail.com",
  request_external_three_ds_authentication: false,
  description: "Hello this is description",
  shipping: {
    address: { ...defaultBillingAddress },
    phone: { ...defaultPhone },
  },
  metadata: {
    udf1: "value1",
    new_customer: "true",
    login_date: "2019-09-10T10:11:12Z",
  },
  profile_id: "",
  billing: {
    email: "hyperswitch_sdk_demo_id@gmail.com",
    address: { ...defaultBillingAddress },
    phone: { ...defaultPhone },
  },
});

/** Returns a fresh copy of `body` without `keys`. */
export function withoutKeys<T extends Record<string, unknown>>(
  body: T,
  ...keys: string[]
): T {
  const copy = structuredClone(body) as Record<string, unknown>;
  for (const k of keys) delete copy[k];
  return copy as T;
}

/**
 * Fresh payment body = DEFAULT_PAYMENT_BODY shallow-merged with `overrides`
 * (top-level keys are replaced, not deep-merged). Keys whose override value is
 * `undefined` are removed.
 */
export function paymentBody(overrides: PaymentBodyOverrides = {}): PaymentBody {
  const body = structuredClone(DEFAULT_PAYMENT_BODY) as PaymentBody;
  for (const [k, v] of Object.entries(overrides)) {
    if (v === undefined) delete body[k];
    else body[k] = structuredClone(v);
  }
  return body;
}

/** Server-side POST /payments/:id/confirm payload (card, billing, browser_info). */
export function confirmBody(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  const base = {
    client_secret: "",
    return_url: `${CLIENT_BASE_URL}/completion`,
    payment_method: "card",
    payment_method_data: {
      card: {
        card_number: "4000000000001091",
        card_exp_month: "01",
        card_exp_year: "28",
        card_holder_name: "",
        card_cvc: "424",
        card_network: "Visa",
      },
    },
    billing: {
      address: {
        state: "New York",
        city: "New York",
        country: "US",
        first_name: "John",
        last_name: "Doe",
        zip: "10001",
        line1: "123 Main Street Apt 4B",
      },
    },
    email: "hyperswitch_sdk_demo_id@gmail.com",
    browser_info: {
      user_agent:
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      accept_header:
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
      language: "en-US",
      color_depth: 30,
      screen_height: 1117,
      screen_width: 1728,
      time_zone: -330,
      java_enabled: true,
      java_script_enabled: true,
    },
  };
  const body = structuredClone(base) as Record<string, unknown>;
  for (const [k, v] of Object.entries(overrides)) {
    if (v === undefined) delete body[k];
    else body[k] = structuredClone(v);
  }
  return body;
}

// Connector test card numbers.
export const stripeTestCard = "4000000000003220";
export const adyenTestCard = "4917610000000000";
export const bluesnapTestCard = "4000000000001091";
export const amexTestCard = "378282246310005";
export const visaTestCard = "4242424242424242";
export const netceteraChallengeTestCard = "348638267931507";
export const netceteraFrictionlessTestCard = "4929251897047956";
export const juspayChallengeTestCard = "5306889942833340";
export const juspayFrictionlessTestCard = "4929251897047956";
