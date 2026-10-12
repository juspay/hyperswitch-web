// ---------------------------------------------------------------------------
// `hermetic` fixture facade. Safe to call from specs that also run live: on the
// live projects every mutator is a no-op (the real router answers), and the
// call log is empty.
// ---------------------------------------------------------------------------
import type { HermeticEngine } from "./engine";
import type { HermeticCall, HermeticIntent, HermeticRoute } from "./types";

export type {
  HermeticCall,
  HermeticIntent,
  HermeticRoute,
  HermeticFixtureFile,
  HermeticMatch,
} from "./types";

export class Hermetic {
  private liveIds: {
    paymentId?: string;
    clientSecret?: string;
    profileId?: string;
  } = {};

  constructor(readonly engine: HermeticEngine | undefined) {}

  /** True on the hermetic project. */
  get enabled(): boolean {
    return !!this.engine;
  }

  /** Adds per-test routes with the highest priority. No-op on live projects. */
  use(...routes: HermeticRoute[]): this {
    this.engine?.use(...routes);
    return this;
  }

  /** Loads an extra fixture file (relative to recordings/) as a new top layer. No-op live. */
  load(file: string): this {
    this.engine?.loadFile(file);
    return this;
  }

  /**
   * Replace the effective route `name` (e.g. "clientList", "confirm"): an object
   * is deep-merged into its body, a function gets a clone and returns the new
   * route. No-op live.
   */
  override(
    name: string,
    patch: Record<string, unknown> | ((route: HermeticRoute) => HermeticRoute),
  ): this {
    this.engine?.override(name, patch);
    return this;
  }

  /** Calls served so far (by route name, or RegExp on "METHOD url"). Empty live. */
  calls(filter?: string | RegExp): HermeticCall[] {
    return this.engine?.callsTo(filter) ?? [];
  }

  /** Waits for a call (hermetic only; resolves undefined immediately on live). */
  async waitForCall(
    filter: string | RegExp,
    opts?: { timeout?: number },
  ): Promise<HermeticCall | undefined> {
    return this.engine?.waitForCall(filter, opts);
  }

  /** The fake intent (hermetic) — undefined live. */
  get intent(): HermeticIntent | undefined {
    return this.engine?.intent;
  }

  /** Patch the fake intent, e.g. setIntent({ status: "succeeded" }). No-op live. */
  setIntent(patch: Record<string, unknown>): void {
    this.engine?.setIntent(patch);
  }

  /** Requests to non-local hosts that no route matched (answered 404). */
  get unmatched(): string[] {
    return this.engine?.unmatched ?? [];
  }

  /** @internal used by the live recorder to template ids. */
  noteLiveIntent(i: {
    paymentId: string;
    clientSecret: string;
    profileId: string;
  }): void {
    this.liveIds = {
      paymentId: i.paymentId,
      clientSecret: i.clientSecret,
      profileId: i.profileId,
    };
  }

  /** @internal */
  get liveIntentIds() {
    return this.liveIds;
  }
}
