// ---------------------------------------------------------------------------
// checkout: create a payment intent and open the demo shop on it.
// ---------------------------------------------------------------------------
import type { Page } from "@playwright/test";
import { CLIENT_BASE_URL } from "./env";
import type { TestCredentials } from "./credentials";
import type { HyperswitchApi, PaymentIntent } from "./api";
import { paymentBody, type PaymentBody } from "./payment-body";
import type { Sdk } from "./sdk";

export interface ClientUrlOptions {
  profileId?: string;
  locale?: string;
  theme?: string;
  layout?: string | Record<string, unknown>;
  options?: Record<string, unknown>;
}

/**
 * Demo-shop URL for a client secret. `isTestMode=true` makes the demo app take
 * the client secret, publishable key and profile from the query string instead
 * of creating its own intent.
 */
export function getClientURL(
  clientSecret: string,
  publishableKey: string,
  { profileId, locale, theme, layout, options }: ClientUrlOptions = {},
  baseUrl: string = CLIENT_BASE_URL,
): string {
  let url = `${baseUrl}?isTestMode=true&clientSecret=${clientSecret}&publishableKey=${publishableKey}`;
  if (profileId) url += `&profileId=${encodeURIComponent(profileId)}`;
  if (locale) url += `&locale=${locale}`;
  if (theme) url += `&theme=${theme}`;
  if (layout) {
    const layoutValue =
      typeof layout === "string" ? layout : JSON.stringify(layout);
    url += `&layout=${encodeURIComponent(layoutValue)}`;
  }
  if (options) url += `&options=${encodeURIComponent(JSON.stringify(options))}`;
  return url;
}

export interface OpenCheckoutOptions extends Omit<
  ClientUrlOptions,
  "profileId"
> {
  /** Payment body; default paymentBody(). profile_id defaults to the Stripe profile. */
  body?: PaymentBody;
  /** Override the publishable key put in the URL (e.g. error-handling specs). */
  publishableKey?: string;
  /** Override the profileId put in the URL (default: the intent's profile). */
  profileId?: string;
  /** Wait for the card fields to render before returning. Default false. */
  waitForReady?: boolean;
}

export interface OpenedCheckout extends PaymentIntent {
  url: string;
}

export class Checkout {
  /** The last intent created in this test. */
  lastIntent: PaymentIntent | undefined;

  constructor(
    private readonly page: Page,
    private readonly api: HyperswitchApi,
    private readonly credentials: TestCredentials,
    private readonly sdk: Sdk,
  ) {}

  /** POST /payments (hermetic: fake intent). */
  async createPaymentIntent(
    body: PaymentBody = paymentBody(),
  ): Promise<PaymentIntent> {
    this.lastIntent = await this.api.createPaymentIntent(body);
    return this.lastIntent;
  }

  /** Demo-shop URL for an intent (or a raw client secret). */
  url(
    intent: PaymentIntent | string,
    opts: ClientUrlOptions & { publishableKey?: string } = {},
  ): string {
    const clientSecret =
      typeof intent === "string" ? intent : intent.clientSecret;
    const profileId =
      opts.profileId ??
      (typeof intent === "string" ? undefined : intent.profileId);
    return getClientURL(
      clientSecret,
      opts.publishableKey ?? this.credentials.publishableKey,
      {
        ...opts,
        profileId,
      },
    );
  }

  /** Creates the intent and opens the demo shop on it. */
  async open(opts: OpenCheckoutOptions = {}): Promise<OpenedCheckout> {
    const intent = await this.createPaymentIntent(opts.body ?? paymentBody());
    const url = this.url(intent, opts);
    await this.page.goto(url);
    if (opts.waitForReady) await this.sdk.waitForReady();
    return { ...intent, url };
  }
}
