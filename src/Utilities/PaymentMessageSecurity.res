// A window identity alone survives navigation; always authenticate its origin too.
let isConcreteOrigin = origin => origin !== "" && origin !== "*" && origin !== "null"

let isExpectedSender = (~source, ~origin, ~eventSource, ~eventOrigin) =>
  isConcreteOrigin(origin) && eventSource === source && eventOrigin === origin

type queryParams
@send external getAll: (queryParams, string) => array<string> = "getAll"
@send external forEachParam: (queryParams, (string, string) => unit) => unit = "forEach"

type redirectUrl = {
  href: string,
  origin: string,
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

// Confirmation adds status/payment query parameters, but must not change the
// merchant's configured destination or introduce an executable URL scheme.
let isReturnDestination = (~url, ~returnUrl) =>
  switch (httpUrl(url), httpUrl(returnUrl)) {
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
    actual.origin === expected.origin &&
    actual.pathname === expected.pathname &&
    actual.hash === expected.hash &&
    valid.contents
  | _ => false
  }
