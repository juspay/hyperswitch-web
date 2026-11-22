// ---------------------------------------------------------------------------
// RECORD=1 on the live project: capture the router responses a test triggers
// and write them, redacted and templated, in the hermetic fixture format to
//   recordings/_recorded/<group>/<spec>/<test-title>.json
// A porter then reviews the file and moves the routes they need into
// recordings/<group>/<spec>.json (see README "Recording fixtures").
// ---------------------------------------------------------------------------
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import type { BrowserContext, Request, TestInfo } from "@playwright/test";
import { E2E_DIR, RECORDINGS_DIR, TEST_ENV } from "../env";
import type { Credentials } from "../credentials";
import type { HermeticFixtureFile, HermeticRoute } from "./types";
import { slugify } from "./template";

/** Canonical names for router endpoints the SDK calls (used by base fixtures and recordings). */
export const ROUTE_NAMES: Array<
  [method: string, pattern: RegExp, name: string, template: string]
> = [
  [
    "GET",
    /^\/payments\/[^/]+\/client$/,
    "clientList",
    "/payments/:paymentId/client",
  ],
  [
    "GET",
    /^\/v1\/sdk\/configs\/web\/sdk_config\.json$/,
    "sdkConfigs",
    "/v1/sdk/configs/web/sdk_config.json",
  ],
  [
    "POST",
    /^\/payments\/session_tokens$/,
    "sessionTokens",
    "/payments/session_tokens",
  ],
  [
    "POST",
    /^\/payments\/[^/]+\/confirm$/,
    "confirm",
    "/payments/:paymentId/confirm",
  ],
  [
    "POST",
    /^\/payments\/[^/]+\/complete_authorize$/,
    "completeAuthorize",
    "/payments/:paymentId/complete_authorize",
  ],
  [
    "POST",
    /^\/payments\/[^/]+\/eligibility$/,
    "eligibility",
    "/payments/:paymentId/eligibility",
  ],
  [
    "POST",
    /^\/payments\/[^/]+\/3ds\/authentication$/,
    "threeDsAuthentication",
    "/payments/:paymentId/3ds/authentication",
  ],
  [
    "POST",
    /^\/payments\/[^/]+\/calculate_tax$/,
    "calculateTax",
    "/payments/:paymentId/calculate_tax",
  ],
  [
    "POST",
    /^\/payments\/[^/]+\/post_session_tokens$/,
    "postSessionTokens",
    "/payments/:paymentId/post_session_tokens",
  ],
  ["GET", /^\/payments\/[^/]+$/, "retrieve", "/payments/:paymentId"],
  [
    "GET",
    /^\/account\/payment_methods$/,
    "accountPaymentMethods",
    "/account/payment_methods",
  ],
  [
    "GET",
    /^\/customers\/payment_methods$/,
    "customerPaymentMethods",
    "/customers/payment_methods",
  ],
  ["GET", /^\/poll\/status\/[^/]+$/, "pollStatus", "/poll/status/:pollId"],
];

// Keys whose values are secrets. client_secret is templated instead (the SDK needs it to match).
const SENSITIVE_KEY =
  /^(api[-_]?key|secret[-_]?key|publishable[-_]?key|password|authorization|cookie|signature|ephemeral[-_]?key|client[-_]?token|access[-_]?token|refresh[-_]?token|session[-_]?token[-_]?data|merchant[-_]?secret|secret|ip[-_]?address)$/i;
const HASHED_KEY = /^(payment_token|payment_method_id|card_token|token)$/i;
/**
 * Per-wallet `session_token` strings (e.g. Klarna's client token, SessionsType.res). The
 * response's top-level `session_token` is the array of wallets, so only strings are redacted.
 */
const SESSION_TOKEN_KEY = /^session[-_]?token$/i;

