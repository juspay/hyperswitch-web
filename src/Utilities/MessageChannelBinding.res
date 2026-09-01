/* minimal DOM bindings for the MessageChannel Card Relay. One MessageChannel per field
   mount per portEpoch: `port2` rides WITH the field's mount-config transfer, `port1` is
   retained by the group and forwarded into the hidden coordinator after its `iframeMounted`.
   The raw half of every field update travels on these ports, never the merchant window. */
type port

type channel = {
  port1: port,
  port2: port,
}

@new external makeChannel: unit => channel = "MessageChannel"

// ports carry structured-clone JSON, not the stringified frames of the legacy window plane.
@send external portPostMessage: (port, JSON.t) => unit = "postMessage"
@set external onPortMessage: (port, Window.event => unit) => unit = "onmessage"
@send external portClose: port => unit = "close"

// populated by the browser when the sender passed a transfer list; empty otherwise.
@get external eventPorts: Window.event => array<port> = "ports"
