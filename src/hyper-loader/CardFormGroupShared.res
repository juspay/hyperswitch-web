open Utils

let randomIdSuffix = (): string => Math.random()->Float.toString->String.slice(~start=2, ~end=8)

let uniqueId = (~prefix: string): string =>
  `${prefix}-${Date.now()->Float.toString}-${randomIdSuffix()}`

let eventDataJson = (ev: Types.event): JSON.t =>
  try ev.data->Identity.anyTypeToJson catch {
  | _ => JSON.Encode.null
  }

let isFromIframe = (~ev: Types.event, ~iframe: option<Dom.element>, ~origin: string): bool =>
  iframe
  ->Option.map(iframe => ev.source === iframe->Window.contentWindow && ev.origin === origin)
  ->Option.getOr(false)

type coordinatorChannel = {
  groupId: string,
  mountRef: ref<option<CoordinatorMount.coordinatorMount>>,
  readyRef: ref<bool>,
  pendingPortsRef: ref<array<CoordinatorMount.pendingPort>>,
  pendingCommandsRef: ref<array<array<(string, JSON.t)>>>,
  installedPortKeysRef: ref<array<string>>,
  portEpochCounterRef: ref<int>,
}

let makeCoordinatorChannel = (~groupId: string): coordinatorChannel => {
  groupId,
  mountRef: ref(None),
  readyRef: ref(false),
  pendingPortsRef: ref([]),
  pendingCommandsRef: ref([]),
  installedPortKeysRef: ref([]),
  portEpochCounterRef: ref(0),
}

let postToCoordinator = (
  mount: CoordinatorMount.coordinatorMount,
  fields: array<(string, JSON.t)>,
) =>
  try mount.iframe->Nullable.make->Window.iframePostMessage(fields->Dict.fromArray) catch {
  | _ => ()
  }

let postCoordinatorCommand = (channel: coordinatorChannel, fields: array<(string, JSON.t)>) =>
  switch (channel.mountRef.contents, channel.readyRef.contents) {
  | (Some(mount), true) => postToCoordinator(mount, fields)
  | _ => channel.pendingCommandsRef := channel.pendingCommandsRef.contents->Array.concat([fields])
  }

let flushPendingCoordinatorCommands = (channel: coordinatorChannel) =>
  switch (channel.mountRef.contents, channel.readyRef.contents) {
  | (Some(mount), true) =>
    let queuedCommands = channel.pendingCommandsRef.contents
    channel.pendingCommandsRef := []
    queuedCommands->Array.forEach(fields => postToCoordinator(mount, fields))
  | _ => ()
  }

let flushPendingPorts = (channel: coordinatorChannel) =>
  switch (channel.mountRef.contents, channel.readyRef.contents) {
  | (Some(mount), true) =>
    channel.pendingPortsRef.contents->Array.forEach(({fieldName, epoch, port}) =>
      CoordinatorMount.forwardPortToCoordinator(
        ~coordinatorIframe=mount.iframe->Nullable.make,
        ~groupId=channel.groupId,
        ~fieldName,
        ~portEpoch=epoch,
        ~port,
      )
    )
    channel.pendingPortsRef := []
  | _ => ()
  }

let openFieldPort = (
  channel: coordinatorChannel,
  ~fieldIframe: Nullable.t<Dom.element>,
  ~mountConfig: JSON.t,
  ~fieldName: string,
): unit => {
  channel.portEpochCounterRef := channel.portEpochCounterRef.contents + 1
  let epoch = channel.portEpochCounterRef.contents
  let messageChannel = MessageChannelBinding.makeChannel()
  let portKey = CardFormCoordinator.portKey(~groupId=channel.groupId, ~fieldName)
  channel.installedPortKeysRef :=
    channel.installedPortKeysRef.contents->Array.concat([portKey])
  CoordinatorMount.postFieldMountConfigWithPort(
    ~fieldIframe,
    ~mountConfig,
    ~portKey,
    ~portEpoch=epoch,
    ~port=messageChannel.port2,
  )
  channel.pendingPortsRef :=
    channel.pendingPortsRef.contents->Array.concat([
      {fieldName, epoch, port: messageChannel.port1},
    ])
  flushPendingPorts(channel)
}