/**
 * Secrets recognised by their shape, scrubbed from every recorded string (JSON values, HTML
 * pages, paths) after the run's own ids were templated: other payments' client secrets
 * (router redirect pages carry `payment_intent_client_secret`), Stripe-style and Hyperswitch
 * API keys, JWTs and email addresses.
 */
const SECRET_PATTERNS: Array<[RegExp, string]> = [
  [/(_secret_)[A-Za-z0-9]{8,}/g, "$1REDACTED"],
  [/\b(pk|sk|rk)_(test|live|snd|prd)_[A-Za-z0-9]+/g, "$1_$2_REDACTED"],
  [/\b(snd|dev|prd)_[A-Za-z0-9]{20,}\b/g, "$1_REDACTED"],
  [
    /\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*/g,
    "REDACTED_JWT",
  ],
  [
    /[A-Za-z0-9._%+-]+@[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g,
    "redacted@example.com",
  ],
];

/** Applies SECRET_PATTERNS to one string. */
export function scrubSecrets(s: string): string {
  return SECRET_PATTERNS.reduce((acc, [re, to]) => acc.replace(re, to), s);
}

/** Hyperswitch-hosted router ("/api" prefix); see HYPERSWITCH_ROUTER_HOST in engine.ts. */
const HYPERSWITCH_ROUTER_HOST = /(^|\.)hyperswitch\.io$/;

const shortHash = (s: string) =>
  crypto.createHash("sha1").update(s).digest("hex").slice(0, 12);

export interface RedactionContext {
  replacements: Array<[from: string, to: string]>;
}

/**
 * Recursively redacts secrets and replaces run-specific ids with {{placeholders}}:
 * the run's ids first (so the intent's own client secret stays usable as
 * {{intent.client_secret}}), then secret-looking strings (scrubSecrets), and
 * secret keys by name.
 */
export function redact(value: unknown, ctx: RedactionContext): unknown {
  if (typeof value === "string") {
    let s = value;
    for (const [from, to] of ctx.replacements)
      if (from) s = s.split(from).join(to);
    return scrubSecrets(s);
  }
  if (Array.isArray(value)) return value.map((v) => redact(v, ctx));
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value)) {
      if (SENSITIVE_KEY.test(k) && v !== null && v !== "") out[k] = "REDACTED";
      else if (SESSION_TOKEN_KEY.test(k) && typeof v === "string" && v)
        out[k] = "REDACTED";
      else if (HASHED_KEY.test(k) && typeof v === "string" && v)
        out[k] = `redacted_${shortHash(v)}`;
      else out[k] = redact(v, ctx);
    }
    return out;
  }
  return value;
}

interface Captured {
  method: string;
  url: URL;
  status: number;
  contentType: string;
  body: unknown;
}

export class Recorder {
  private captured: Captured[] = [];
  private pending: Promise<void>[] = [];
  private readonly apiOrigin: string;
  private readonly apiBasePath: string;

  constructor(apiUrl: string) {
    const u = new URL(apiUrl);
    this.apiOrigin = u.origin;
    this.apiBasePath = u.pathname.replace(/\/+$/, "");
  }

  attach(context: BrowserContext): void {
    const onFinished = (request: Request) => {
      const u = new URL(request.url());
      // The router, plus GlobalVars.backendEndPoint (e.g. https://beta.hyperswitch.io/api), which the
      // SDK's fullscreen frames (QR, 3DS, Plaid) call instead of the merchant's backend.
      const isBackendEndPoint =
        HYPERSWITCH_ROUTER_HOST.test(u.hostname) &&
        u.pathname.startsWith("/api/");
      if (u.origin !== this.apiOrigin && !isBackendEndPoint) return;
      this.pending.push(
        (async () => {
          const response = await request.response();
          if (!response) return;
          const contentType = response.headers()["content-type"] || "";
          let body: unknown;
          try {
            const text = await response.text();
            body = contentType.includes("json") ? JSON.parse(text) : text;
          } catch {
            return;
          }
          this.captured.push({
            method: request.method(),
            url: u,
            status: response.status(),
            contentType,
            body,
          });
        })().catch(() => {}),
      );
    };
    context.on("requestfinished", onFinished);
  }

