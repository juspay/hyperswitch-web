// ---------------------------------------------------------------------------
// Node-side router calls (create intent, retrieve, poll status, payment
// methods). In the hermetic tier nothing leaves the machine: every call is
// answered by the same hermetic engine that serves the browser.
//
// Live calls use Node's global fetch, NOT Playwright's APIRequestContext: the
// latter records every request (with its `api-key` header, i.e. the merchant's
// secret key) in traces and the HTML report that CI uploads. `callLog` keeps a redacted summary instead (attached on failure).
// ---------------------------------------------------------------------------
import { expect } from "@playwright/test";
import { HYPERSWITCH_API_URL } from "./env";
import type { TestCredentials } from "./credentials";
import type { Hermetic } from "./hermetic";
import type { PaymentBody } from "./payment-body";

export interface PaymentIntent {
  paymentId: string;
  clientSecret: string;
  /** profile_id the intent was created on (default: Stripe profile). */
  profileId: string;
  /** The exact body sent to POST /payments. */
  body: PaymentBody;
  /** Router response (hermetic: the fake intent). */
  response: Record<string, unknown>;
}

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

/** Masks client secrets (`…_secret_<random>`) in a URL/path for logs and reports. */
export const redactClientSecrets = (s: string): string =>
  s.replace(/(_secret_)[A-Za-z0-9]+/g, "$1***");

export interface ApiCallLogEntry {
  method: string;
  /** Path + query, client secrets masked. */
  path: string;
  /** "publishable" or "secret" (never the key itself). */
  key: "publishable" | "secret" | "other";
  status: number;
  ms: number;
}

export class HyperswitchApi {
  /** Redacted log of live router calls made by this test (empty in hermetic mode). */
  readonly callLog: ApiCallLogEntry[] = [];

  constructor(
    private readonly credentials: TestCredentials,
    private readonly hermetic: Hermetic,
    readonly baseUrl: string = HYPERSWITCH_API_URL,
  ) {}

