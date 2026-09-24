// ---------------------------------------------------------------------------
// Hermetic engine: serves every non-local request of a browser context from
// recorded / hand-authored router responses (recordings/**.json).
//
// Layers, lowest priority first:
//   1. recordings/base/*.json                 shared defaults (card checkout)
//   2. recordings/<group>/_group.json          optional, owned by the group
//   3. recordings/<group>/<spec>.json          optional, per spec file (auto-loaded)
//   4. test.use({ hermeticFixtures: [...] })   explicit extra files
//   5. hermetic.use(...) / hermetic.override() per-test, at runtime
// A request is answered by the first matching route searching from the top
// layer down. Anything not matched is answered by a built-in stub (third-party
// scripts/styles/documents -> empty 200, logging/analytics -> 200 {}; recorded
// in the call log with source "stub") or, for router calls, a 404 that is
// recorded in `unmatched` and attached to the report.
// ---------------------------------------------------------------------------
import fs from "node:fs";
import path from "node:path";
import type { BrowserContext, Request, Route } from "@playwright/test";
import { RECORDINGS_DIR } from "../env";
import type { Credentials } from "../credentials";
import type {
  HermeticCall,
  HermeticFixtureFile,
  HermeticIntent,
  HermeticRoute,
} from "./types";
import {
  deepMerge,
  getPath,
  globToRegExp,
  partialMatch,
  pathPatternToRegExp,
  render,
} from "./template";

interface Layer {
  source: string;
  routes: HermeticRoute[];
}

export interface HermeticEngineOptions {
  credentials: Credentials;
  /** Origins that are served by the real local servers (SDK, demo shop, demo server). */
  localOrigins: string[];
  /** Router base URL (HYPERSWITCH_API_URL). Its pathname (e.g. "/api" on integ) is stripped before matching. */
  apiUrl?: string;
}

const LOCATION_ASSET = /\/assets\/v1\/jsons\/location\//;
/**
 * Hyperswitch-hosted routers serve the API under "/api" (beta/app/checkout/dev/integ/eu).
 * Some SDK frames (QR polling, 3DS method/auth, Plaid status) call GlobalVars.backendEndPoint
 * (https://beta.hyperswitch.io/api on sandbox builds) instead of the merchant's backend, so
 * "/api" is stripped on these hosts too and base routes such as `retrieve` still match.
 */
const HYPERSWITCH_ROUTER_HOST = /(^|\.)hyperswitch\.io$/;
const LOGGING_HINT =
  /(^|\.)(sentry\.io|scarf\.sh|google-analytics\.com|googletagmanager\.com)$|\/logs?(\/|$)|analytics/i;

let intentCounter = 0;
const rand = (n: number) =>
  Array.from(
    { length: n },
    () =>
      "abcdefghijklmnopqrstuvwxyz0123456789"[Math.floor(Math.random() * 36)],
  ).join("");

/** Reads a fixture file (JSON). `file` is absolute or relative to recordings/. */
export function readFixtureFile(file: string): HermeticFixtureFile {
  const abs = path.isAbsolute(file) ? file : path.join(RECORDINGS_DIR, file);
  const withExt = fs.existsSync(abs) ? abs : `${abs}.json`;
  const parsed = JSON.parse(
    fs.readFileSync(withExt, "utf-8"),
  ) as HermeticFixtureFile;
  if (!Array.isArray(parsed.routes)) {
    throw new Error(`[hermetic] ${withExt} has no "routes" array`);
  }
  return parsed;
}

export class HermeticEngine {
  private layers: Layer[] = [];
  private runtime: Layer = { source: "runtime (hermetic.use)", routes: [] };
  private served = new Map<HermeticRoute, number>();
  private waiters: Array<() => void> = [];
  private readonly localOrigins: Set<string>;
  private readonly apiUrl: string;
  private readonly apiBasePath: string;

  readonly calls: HermeticCall[] = [];
  /** "METHOD url" of router-looking requests no route matched (answered 404). */
  readonly unmatched: string[] = [];
  intent: HermeticIntent | undefined;

  constructor(private readonly opts: HermeticEngineOptions) {
    this.localOrigins = new Set(
      opts.localOrigins.map((o) => new URL(o).origin),
    );
    this.apiUrl = (opts.apiUrl || "").replace(/\/+$/, "");
    this.apiBasePath = this.apiUrl
      ? new URL(this.apiUrl).pathname.replace(/\/+$/, "")
      : "";
  }

  // ── Fixture loading ──────────────────────────────────────────────────────

