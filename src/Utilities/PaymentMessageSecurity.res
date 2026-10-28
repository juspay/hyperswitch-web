// A window identity alone survives navigation; always authenticate its origin too.
let isConcreteOrigin = origin => origin !== "" && origin !== "*" && origin !== "null"

let isExpectedSender = (~source, ~origin, ~eventSource, ~eventOrigin) =>
  isConcreteOrigin(origin) && eventSource === source && eventOrigin === origin

@get external sourceTop: Dom.element => Dom.element = "top"

// Same-origin descendants share the merchant's principal. A popup does not
// belong to its frame tree, even if it has the same origin.
let isSameOriginDescendant = (~window, ~origin, ~eventSource, ~eventOrigin) => {
  try {
    isConcreteOrigin(origin) && eventOrigin === origin && sourceTop(eventSource) === window
  } catch {
  | _ => false
  }
}

type queryParams
@send external getAll: (queryParams, string) => array<string> = "getAll"
@send external forEachParam: (queryParams, (string, string) => unit) => unit = "forEach"

type redirectUrl = {
  href: string,
  origin: string,
  host: string,
  pathname: string,
  protocol: string,
  username: string,
  password: string,
  hash: string,
  searchParams: queryParams,
}
@new external parseUrl: string => redirectUrl = "URL"

let httpUrl = url => {
  try {
    let parsed = parseUrl(url)
    if (
      (parsed.protocol === "https:" || parsed.protocol === "http:") &&
      parsed.username === "" &&
      parsed.password === ""
    ) {
      Some(parsed)
    } else {
      None
    }
  } catch {
  | _ => None
  }
}

let originOf = url => httpUrl(url)->Option.map(url => url.origin)

// Script-executing and local-content schemes are never a payment return destination.
let blockedReturnProtocols = ["javascript:", "data:", "vbscript:", "blob:", "file:"]

// Merchants may return to app deep links (custom schemes), so only executable
// and local-content schemes are refused here.
let returnDestinationUrl = url => {
  try {
    let parsed = parseUrl(url)
    blockedReturnProtocols->Array.includes(parsed.protocol) ? None : Some(parsed)
  } catch {
  | _ => None
  }
}

// Confirmation adds status/payment query parameters, but must not change the
// merchant's configured destination or introduce an executable URL scheme.
let isReturnDestination = (~url, ~returnUrl) =>
  switch (returnDestinationUrl(url), returnDestinationUrl(returnUrl)) {
  | (Some(actual), Some(expected)) =>
    let valid = ref(true)
    let checkParam = (_, key) => {
      if !(["payment_id", "status", "payment_intent_client_secret"]->Array.includes(key)) {
        if (
          actual.searchParams->getAll(key)->JSON.stringifyAny !==
            expected.searchParams->getAll(key)->JSON.stringifyAny
        ) {
          valid := false
        }
      }
    }
    actual.searchParams->forEachParam(checkParam)
    expected.searchParams->forEachParam(checkParam)
    actual.protocol === expected.protocol &&
    actual.username === expected.username &&
    actual.password === expected.password &&
    actual.host === expected.host &&
    actual.pathname === expected.pathname &&
    actual.hash === expected.hash &&
    valid.contents
  | _ => false
  }
