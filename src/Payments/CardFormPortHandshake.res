// Sets up the ports between a card form's field iframes and its coordinator
// iframe without the merchant page in the path.
//
// Raw card values travel from each field to the coordinator over a MessagePort,
// so whoever hands out the ports can read them. Script on the merchant page must
// not be able to, so the coordinator creates each channel itself and passes the
// field its end directly, frame to frame. Both sides accept these messages only
// from a sibling frame on the SDK's own origin, which merchant-page script cannot
// send from.
open Utils

let portKey = (~groupId: string, ~fieldName: string): string => `${groupId}:${fieldName}`

let fieldHelloKey = "cardFormFieldHello"
let fieldPortKey = "cardFormFieldPort"
let coordinatorReadyKey = "cardFormCoordinatorReady"

@send external postToFrame: (Types.window, JSON.t, string) => unit = "postMessage"
@send
external postToFrameWithPorts: (
  Types.window,
  JSON.t,
  string,
  array<MessageChannelBinding.port>,
) => unit = "postMessage"
external sourceFrame: Dom.element => Types.window = "%identity"

// Epochs only need to differ from the port they replace. One counter for the
// whole frame keeps that true even if a hook below runs again.
let lastEpoch = ref(0)
let nextEpoch = () => {
  lastEpoch := lastEpoch.contents + 1
  lastEpoch.contents
}

let makeInstanceId = () => `${Date.now()->Float.toString}-${Math.random()->Float.toString}`

// The other frames embedded by this iframe's parent. Reading them needs no
// access to the parent document, so the merchant page cannot intercept it.
let siblingFrames = (): array<Types.window> => {
  let frames = Window.parent->Window.frames
  Array.fromInitializer(~length=frames->Window.framesLength, index =>
    frames->Window.frameAt(index)
  )->Array.filter(frame => frame !== Window.window)
}

let isFromSdkSibling = (ev: Window.event): bool =>
  PaymentMessageSecurity.isConcreteOrigin(ev.origin) &&
  ev.origin === Window.Location.origin &&
  siblingFrames()->Array.some(frame => frame === ev.source->sourceFrame)

let postToSdkFrame = (frame: Types.window, message: JSON.t) =>
  try frame->postToFrame(message, Window.Location.origin) catch {
  | _ => ()
  }

let eventDict = (ev: Window.event) => ev.data->Identity.anyTypeToJson->getDictFromJson

// Field side: asks the coordinator of its card form for a port, and takes one
// only from a sibling SDK frame. Asks again when a coordinator it has no port
// from announces itself, e.g. one that started listening after the first ask.
let useFieldPort = (~groupId: string, ~fieldName: string) => React.useEffect(() => {
    if groupId === "" || fieldName === "" {
      None
    } else {
      let hello =
        [
          (fieldHelloKey, true->JSON.Encode.bool),
          ("groupId", groupId->JSON.Encode.string),
          ("fieldName", fieldName->JSON.Encode.string),
          ("fieldInstanceId", makeInstanceId()->JSON.Encode.string),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      let portCoordinatorId = ref("")
      let cleanup = handleMessage((ev: Window.event) => {
        if isFromSdkSibling(ev) {
          let dict = ev->eventDict
          let coordinatorId = dict->getString("coordinatorId", "")
          if dict->getString("groupId", "") === groupId {
            if dict->getBool(coordinatorReadyKey, false) {
              if coordinatorId !== portCoordinatorId.contents {
                ev.source->sourceFrame->postToSdkFrame(hello)
              }
            } else if (
              dict->getBool(fieldPortKey, false) && dict->getString("fieldName", "") === fieldName
            ) {
              ev
              ->MessageChannelBinding.eventPorts
              ->Array.get(0)
              ->Option.forEach(
                port => {
                  portCoordinatorId := coordinatorId
                  SadPortRegistry.installPort(
                    ~key=portKey(~groupId, ~fieldName),
                    ~epoch=nextEpoch(),
                    ~port,
                  )
                },
              )
            }
          }
        }
      }, "")
      siblingFrames()->Array.forEach(frame => frame->postToSdkFrame(hello))
      cleanup
    }
  }, (groupId, fieldName))

// Coordinator side: opens a channel for each field of its card form that asks,
// keeps one end, and sends the other straight back to the asking frame. A field
// that asks twice before its port arrives gets one port, not two.
let useCoordinatorPorts = (~groupId: string) => React.useEffect(() => {
    if groupId === "" {
      None
    } else {
      let coordinatorId = makeInstanceId()
      let servedFieldInstances = Dict.make()
      let cleanup = handleMessage((ev: Window.event) => {
        if isFromSdkSibling(ev) {
          let dict = ev->eventDict
          let fieldName =
            dict->getString("fieldName", "")->CardFormShared.mapFieldTypeToInternalFieldName
          let fieldInstanceId = dict->getString("fieldInstanceId", "")
          if (
            dict->getBool(fieldHelloKey, false) &&
            dict->getString("groupId", "") === groupId &&
            fieldName !== "" &&
            servedFieldInstances->Dict.get(fieldName) !== Some(fieldInstanceId)
          ) {
            servedFieldInstances->Dict.set(fieldName, fieldInstanceId)
            let channel = MessageChannelBinding.makeChannel()
            SadPortRegistry.installPort(
              ~key=portKey(~groupId, ~fieldName),
              ~epoch=nextEpoch(),
              ~port=channel.port1,
            )
            let portMessage =
              [
                (fieldPortKey, true->JSON.Encode.bool),
                ("groupId", groupId->JSON.Encode.string),
                ("fieldName", fieldName->JSON.Encode.string),
                ("coordinatorId", coordinatorId->JSON.Encode.string),
              ]
              ->Dict.fromArray
              ->JSON.Encode.object
            try {
              ev.source
              ->sourceFrame
              ->postToFrameWithPorts(portMessage, Window.Location.origin, [channel.port2])
            } catch {
            | _ => ()
            }
          }
        }
      }, "")
      let ready =
        [
          (coordinatorReadyKey, true->JSON.Encode.bool),
          ("groupId", groupId->JSON.Encode.string),
          ("coordinatorId", coordinatorId->JSON.Encode.string),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      siblingFrames()->Array.forEach(frame => frame->postToSdkFrame(ready))
      cleanup
    }
  }, [groupId])

// A field can start emitting before its port arrives, since the field and the
// coordinator load independently. Keeps the latest frame and resends it whenever
// the field's port is (re)installed.
let useFieldStatePoster = (~portKey: string): (JSON.t => unit) => {
  let latestFrameRef = React.useRef(None)
  React.useEffect(() => {
    if portKey === "" {
      None
    } else {
      let resend = () =>
        latestFrameRef.current->Option.forEach(frame =>
          SadPortRegistry.postFrame(~key=portKey, frame)->ignore
        )
      SadPortRegistry.addChangeListener(resend)
      Some(() => SadPortRegistry.removeChangeListener(resend))
    }
  }, [portKey])
  frame => {
    latestFrameRef.current = Some(frame)
    SadPortRegistry.postFrame(~key=portKey, frame)->ignore
  }
}