  /** Low-level call. Hermetic: served from recordings (404 JSON if no route matches). */
  async call(
    method: "GET" | "POST",
    path: string,
    {
      apiKey = this.credentials.secretKey,
      data,
    }: { apiKey?: string; data?: unknown } = {},
  ): Promise<{ status: number; body: Json }> {
    const url = `${this.baseUrl}${path}`;
    if (this.hermetic.enabled) {
      const served = await this.hermetic.engine!.serve(method, url, data);
      if (!served) {
        return {
          status: 404,
          body: {
            error: { type: "hermetic_unmatched", message: `${method} ${path}` },
          },
        };
      }
      return { status: served.status, body: (served.body ?? {}) as Json };
    }
    const key =
      apiKey === this.credentials.secretKey
        ? "secret"
        : apiKey === this.credentials.publishableKey
          ? "publishable"
          : "other";
    const started = Date.now();
    let response: Response;
    try {
      response = await fetch(url, {
        method,
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "api-key": apiKey,
        },
        body: data === undefined ? undefined : JSON.stringify(data),
        signal: AbortSignal.timeout(60_000),
      });
    } catch (err) {
      // Never let the URL (client secret) or headers (api key) into the error.
      throw new Error(
        `[api] ${method} ${redactClientSecrets(path)} failed: ${(err as Error).message}`,
      );
    }
    const text = await response.text();
    let body: Json = {};
    try {
      body = text ? JSON.parse(text) : {};
    } catch {
      body = { raw: text };
    }
    this.callLog.push({
      method,
      path: redactClientSecrets(path),
      key,
      status: response.status,
      ms: Date.now() - started,
    });
    return { status: response.status, body };
  }

  /**
   * POST /payments with the secret key; fills profile_id with the Stripe profile when the body has none.
   * Hermetic: no network — returns a fake payment_id/client_secret that the
   * recordings are templated with.
   */
  async createPaymentIntent(body: PaymentBody): Promise<PaymentIntent> {
    const finalBody: PaymentBody = structuredClone(body);
    if (!finalBody.profile_id)
      finalBody.profile_id = this.credentials.defaultProfileId;

    if (this.hermetic.enabled) {
      const intent = this.hermetic.engine!.createIntent(finalBody);
      return {
        paymentId: intent.payment_id,
        clientSecret: intent.client_secret,
        profileId: intent.profile_id,
        body: finalBody,
        response: { ...intent },
      };
    }

    const { status, body: res } = await this.call("POST", "/payments", {
      data: finalBody,
    });
    expect(
      res,
      `POST /payments failed (${status}): ${JSON.stringify(res).slice(0, 500)}`,
    ).toHaveProperty("client_secret");
    const intent: PaymentIntent = {
      paymentId: res.payment_id,
      clientSecret: res.client_secret,
      profileId: res.profile_id ?? finalBody.profile_id ?? "",
      body: finalBody,
      response: res,
    };
    this.hermetic.noteLiveIntent(intent);
    return intent;
  }

  /** GET /payments/:id (force_sync by default) with the secret key. */
  async retrievePayment(
    paymentId: string,
    { forceSync = true } = {},
  ): Promise<Json> {
    const { body } = await this.call(
      "GET",
      `/payments/${paymentId}${forceSync ? "?force_sync=true" : ""}`,
    );
    if (this.hermetic.enabled && body?.error?.type === "hermetic_unmatched") {
      return { ...(this.hermetic.intent ?? {}) };
    }
    return body;
  }

  /**
   * Polls GET /payments/:id?force_sync=true every
   * `intervalMs` until status === expectedStatus, failing after `timeoutMs`.
   * Hermetic: reads the status the recordings put on the intent (confirm's intentPatch).
   */
  async pollPaymentStatus(
    paymentId: string,
    expectedStatus: string,
    {
      timeoutMs = 20_000,
      intervalMs = 2_000,
    }: { timeoutMs?: number; intervalMs?: number } = {},
  ): Promise<Json> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const payment = await this.retrievePayment(paymentId);
      if (payment.status === expectedStatus) return payment;
      if (Date.now() >= deadline) {
        throw new Error(
          `Payment did not reach "${expectedStatus}" within ${timeoutMs} ms. Last status: ${payment.status}`,
        );
      }
      await new Promise((r) =>
        setTimeout(r, this.hermetic.enabled ? 100 : intervalMs),
      );
    }
  }

  /** GET /payments/:id/client — what the SDK renders from (payment_methods_enabled, saved methods). */
  async clientList(paymentId: string, clientSecret: string): Promise<Json> {
    const { body } = await this.call(
      "GET",
      `/payments/${paymentId}/client?client_secret=${clientSecret}`,
      { apiKey: this.credentials.publishableKey },
    );
    return body;
  }

  /** Legacy GET /account/payment_methods (nested payment_methods with required_fields). */
  async accountPaymentMethods(clientSecret: string): Promise<Json> {
    const { body } = await this.call(
      "GET",
      `/account/payment_methods?client_secret=${clientSecret}`,
      {
        apiKey: this.credentials.publishableKey,
      },
    );
    return body;
  }

  /** required_fields of card/<cardType> from the legacy list (input for sdk.testDynamicFields()). */
  async cardRequiredFields(
    clientSecret: string,
    cardType = "debit",
  ): Promise<Record<string, unknown>> {
    const list = await this.accountPaymentMethods(clientSecret);
    const card = (list.payment_methods ?? []).find(
      (pm: Json) => pm.payment_method === "card",
    );
    const type = card?.payment_method_types?.find(
      (t: Json) => t.payment_method_type === cardType,
    );
    return type?.required_fields ?? {};
  }

  /** One-line summary of payment_methods_enabled, for skip/debug logs. */
  async describePaymentMethods(
    paymentId: string,
    clientSecret: string,
  ): Promise<string> {
    const list = await this.clientList(paymentId, clientSecret).catch(
      () => ({}) as Json,
    );
    const pms = (list.payment_methods_enabled ?? []) as Json[];
    return (
      pms
        .map((pm) => `${pm.payment_method}/${pm.payment_method_type}`)
        .join(" | ") || "(empty)"
    );
  }
}
