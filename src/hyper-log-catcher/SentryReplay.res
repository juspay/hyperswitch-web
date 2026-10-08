type client
type integration

@module("@sentry/react")
external replayIntegration: unit => integration = "replayIntegration"

@send external addIntegration: (client, integration) => unit = "addIntegration"

let addTo = (client: client) => client->addIntegration(replayIntegration())
