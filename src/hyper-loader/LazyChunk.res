/*
 One cell per async chunk the loader imports, holding that chunk's load state and failure
 policy for the whole page.

 Two things have to be true at once, and the obvious implementations of each break the other.

 A failed load must not be cached - caching the rejected promise made one transient failure
 permanent for the life of the page. But clearing the cache alone makes every later call fire a
 fresh chunk request and a fresh Sentry event, which during a CDN/CSP incident multiplies into
 unbounded `<script>` injections and Sentry volume on every merchant page at once.

 So recovery is bounded: at most one attempt in flight, a widening cooldown between attempts,
 and one Sentry report per page instead of one per call.

 `load` never rejects. `None` means "the chunk is not here", the only thing a caller can act
 on, and no caller can leak an unhandled rejection into the merchant's page by dropping the
 promise.
 */
type t<'a> = {
  label: string,
  /* cleared on failure so a later call can retry */
  mutable cached: option<promise<option<'a>>>,
  mutable failures: int,
  mutable retryNotBefore: float,
  /* one Sentry event per page for this chunk */
  mutable hasReported: bool,
}

let make = (~label: string) => {
  label,
  cached: None,
  failures: 0,
  retryNotBefore: 0.,
  hasReported: false,
}

/* 1s, 2s, 4s, 8s, 16s, then 30s for every further consecutive failure */
let cooldownMs = failures =>
  switch failures {
  | 1 => 1000.
  | 2 => 2000.
  | 3 => 4000.
  | 4 => 8000.
  | 5 => 16000.
  | _ => 30000.
  }

let report = (t, err) =>
  try {
    Console.error2(`[${t.label}] chunk load failed`, err)
    if !t.hasReported {
      t.hasReported = true
      Sentry.captureException(err)
    }
  } catch {
  | _ => ()
  }

let load = (t: t<'a>, importChunk: unit => promise<'a>): promise<option<'a>> =>
  switch t.cached {
  | Some(chunkPromise) => chunkPromise
  | None =>
    if Date.now() < t.retryNotBefore {
      Promise.resolve(None)
    } else {
      let chunkPromise =
        importChunk()
        ->Promise.thenResolve(value => {
          t.failures = 0
          Some(value)
        })
        ->Promise.catch(err => {
          t.cached = None
          t.failures = t.failures + 1
          t.retryNotBefore = Date.now() +. cooldownMs(t.failures)
          t->report(err)
          Promise.resolve(None)
        })
      t.cached = Some(chunkPromise)
      chunkPromise
    }
  }