// Merges a field's `create()` subscriptionEvents into the group-level union.
// Returns true when the union actually grew, so the caller can re-post the
// coordinator's options for fields created after the coordinator was configured.
let mergeSubscriptionEvents = (
  ~subscriptionEventsRef: ref<array<string>>,
  ~fieldOptions: JSON.t,
): bool => {
  let incoming =
    fieldOptions
    ->getDictFromJson
    ->Dict.get("subscriptionEvents")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.getOr([])
    ->Array.filterMap(JSON.Decode.string)
  let merged = incoming->Array.reduce(subscriptionEventsRef.contents, (acc, event) =>
    acc->Array.includes(event) ? acc : acc->Array.concat([event])
  )
  if merged->Array.length > subscriptionEventsRef.contents->Array.length {
    subscriptionEventsRef := merged
    true
  } else {
    false
  }
}

let closeInstalledPorts = (channel: coordinatorChannel): unit => {
  channel.installedPortKeysRef.contents->Array.forEach(key => SadPortRegistry.closePort(~key))
  channel.installedPortKeysRef := []
}

let resolveFieldAppearance = (
  ~fieldOptionsDict: Dict.t<JSON.t>,
  ~groupAppearance: JSON.t,
): JSON.t => {
  let fieldAppearance =
    fieldOptionsDict->Dict.get("appearance")->Option.getOr(Dict.make()->JSON.Encode.object)
  if (
    fieldAppearance
    ->JSON.Decode.object
    ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
    ->Option.getOr(false)
  ) {
    fieldAppearance
  } else {
    groupAppearance
  }
}

let optionsWithAppearance = (~fieldOptionsDict: Dict.t<JSON.t>, ~appearance: JSON.t): JSON.t => {
  let merged = fieldOptionsDict->Dict.copy
  merged->Dict.set("appearance", appearance)
  merged->JSON.Encode.object
}

let buildPaymentOptions = (
  ~appearance: JSON.t,
  ~locale: string,
  ~credentialKeys: array<(string, JSON.t)>,
): JSON.t =>
  [
    ("appearance", appearance),
    ("fonts", []->JSON.Encode.array),
    ("locale", locale->JSON.Encode.string),
  ]
  ->Array.concat(credentialKeys)
  ->Dict.fromArray
  ->JSON.Encode.object

let buildFieldMountConfig = (
  ~paymentOptions: JSON.t,
  ~options: JSON.t,
  ~fieldId: string,
  ~publishableKey: string,
  ~credentialKeys: array<(string, JSON.t)>,
  ~sdkSessionId: string,
  ~loggerSource: string,
  ~savedCardBrand: string,
  ~tailKeys: array<(string, JSON.t)>=[],
): Dict.t<JSON.t> => {
  let redirectionFlagsDict =
    [
      ("shouldUseTopRedirection", JSON.Encode.bool(false)),
      ("shouldRemoveBeforeUnloadEvents", JSON.Encode.bool(false)),
    ]->Dict.fromArray
  [
    ("paymentElementCreate", true->JSON.Encode.bool),
    ("otherElements", false->JSON.Encode.bool),
    ("componentType", "payment"->JSON.Encode.string),
    ("paymentOptions", paymentOptions),
    ("options", options),
    ("iframeId", fieldId->JSON.Encode.string),
    ("publishableKey", publishableKey->JSON.Encode.string),
  ]
  ->Array.concat(credentialKeys)
  ->Array.concat([
    ("sdkSessionId", sdkSessionId->JSON.Encode.string),
    ("customPodUri", ""->JSON.Encode.string),
    ("parentURL", "*"->JSON.Encode.string),
    ("sdkHandleOneClickConfirmPayment", false->JSON.Encode.bool),
    ("launchTime", Date.now()->JSON.Encode.float),
    ("loggerSource", loggerSource->JSON.Encode.string),
    ("isSavedCardCvcFlow", false->JSON.Encode.bool),
    ("savedCardBrand", savedCardBrand->JSON.Encode.string),
    ("cardCollectionMode", "tokenise"->JSON.Encode.string),
    ("isBancontactCardFlow", false->JSON.Encode.bool),
    ("cardFlowType", "payment"->JSON.Encode.string),
    ("isTestMode", false->JSON.Encode.bool),
    ("customBackendUrl", ""->JSON.Encode.string),
    ("paymentId", ""->JSON.Encode.string),
    ("blockConfirm", false->JSON.Encode.bool),
    ("analyticsMetadata", Dict.make()->JSON.Encode.object),
    ("redirectionFlags", redirectionFlagsDict->JSON.Encode.object),
  ])
  ->Array.concat(tailKeys)
  ->Dict.fromArray
}

