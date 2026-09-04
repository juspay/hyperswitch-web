type port

type channel = {
  port1: port,
  port2: port,
}

@new external makeChannel: unit => channel = "MessageChannel"

@send external portPostMessage: (port, JSON.t) => unit = "postMessage"
@set external onPortMessage: (port, Window.event => unit) => unit = "onmessage"
@send external portClose: port => unit = "close"

@get external eventPorts: Window.event => array<port> = "ports"
