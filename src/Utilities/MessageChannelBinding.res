// MessageChannelBinding — minimal DOM bindings for the MessageChannel Card
// Relay.
//
// One `MessageChannel` is created per field mount per portEpoch. `port2`
// rides WITH the field's mount-config message (postMessage transfer); `port1`
// is retained by the CardForm group and forwarded into the hidden
// `cardFormCoordinator` iframe after its `iframeMounted`. The SAD/raw half of
// every field update then travels on these ports instead of the merchant
// window — see CardFormPortProtocol.res and SadPortRegistry.res.
type port

type channel = {
  port1: port,
  port2: port,
}

@new external makeChannel: unit => channel = "MessageChannel"

// Ports carry structured-clone JSON (NOT the stringified-frame convention of
// the legacy window plane — the port plane is new, so it gets typed JSON).
@send external portPostMessage: (port, JSON.t) => unit = "postMessage"
@set external onPortMessage: (port, Window.event => unit) => unit = "onmessage"
@send external portClose: port => unit = "close"

// MessageEvent.ports — populated by the browser when the sender passed a
// transfer list. Always an array (empty when no transfer occurred).
@get external eventPorts: Window.event => array<port> = "ports"