let savedCardNetwork = (savedCardDict: Dict.t<JSON.t>): string =>
  savedCardDict
  ->getDictFromDict("paymentMethodData")
  ->getDictFromDict("card")
  ->getString("cardNetwork", "")

let postFieldUpdate = (
  ~iframeRef: ref<Nullable.t<Dom.element>>,
  ~newOptions: JSON.t,
): Dict.t<JSON.t> => {
  iframeRef.contents->Window.iframePostMessage(
    [
      ("paymentElementsUpdate", true->JSON.Encode.bool),
      ("options", newOptions),
    ]->Dict.fromArray,
  )
  let savedCardDict = newOptions->getDictFromJson->getDictFromDict("savedCard")
  let brand = savedCardDict->savedCardNetwork
  if brand !== "" {
    iframeRef.contents->Window.iframePostMessage(
      [("savedCardBrand", brand->JSON.Encode.string)]->Dict.fromArray,
    )
  }
  savedCardDict
}

let makeFieldElementAndHandle = (
  ~optionsForElement: JSON.t,
  ~appearance: JSON.t,
  ~iframeRef: ref<Nullable.t<Dom.element>>,
  ~mountPostMessage,
  ~sdkDomainUrl: string,
  ~surfaceFamily: string,
  ~fieldName: string,
  ~groupId: string,
  ~listenerName: string,
  ~eventHandlersRef: ref<Dict.t<JSON.t => unit>>,
  ~update: JSON.t => unit,
): Types.fieldHandle => {
  let element = LoaderPaymentElement.make(
    "paymentMethodsSDK",
    optionsForElement,
    ref => iframeRef := ref,
    [],
    mountPostMessage,
    ~appearance,
    ~redirectionFlags=JotaiAtoms.defaultRedirectionFlags,
    ~sdkDomainUrl,
    ~logger=None,
    ~confirmPayment=_json => Promise.resolve(JSON.Encode.null),
    ~fieldName,
    ~surfaceFamily,
    ~groupId,
  )
  let postToOwnIframe = fields =>
    iframeRef.contents->Window.iframePostMessage(fields->Dict.fromArray)
  {
    mount: selector => element.mount(selector),
    unmount: () => element.unmount(),
    destroy: () => {
      element.destroy()
      iframeRef := Nullable.null
      EventListenerManager.removeSmartEventListener("message", listenerName)
    },
    update,
    focus: () => postToOwnIframe([("doFocus", true->JSON.Encode.bool)]),
    blur: () => postToOwnIframe([("doBlur", true->JSON.Encode.bool)]),
    clear: () => postToOwnIframe([("doClearValues", true->JSON.Encode.bool)]),
    on: (event, cb) => eventHandlersRef.contents->Dict.set(event, cb),
  }
}

let registerField = (
  ~fields: ref<JSON.t>,
  ~fieldId: string,
  ~fieldType: string,
  ~extraMeta: array<(string, JSON.t)>=[],
): unit => {
  let fieldsDict = fields.contents->getDictFromJson
  let fieldMeta =
    [
      ("id", fieldId->JSON.Encode.string),
      ("type", fieldType->JSON.Encode.string),
    ]
    ->Array.concat(extraMeta)
    ->Dict.fromArray
    ->JSON.Encode.object
  fieldsDict->Dict.set(fieldId, fieldMeta)
  fields := fieldsDict->JSON.Encode.object
}