  /** Loads every *.json file in `dir` (relative to recordings/) as one layer each, sorted by name. */
  loadDir(dir: string): this {
    const abs = path.isAbsolute(dir) ? dir : path.join(RECORDINGS_DIR, dir);
    if (!fs.existsSync(abs)) return this;
    for (const f of fs
      .readdirSync(abs)
      .filter((f) => f.endsWith(".json"))
      .sort()) {
      this.loadFile(path.join(abs, f));
    }
    return this;
  }

  /** Adds a fixture file as a new (higher-priority) layer. `optional` skips missing files. */
  loadFile(file: string, { optional = false } = {}): this {
    const abs = path.isAbsolute(file) ? file : path.join(RECORDINGS_DIR, file);
    const candidates = [abs, `${abs}.json`];
    const found = candidates.find(
      (c) => fs.existsSync(c) && fs.statSync(c).isFile(),
    );
    if (!found) {
      if (optional) return this;
      throw new Error(`[hermetic] fixture file not found: ${abs}`);
    }
    const fixture = readFixtureFile(found);
    this.layers.push({
      source: path.relative(RECORDINGS_DIR, found),
      routes: fixture.routes,
    });
    return this;
  }

  /**
   * Adds routes with the highest priority (per test). Later calls win over
   * earlier ones; within one call, routes are tried in the order given.
   */
  use(...routes: HermeticRoute[]): this {
    this.runtime.routes.unshift(...routes);
    return this;
  }

  /**
   * Replaces the currently effective route called `name` by a copy with `patch`
   * applied: a function receives a clone and returns the new route; an object is
   * deep-merged into the route's `body` (undefined deletes a key, arrays replace).
   */
  override(
    name: string,
    patch: Record<string, unknown> | ((route: HermeticRoute) => HermeticRoute),
  ): this {
    const current = this.findByName(name);
    if (!current)
      throw new Error(
        `[hermetic] override("${name}"): no route with that name is loaded`,
      );
    const clone = structuredClone(current);
    delete clone.times;
    const next =
      typeof patch === "function"
        ? patch(clone)
        : { ...clone, body: deepMerge(clone.body, patch) };
    return this.use(next);
  }

  /** The effective (highest-priority) route with this name, if any. */
  findByName(name: string): HermeticRoute | undefined {
    for (const layer of this.allLayersTopDown()) {
      const r = layer.routes.find((r) => r.name === name);
      if (r) return r;
    }
    return undefined;
  }

  /** Human-readable list of loaded layers (lowest priority first). */
  get sources(): string[] {
    return [...this.layers.map((l) => l.source), this.runtime.source];
  }

  // ── Intent state ─────────────────────────────────────────────────────────

  /** Pretends the router created a payment from `body`; returns the fake intent. */
  createIntent(body: Record<string, unknown>): HermeticIntent {
    intentCounter += 1;
    const paymentId = `pay_hermetic${String(intentCounter).padStart(4, "0")}${rand(10)}`;
    this.intent = {
      ...structuredClone(body),
      payment_id: paymentId,
      client_secret: `${paymentId}_secret_${rand(20)}`,
      status: body.confirm ? "processing" : "requires_payment_method",
      amount: Number(body.amount ?? 0),
      currency: String(body.currency ?? "USD"),
      profile_id: String(body.profile_id ?? ""),
      merchant_id: this.opts.credentials.merchantId,
      created: new Date().toISOString(),
    } as HermeticIntent;
    return this.intent;
  }

  /** Shallow-patches the intent (e.g. `{ status: "succeeded" }`). */
  setIntent(patch: Record<string, unknown>): void {
    if (!this.intent)
      throw new Error(
        "[hermetic] no intent yet — create one with checkout first",
      );
    Object.assign(this.intent, structuredClone(patch));
  }

  templateContext(
    extra: Record<string, unknown> = {},
  ): Record<string, unknown> {
    return {
      intent: this.intent ?? {},
      publishable_key: this.opts.credentials.publishableKey,
      api_url: this.apiUrl,
      merchant_id: this.opts.credentials.merchantId,
      profiles: this.opts.credentials.connectorProfileIds,
      now: new Date().toISOString(),
      ...extra,
    };
  }

  // ── Call log ─────────────────────────────────────────────────────────────

  /** Calls served so far, optionally filtered by route name, or by a RegExp on "METHOD url". */
  callsTo(filter?: string | RegExp): HermeticCall[] {
    if (filter === undefined) return [...this.calls];
    return this.calls.filter((c) =>
      typeof filter === "string"
        ? c.name === filter
        : filter.test(`${c.method} ${c.url}`),
    );
  }

