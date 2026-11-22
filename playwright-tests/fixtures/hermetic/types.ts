// Types for the hermetic tier's recorded / hand-authored router responses.
// See playwright-tests/README.md ("Hermetic fixtures") for the full contract.

/**
 * Extra conditions a request must satisfy for a route to match. A placeholder
 * that resolves to undefined makes the route never match.
 */
export interface HermeticMatch {
  /** Every listed query parameter must be present with this (templated) value. */
  query?: Record<string, string>;
  /** Deep-partial match against the JSON request body (templated). */
  body?: Record<string, unknown>;
  /**
   * Deep-partial match against the current hermetic intent (templated), e.g.
   * `{ "profile_id": "{{profiles.trustpay}}" }` or `{ "customer_id": "saved_card_user" }`.
   */
  intent?: Record<string, unknown>;
}

export interface HermeticRoute {
  /**
   * Stable name used by `hermetic.override(name, ...)`, `hermetic.calls(name)` and
   * reports. Base names: clientList, sdkConfigs, sessionTokens, confirm, retrieve,
   * accountPaymentMethods, customerPaymentMethods, eligibility, completeAuthorize, ...
   */
  name?: string;
  /** HTTP method, default "GET". "*" matches any method. */
  method?: string;
  /**
   * Router path pattern, e.g. "/payments/:paymentId/client". Matched against the
   * request pathname with any API base path (e.g. integ's "/api") stripped; the
   * host is ignored, so recordings replay regardless of TEST_ENV. Templated like
   * `match`, e.g. "/payments/redirect/{{intent.payment_id}}/{{merchant_id}}/:attemptId".
   */
  path?: string;
  /** Alternative to `path`: glob (`*`, `**`) matched against the full URL, for non-router hosts. Templated. */
  url?: string;
  match?: HermeticMatch;
  /** Response status, default 200. */
  status?: number;
  headers?: Record<string, string>;
  /** Default: application/json for object bodies, text/plain for strings. */
  contentType?: string;
  /**
   * Response body. Strings of the form "{{a.b}}" are replaced by the value at
   * that path in the template context (raw JSON value when the whole string is a
   * placeholder, string interpolation otherwise). Context:
   *   intent.*        the payment created by checkout (payment_id, client_secret,
   *                   status, amount, currency, customer_id, profile_id, billing, ...
   *                   = the create-payment body + generated ids)
   *   publishable_key, merchant_id, profiles.<connector>, now (ISO timestamp),
   *   api_url         the router base URL (HYPERSWITCH_API_URL, e.g. https://sandbox.hyperswitch.io),
   *   request.body.*  the parsed JSON request body, request.query.*
   */
  body?: unknown;
  /** Serve at most this many times, then fall through to the next matching route. */
  times?: number;
  /** Artificial latency before fulfilling. */
  delayMs?: number;
  /**
   * Shallow patch applied to the hermetic intent after this route is served.
   * Templated with the same context plus `response` (the rendered body), e.g.
   * `{ "status": "{{response.status}}" }` on confirm.
   */
  intentPatch?: Record<string, unknown>;
}

export interface HermeticFixtureFile {
  /**
   * "synthetic" = hand-authored (no sandbox access when written);
   * "recorded"  = captured from a live run with RECORD=1 (redacted).
   */
  _source: "synthetic" | "recorded" | (string & {});
  _note?: string;
  _recordedAt?: string;
  _env?: string;
  _test?: string;
  routes: HermeticRoute[];
}

/** The payment the hermetic tier pretends the router created. */
export interface HermeticIntent {
  payment_id: string;
  client_secret: string;
  status: string;
  amount: number;
  currency: string;
  customer_id?: string;
  profile_id: string;
  [key: string]: unknown;
}

/** One request served (or refused) by the hermetic engine. */
export interface HermeticCall {
  name: string | undefined;
  method: string;
  url: string;
  path: string;
  requestBody: unknown;
  status: number;
  responseBody: unknown;
  /** True when a fixture route answered. */
  matched: boolean;
  /**
   * The fixture layer that answered (e.g. "base/payments.json"), "stub" for the
   * built-in third-party stubs (blank documents, empty scripts/styles, location
   * data 404), "router-auth" for the router's 404 HE_02 / 400 IR_09 to a call for
   * another payment or with the wrong client secret, or "unmatched" for router
   * calls nothing answered (404).
   */
  source: string;
  at: number;
}