  get count(): number {
    return this.captured.length;
  }

  /** Writes the capture (if any) and returns the file path. */
  async save(
    testInfo: TestInfo,
    ids: {
      paymentId?: string;
      clientSecret?: string;
      customerId?: string;
      profileId?: string;
    },
    credentials: Credentials,
  ): Promise<string | undefined> {
    await Promise.all(this.pending);
    if (this.captured.length === 0) return undefined;

    const ctx: RedactionContext = {
      replacements: [
        [ids.clientSecret ?? "", "{{intent.client_secret}}"],
        [ids.paymentId ?? "", "{{intent.payment_id}}"],
        [credentials.secretKey, "REDACTED"],
        [credentials.publishableKey, "{{publishable_key}}"],
        [credentials.merchantId, "{{merchant_id}}"],
        ...Object.entries(credentials.connectorProfileIds).map(
          ([c, id]) => [id, `{{profiles.${c}}}`] as [string, string],
        ),
      ],
    };

    const routes: HermeticRoute[] = [];
    for (const c of this.captured) {
      let p = c.url.pathname;
      if (this.apiBasePath && p.startsWith(`${this.apiBasePath}/`))
        p = p.slice(this.apiBasePath.length);
      else if (
        HYPERSWITCH_ROUTER_HOST.test(c.url.hostname) &&
        p.startsWith("/api/")
      )
        p = p.slice(4);
      const known = ROUTE_NAMES.find(([m, re]) => m === c.method && re.test(p));
      const templatePath = known
        ? known[3]
        : scrubSecrets(
            ids.paymentId ? p.split(ids.paymentId).join(":paymentId") : p,
          );
      const body = redact(c.body, ctx);
      const route: HermeticRoute = {
        name: known?.[2] ?? `${c.method.toLowerCase()} ${templatePath}`,
        method: c.method,
        path: templatePath,
        status: c.status,
        ...(c.contentType && !c.contentType.includes("json")
          ? { contentType: c.contentType }
          : {}),
        body,
      };
      if (
        known?.[2] === "confirm" &&
        body &&
        typeof body === "object" &&
        "status" in body
      ) {
        route.intentPatch = { status: "{{response.status}}" };
      }
      const prev = routes[routes.length - 1];
      // Collapse consecutive identical responses for the same endpoint.
      if (
        prev &&
        prev.method === route.method &&
        prev.path === route.path &&
        prev.status === route.status &&
        JSON.stringify(prev.body) === JSON.stringify(route.body)
      ) {
        prev.times = (prev.times ?? 1) + 1;
        continue;
      }
      routes.push(route);
    }
    // Keep response sequences (e.g. retrieve polled until "succeeded") in order:
    // every occurrence except the last one of an endpoint is served a limited
    // number of times; the last one is served forever.
    const lastIndex = new Map<string, number>();
    routes.forEach((r, i) => lastIndex.set(`${r.method} ${r.path}`, i));
    routes.forEach((r, i) => {
      if (lastIndex.get(`${r.method} ${r.path}`) === i) delete r.times;
      else r.times = r.times ?? 1;
    });

    const fixture: HermeticFixtureFile = {
      _source: "recorded",
      _note:
        "Captured with RECORD=1 and redacted automatically. Review before committing.",
      _recordedAt: new Date().toISOString(),
      _env: TEST_ENV,
      _test: testInfo.titlePath.join(" › "),
      routes,
    };
    const rel = path
      .relative(E2E_DIR, testInfo.file)
      .replace(/\.spec\.ts$/, "");
    const out = path.join(
      RECORDINGS_DIR,
      "_recorded",
      rel,
      `${slugify(testInfo.title)}.json`,
    );
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, `${JSON.stringify(fixture, null, 2)}\n`);
    return out;
  }
}