  /** Resolves with the first call matching `filter` (already made or future). */
  async waitForCall(
    filter: string | RegExp,
    { timeout = 10_000 } = {},
  ): Promise<HermeticCall> {
    const deadline = Date.now() + timeout;
    for (;;) {
      const hit = this.callsTo(filter)[0];
      if (hit) return hit;
      const remaining = deadline - Date.now();
      if (remaining <= 0) {
        throw new Error(
          `[hermetic] timed out after ${timeout}ms waiting for a call to ${String(filter)}. ` +
            `Calls so far: ${this.calls.map((c) => `${c.name ?? "?"}(${c.method} ${c.path})`).join(", ") || "none"}`,
        );
      }
      await new Promise<void>((resolve) => {
        const t = setTimeout(resolve, Math.min(remaining, 250));
        this.waiters.push(() => {
          clearTimeout(t);
          resolve();
        });
      });
    }
  }

  // ── Routing ──────────────────────────────────────────────────────────────

  private isLocal(u: URL): boolean {
    return this.localOrigins.has(u.origin);
  }

  /** Installs the engine on `context`. Local SDK/demo requests go to the real servers. */
  async install(context: BrowserContext): Promise<void> {
    await context.route(
      (url: URL) => !this.isLocal(url) || LOCATION_ASSET.test(url.pathname),
      (route, request) => this.handle(route, request),
    );
  }

  private allLayersTopDown(): Layer[] {
    return [this.runtime, ...this.layers.slice().reverse()];
  }

  /** The pathname plus the variants with a router base path ("/api") stripped. */
  private candidatePaths(u: URL): string[] {
    const paths = [u.pathname];
    const strip = (prefix: string) => {
      if (prefix && u.pathname.startsWith(`${prefix}/`))
        paths.push(u.pathname.slice(prefix.length));
    };
    strip(this.apiBasePath);
    if (this.apiBasePath !== "/api" && HYPERSWITCH_ROUTER_HOST.test(u.hostname))
      strip("/api");
    return paths;
  }

  private matches(
    route: HermeticRoute,
    method: string,
    u: URL,
    requestBody: unknown,
  ): boolean {
    const wantMethod = (route.method || "GET").toUpperCase();
    if (wantMethod !== "*" && wantMethod !== method) return false;
    if (route.path) {
      const re = pathPatternToRegExp(route.path);
      if (!this.candidatePaths(u).some((p) => re.test(p))) return false;
    } else if (route.url) {
      if (!globToRegExp(route.url).test(u.href)) return false;
    } else {
      return false;
    }
    const limit = route.times;
    if (limit !== undefined && (this.served.get(route) ?? 0) >= limit)
      return false;
    if (route.match) {
      const ctx = this.templateContext();
      if (route.match.query) {
        const q = render(route.match.query, ctx);
        if (
          !Object.entries(q).every(
            ([k, v]) => u.searchParams.get(k) === String(v),
          )
        )
          return false;
      }
      if (
        route.match.body &&
        !partialMatch(requestBody, render(route.match.body, ctx))
      )
        return false;
      if (
        route.match.intent &&
        !partialMatch(this.intent ?? {}, render(route.match.intent, ctx))
      ) {
        return false;
      }
    }
    return true;
  }

  private findRoute(
    method: string,
    u: URL,
    body: unknown,
  ): { route: HermeticRoute; source: string } | undefined {
    for (const layer of this.allLayersTopDown()) {
      for (const route of layer.routes) {
        if (this.matches(route, method, u, body))
          return { route, source: layer.source };
      }
    }
    return undefined;
  }

  private record(call: Omit<HermeticCall, "at">): void {
    this.calls.push({ ...call, at: Date.now() });
    const waiters = this.waiters.splice(0);
    waiters.forEach((w) => w());
  }

