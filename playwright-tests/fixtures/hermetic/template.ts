// Small helpers shared by the hermetic engine and the recorder.

const PLACEHOLDER = /\{\{\s*([\w.$-]+)\s*\}\}/g;
const WHOLE_PLACEHOLDER = /^\{\{\s*([\w.$-]+)\s*\}\}$/;

export const getPath = (obj: unknown, dotted: string): unknown =>
  dotted.split(".").reduce<unknown>((acc, key) => {
    if (acc && typeof acc === "object")
      return (acc as Record<string, unknown>)[key];
    return undefined;
  }, obj);

/**
 * Recursively resolves "{{a.b}}" placeholders in `value` against `ctx`. The engine's
 * context (HermeticEngine.templateContext) provides intent.*, publishable_key,
 * merchant_id, profiles.<connector>, api_url (router base URL), now and request.*.
 */
export function render<T>(value: T, ctx: Record<string, unknown>): T {
  if (typeof value === "string") {
    const whole = value.match(WHOLE_PLACEHOLDER);
    if (whole) return getPath(ctx, whole[1]) as T;
    return value.replace(PLACEHOLDER, (_, p: string) => {
      const v = getPath(ctx, p);
      return v === undefined || v === null
        ? ""
        : typeof v === "object"
          ? JSON.stringify(v)
          : String(v);
    }) as T;
  }
  if (Array.isArray(value)) return value.map((v) => render(v, ctx)) as T;
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value)) {
      const r = render(v, ctx);
      if (r !== undefined) out[k] = r;
    }
    return out as T;
  }
  return value;
}

/**
 * Placeholders in `value` (strings, arrays and objects, recursively) that resolve
 * to `undefined` in `ctx`. render() drops or blanks those, which in a `match`
 * would turn a condition into "matches anything", so the engine checks first.
 */
export function unresolvedPlaceholders(
  value: unknown,
  ctx: Record<string, unknown>,
): string[] {
  if (typeof value === "string")
    return [...value.matchAll(PLACEHOLDER)]
      .map((m) => m[1])
      .filter((p) => getPath(ctx, p) === undefined);
  if (Array.isArray(value))
    return value.flatMap((v) => unresolvedPlaceholders(v, ctx));
  if (value && typeof value === "object")
    return Object.values(value).flatMap((v) => unresolvedPlaceholders(v, ctx));
  return [];
}

/** True when every key in `expected` deep-equals (recursively partial for objects) `actual`. */
export function partialMatch(actual: unknown, expected: unknown): boolean {
  if (expected === null || typeof expected !== "object")
    return actual === expected;
  if (Array.isArray(expected)) {
    return (
      Array.isArray(actual) &&
      actual.length === expected.length &&
      expected.every((e, i) => partialMatch(actual[i], e))
    );
  }
  if (!actual || typeof actual !== "object") return false;
  return Object.entries(expected as Record<string, unknown>).every(([k, v]) =>
    partialMatch((actual as Record<string, unknown>)[k], v),
  );
}

const isPlainObject = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === "object" && !Array.isArray(v);

/** Deep merge (objects merged, arrays and scalars replaced, `undefined` deletes). Returns a new value. */
export function deepMerge<T>(base: T, patch: unknown): T {
  if (!isPlainObject(base) || !isPlainObject(patch)) {
    return (patch === undefined ? base : structuredClone(patch)) as T;
  }
  const out: Record<string, unknown> = structuredClone(base) as Record<
    string,
    unknown
  >;
  for (const [k, v] of Object.entries(patch)) {
    if (v === undefined) delete out[k];
    else
      out[k] =
        isPlainObject(v) && isPlainObject(out[k])
          ? deepMerge(out[k], v)
          : structuredClone(v);
  }
  return out as T;
}

/** "/payments/:paymentId/client" -> /^\/payments\/([^/]+)\/client$/ */
export function pathPatternToRegExp(pattern: string): RegExp {
  const escaped = pattern
    .split("/")
    .map((seg) => {
      if (seg.startsWith(":")) return "[^/]+";
      if (seg === "**") return ".*";
      return seg.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, "[^/]*");
    })
    .join("/");
  return new RegExp(`^${escaped}/?$`);
}

/** Playwright-style URL glob ("**" any chars, "*" any chars except "/"). */
export function globToRegExp(glob: string): RegExp {
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        re += ".*";
        i++;
      } else re += "[^/]*";
    } else if (c === "?") re += "\\?";
    else re += c.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp(`^${re}$`);
}

export const slugify = (s: string): string =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80) || "test";
