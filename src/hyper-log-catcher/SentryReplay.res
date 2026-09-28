/*
 Session Replay, isolated so it can be `import()`ed: `replayIntegration` drags rrweb in
 (~40 KB gzip) and nothing in the payment form needs it to paint, so it lands in an async
 chunk instead of app.js.

 Deferring is about *when* Replay loads, never *whether*: `replaysOnErrorSampleRate` is 1.0,
 so most sessions run Replay in buffer mode, and that rolling buffer is kept by the integration
 itself - a session that never loads it has no buffer to flush and its errors carry no replay.
 */
type client
type integration

@module("@sentry/react")
external replayIntegration: unit => integration = "replayIntegration"

@send external addIntegration: (client, integration) => unit = "addIntegration"

let addTo = (client: client) => client->addIntegration(replayIntegration())