  /**
   * Resolves a request against the loaded routes without a browser (also used by
   * fixtures/api.ts so Node-side API calls replay the same fixtures). Records the
   * call and applies `intentPatch`. Returns undefined when no route matches.
   */
  async serve(
    method: string,
    url: string,
    requestBody?: unknown,
  ): Promise<
    | {
        status: number;
        contentType: string;
        headers: Record<string, string>;
        body: unknown;
        raw: string;
      }
    | undefined
  > {
    const u = new URL(url);
    const m = method.toUpperCase();
    const found = this.findRoute(m, u, requestBody);
    if (!found) return undefined;
    const { route: r, source } = found;
    this.served.set(r, (this.served.get(r) ?? 0) + 1);
    const ctx = this.templateContext({
      request: {
        body: requestBody,
        query: Object.fromEntries(u.searchParams),
        path: u.pathname,
      },
    });
    const body = render(r.body, ctx);
    const status = r.status ?? 200;
    const isText = typeof body === "string";
    if (r.delayMs) await new Promise((res) => setTimeout(res, r.delayMs));
    if (r.intentPatch && this.intent) {
      Object.assign(
        this.intent,
        render(r.intentPatch, { ...ctx, response: body }),
      );
    }
    this.record({
      name: r.name,
      method: m,
      url: u.href,
      path: u.pathname,
      requestBody,
      status,
      responseBody: body,
      matched: true,
      source,
    });
    return {
      status,
      contentType:
        r.contentType ?? (isText ? "text/plain" : "application/json"),
      headers: { "access-control-allow-origin": "*", ...(r.headers ?? {}) },
      body,
      raw:
        body === undefined
          ? ""
          : isText
            ? (body as string)
            : JSON.stringify(body),
    };
  }

  async handle(route: Route, request: Request): Promise<void> {
    const u = new URL(request.url());
    const method = request.method().toUpperCase();
    let requestBody: unknown = undefined;
    const raw = request.postData();
    if (raw) {
      try {
        requestBody = JSON.parse(raw);
      } catch {
        requestBody = raw;
      }
    }

    const served = await this.serve(method, u.href, requestBody);
    if (served) {
      await route
        .fulfill({
          status: served.status,
          headers: served.headers,
          contentType: served.contentType,
          body: served.raw,
        })
        .catch(() => {});
      return;
    }

    // ── Built-in stubs ─────────────────────────────────────────────────────
    // Recorded (source "stub") so hermetic.calls() / waitForCall() also see
    // third-party navigations and script loads; images, fonts and logging are not.
    const type = request.resourceType();
    const stub = (
      status: number,
      contentType: string,
      body: string,
      { log = true } = {},
    ) => {
      if (log) {
        this.record({
          name: undefined,
          method,
          url: u.href,
          path: u.pathname,
          requestBody,
          status,
          responseBody: undefined,
          matched: false,
          source: "stub",
        });
      }
      return route
        .fulfill({
          status,
          contentType,
          body,
          headers: { "access-control-allow-origin": "*" },
        })
        .catch(() => {});
    };

    if (LOCATION_ASSET.test(u.pathname)) {
      // No fixture: a non-JSON 404 makes the SDK fall back to its bundled country/state
      // data. (A JSON body such as "{}" would be decoded as an empty country list, because
      // S3Utils never checks resp.ok, and the Country/State dropdowns would vanish.)
      return stub(404, "text/plain", "Not Found");
    }
    // Third-party SDK scripts are sometimes fetched rather than loaded via <script>.
    const kind = /\.m?js$/.test(u.pathname) ? "script" : type;
    switch (kind) {
      case "script":
        return stub(
          200,
          "application/javascript",
          "/* hermetic: third-party script stubbed */",
        );
      case "stylesheet":
        return stub(200, "text/css", "/* hermetic */");
      case "font":
      case "image":
      case "media":
        return stub(404, "text/plain", "", { log: false });
      case "document":
        return stub(
          200,
          "text/html",
          "<!doctype html><html><body data-hermetic-stub></body></html>",
        );
      default:
        break;
    }
    if (
      LOGGING_HINT.test(u.hostname) ||
      LOGGING_HINT.test(u.pathname) ||
      type === "ping"
    ) {
      return stub(200, "application/json", "{}", { log: false });
    }

    const entry = `${method} ${u.origin}${u.pathname}${u.search}`;
    this.unmatched.push(entry);
    this.record({
      name: undefined,
      method,
      url: u.href,
      path: u.pathname,
      requestBody,
      status: 404,
      responseBody: undefined,
      matched: false,
      source: "unmatched",
    });
    return stub(
      404,
      "application/json",
      JSON.stringify({
        error: {
          type: "hermetic_unmatched",
          message: `No hermetic fixture for ${method} ${u.pathname}. Add one under playwright-tests/recordings/ (see README).`,
        },
      }),
    );
  }

  /** Value lookup in the template context, e.g. engine.lookup("intent.status"). */
  lookup(dotted: string): unknown {
    return getPath(this.templateContext(), dotted);
  }
}
