type controller = {
  abort: unit => unit,
  signal: unit,
}

@new external make: unit => controller = "AbortController"
