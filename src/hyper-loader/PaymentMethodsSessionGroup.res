/* Factory behind `hyper.paymentMethodsSession(options)` — the vault CardForm group.
   Confirms are relay-only: the group posts a content-free `cardFormCoordinatorCommand`
   into the hidden coordinator iframe and settles on its masked `confirmResult`. Raw card
   data never crosses the merchant window plane — it rides the MessageChannel port plane only. */

open Utils

/* port1 queued until the coordinator iframe mounts and flushes it. Shape lives in
   `CoordinatorMount` so its teardown can close ports that were never transferred. */
type pendingPort = CoordinatorMount.pendingPort

/* aliased rather than `open Types`, which would shadow the global `None` needed by
   optional labeled args such as `~optLogger=None`. */
type paymentMethodsSessionGroup = Types.paymentMethodsSessionGroup
type fieldHandle = Types.fieldHandle
type cardForm = Types.cardForm

// Active → Consumed on a successful confirm, → Deinitialized on `deinit()`; a non-Active session refuses further confirms.
type sessionState =
  | Active
  | Consumed
  | Deinitialized

type errorType = CardFormCoordinator.errorType

let defaultErrorMessage = CardFormCoordinator.defaultErrorMessage
let resolveErrorMessage = CardFormCoordinator.resolveErrorMessage

let makeErrorResult = (
  ~code: string,
  ~message: option<string>=?,
  ~locale: string="en",
  ~typeOverride: option<errorType>=?,
  (),
): JSON.t => {
  CardFormCoordinator.makeErrorResult(~code, ~message?, ~locale, ~typeOverride?, ())
}
let sessionExpiredResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="session_expired", ~locale, ())

let sessionConsumedResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="session_consumed", ~locale, ())

let confirmInFlightResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="confirm_in_progress", ~locale, ())

type flowASuccessPayload = CardFormCoordinator.flowASuccessPayload
type flowBSuccessPayload = CardFormCoordinator.flowBSuccessPayload
type failurePayload = CardFormCoordinator.failurePayload
type confirmOutcome = CardFormCoordinator.confirmOutcome

let buildConfirmResult = CardFormCoordinator.buildConfirmResult

/* The synthetic session intentionally lacks `expires_at`: the BACKEND
   sessions payload is the sole expiry source; a merchant-supplied value must
   not seed the staleness gate. */
let buildSyntheticSession = (
  ~pmSessionId: string,
  ~customerId: string,
  ~vaultType: string,
  ~vaultData: JSON.t,
): JSON.t => {
  let vaultDetailsDict = Dict.make()
  vaultDetailsDict->Dict.set("vault_type", vaultType->JSON.Encode.string)
  vaultDetailsDict->Dict.set("vault_data", vaultData)
  let sessionDict = Dict.make()
  sessionDict->Dict.set("payment_method_session_id", pmSessionId->JSON.Encode.string)
  sessionDict->Dict.set("customer_id", customerId->JSON.Encode.string)
  sessionDict->Dict.set("vault_details", vaultDetailsDict->JSON.Encode.object)
  sessionDict->Dict.set("associated_payment_methods", []->JSON.Encode.array)
  sessionDict->JSON.Encode.object
}

/* 0.0 means missing or unparseable — treated as unknown, NOT expired. We only flag
   `session_expired` when we positively know now >= expiresAt. */
let parseExpiresAtMs = (expiresAtStr: string): float => {
  if expiresAtStr->String.length == 0 {
    0.0
  } else {
    try {
      Date.fromString(expiresAtStr)->Date.getTime
    } catch {
    | _ => 0.0
    }
  }
}

let isExpired = (~expiresAtMs: float): bool =>
  expiresAtMs > 0.0 && Date.now() >= expiresAtMs

// confirm settlement rides `coordinatorConfirmPendingRef` alone; no window-relay resolver.
type fieldEntry = {
  iframeRef: ref<Nullable.t<Dom.element>>,
  handle: fieldHandle,
  fieldType: string,
  savedCardBrandRef: ref<string>,
  savedCardLast4Ref: ref<string>,
  /* no raw caches here: the window-plane `cardStateUpdate` carries the SPLIT payload (no
     raw keys); full snapshots reach the coordinator on the port plane only.
     auto-focus advances only on the false→true edge of the iframe-emitted `focusReady`.
     Do NOT key this off `fieldStatus.complete` — that fires on valid + non-empty without
     brand-aware length and Luhn gating, so a Visa would advance at 14 digits, not 16. */
  prevFocusReadyRef: ref<bool>,
}

let reshapeCardStateUpdateToChangePayload = CardFormShared.reshapeCardStateUpdateToChangePayload

let nextFieldFor = CardFormShared.nextFieldFor

/* VGS aliases are format-preserving (`4111xxxxxxxx1111`) — only the leading prefix is a
   real BIN. `CardValidations.getAllMatchedCardSchemes` regex-matches issuer prefixes
   WITHOUT stripping non-digits; `Validation.getCardBrand` and `CardUtils.getCardBrand`
   strip first, so `6521xxxxxxxx9999` collapses to `65219999` and their BIN check reads the
   fabricated prefix `652199` — RuPay for a Discover card. Co-badged prefixes match several
   issuers, so the winner is resolved against this surface's published brand vocabulary. */
let aliasBrandVocabulary = [
  ("Visa", "visa"),
  ("Mastercard", "mastercard"),
  ("AmericanExpress", "amex"),
  ("Discover", "discover"),
  ("JCB", "jcb"),
  ("DinersClub", "diners club"),
  ("UnionPay", "unionpay"),
]

let detectBrandFromAlias = (alias: string): string =>
  alias
  ->String.trim
  ->CardValidations.getAllMatchedCardSchemes
  ->Array.findMap(issuer =>
    aliasBrandVocabulary
    ->Array.find(((patternIssuer, _)) => patternIssuer == issuer)
    ->Option.map(((_, merchantBrand)) => merchantBrand)
  )
  ->Option.getOr("")

// backstop: without it a dropped resolution leaves the `confirm()` promise pending forever.
let confirmSettleTimeoutMs = 8000

let make = (options: JSON.t): paymentMethodsSessionGroup => {
  let optionsDict = options->getDictFromJson

  let sdkAuthorizationRaw = optionsDict->getString("sdkAuthorization", "")
  let sdkAuth = sdkAuthorizationRaw->getSdkAuthorizationData
  let publishableKey = sdkAuth.publishableKey->Option.getOr("")
  let pmSessionId = sdkAuth.pmSessionId->Option.getOr("")
  let customerId = sdkAuth.customerId->Option.getOr("")

  let locale = optionsDict->getString("locale", "auto")

  let sessionsDataRef: ref<JSON.t> = ref(JSON.Encode.null)
  let vaultCredentialsRef: ref<JSON.t> = ref(JSON.Encode.null)
  let sessionStateRef: ref<sessionState> = ref(Active)
  let confirmingRef: ref<bool> = ref(false)
  let expiresAtRef: ref<float> = ref(0.0)
  let eventCallbacksRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())

  let vgsBrokerRef: ref<option<VGSVaultBroker.vgsBrokerHandle>> = ref(None)

  // VGS builds no fieldEntry, so savedCard hints are captured here for the Flow B union.
  let vgsSavedCardBrandRef: ref<string> = ref("")
  let vgsSavedCardLast4Ref: ref<string> = ref("")

  // pushed to the cardCvc iframe once per brand CHANGE, not per keystroke.
  let lastDetectedBrandRef: ref<string> = ref("")

  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  let fields: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)

  /* the hidden coordinator owns the vault confirm: masked commands in, masked `confirmResult`
     back, raw SAD on the per-field ports. `groupInstanceId` is its selector and the `groupId`
     URL param. VGS-only groups never mount a coordinator. */
  let groupInstanceId = `vault-${pmSessionId}-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
  let portEpochCounterRef: ref<int> = ref(0)
  let pendingPortsRef: ref<array<pendingPort>> = ref([])
  let installedPortKeysRef: ref<array<string>> = ref([])
  let coordinatorMountRef: ref<option<CoordinatorMount.coordinatorMount>> = ref(None)
  let coordinatorReadyRef: ref<bool> = ref(false)
  let coordinatorListenerName = `onVaultCoordinator-${groupInstanceId}`
  let coordinatorConfirmPendingRef: ref<option<(string, JSON.t => unit)>> = ref(None)

  let syncCoordinatorSessions = () => {
    if sessionsDataRef.contents != JSON.Encode.null && coordinatorReadyRef.contents {
      coordinatorMountRef.contents->Option.forEach(mount =>
        mount.iframe->Nullable.make->Window.iframePostMessage(
          [("sessions", sessionsDataRef.contents)]->Dict.fromArray,
        )
      )
    }
  }

  let flushPendingPorts = () => {
    switch (coordinatorMountRef.contents, coordinatorReadyRef.contents) {
    | (Some(mount), true) =>
      pendingPortsRef.contents->Array.forEach(({fieldName, epoch, port}) => {
        CoordinatorMount.forwardPortToCoordinator(
          ~coordinatorIframe=mount.iframe->Nullable.make,
          ~groupId=groupInstanceId,
          ~fieldName,
          ~portEpoch=epoch,
          ~port,
        )
      })
      pendingPortsRef := []
    | _ => ()
    }
  }

  let attachCoordinatorListener = () => {
    let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.vaultSdkDomainUrl).origin
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        let isOurCoordinator =
          coordinatorMountRef.contents
          ->Option.map(coordinatorMount =>
            ev.source === coordinatorMount.iframe->Window.contentWindow &&
              ev.origin === innerIframeOrigin
          )
          ->Option.getOr(false)
        if isOurCoordinator {
          let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
          let dict = json->getDictFromJson
          if dict->getBool("iframeMounted", false) {
            coordinatorReadyRef := true
            flushPendingPorts()
            syncCoordinatorSessions()
          } else {
            switch dict->Dict.get("confirmResult") {
            | Some(result) =>
              let confirmId = dict->getString("confirmId", "")
              switch coordinatorConfirmPendingRef.contents {
              | Some((pendingId, settle)) if pendingId == confirmId =>
                coordinatorConfirmPendingRef := None
                settle(result)
              | _ => ()
              }
            | None => ()
            }
          }
        }
      },
      coordinatorListenerName,
    )
  }

  let ensureCoordinatorMounted = () => {
    switch coordinatorMountRef.contents {
    | Some(_) => ()
    | None =>
      let groupAppearance =
        optionsDict->Dict.get("appearance")->Option.getOr(Dict.make()->JSON.Encode.object)
      let groupConfigAsOptions =
        [
          ("sdkAuthorization", sdkAuthorizationRaw->JSON.Encode.string),
          ("publishableKey", publishableKey->JSON.Encode.string),
          ("appearance", groupAppearance),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      let mount = CoordinatorMount.create(
        ~parentContainer=Window.body,
        ~localSelectorString=groupInstanceId,
        ~elementIframeId="cardFormCoordinator",
        ~surfaceFamily="vault",
        ~groupId=groupInstanceId,
        ~sdkDomain=ApiEndpoint.vaultSdkDomainUrl,
      )
      coordinatorMountRef := Some(mount)
      attachCoordinatorListener()
      let (fullscreenRouter, fullscreenAnswerer) = CoordinatorMount.makeFullscreenFlows(
        ~mount,
        ~localSelectorString=groupInstanceId,
        ~sdkDomain=ApiEndpoint.vaultSdkDomainUrl,
        ~options=groupConfigAsOptions,
        ~appearance=groupAppearance,
      )
      // `Types.event` and `Window.event` are two record overlays of the SAME
      // MessageEvent; the Utils.eventToWindowEvent identity bridges them typed.
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenRouter(ev->eventToWindowEvent),
        `onVaultCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenAnswerer(ev->eventToWindowEvent),
        CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
      )
    }
  }

  let vaultOptionDict = optionsDict->Dict.get("vault")->Option.flatMap(JSON.Decode.object)

  switch vaultOptionDict {
  | Some(vaultDict) => {
      let vaultType = vaultDict->getString("vault_type", "")
      let vaultData = vaultDict->Dict.get("vault_data")->Option.getOr(JSON.Encode.null)
      /* Merchant-supplied `expires_at` is intentionally NOT parsed here: the
         backend sessions payload is the sole expiry source. In Mode B the
         gate stays "unknown" (never proactively expired) until/unless a
         backend sessions hydrate lands. */

      let syntheticSession = buildSyntheticSession(~pmSessionId, ~customerId, ~vaultType, ~vaultData)
      sessionsDataRef := syntheticSession

      let vaultMode = vaultType->VaultHelpers.getVaultModeFromName
      let loadedSession: PaymentType.loadType = Loaded(syntheticSession)
      let vaultConfigJson = VaultHelpers.buildVaultConfig(loadedSession, vaultMode)
      vaultCredentialsRef := vaultConfigJson
    }
  | None => {
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)
      PaymentHelpersV2.fetchPaymentManagementList(
        ~pmSessionId,
        ~endpoint,
        ~optLogger=None,
        ~customPodUri="",
        ~sdkAuthorization=sdkAuthorizationRaw,
      )
      ->Promise.then(sessionJson => {
        sessionsDataRef := sessionJson
        let sessionDict = sessionJson->getDictFromJson
        let expiresAt = sessionDict->getString("expires_at", "")
        expiresAtRef := parseExpiresAtMs(expiresAt)

        let vaultType =
          sessionDict->getDictFromDict("vault_details")->getString("vault_type", "")
        let vaultMode = vaultType->VaultHelpers.getVaultModeFromName
        let loadedSession: PaymentType.loadType = Loaded(sessionJson)
        let vaultConfigJson = VaultHelpers.buildVaultConfig(loadedSession, vaultMode)
        vaultCredentialsRef := vaultConfigJson
        /* slow-fetch twin of the ready-flush: if the coordinator mounted before this fetch
           resolved, push the session snapshot now. */
        syncCoordinatorSessions()
        Promise.resolve()
      })
      ->Promise.catch(err => {
        Console.error2("[PaymentMethodsSessionGroup] session fetch failed", err)
        Promise.resolve()
      })
      ->ignore
    }
  }

  /* each `create()` mounts an iframe at componentName=paymentMethodsSDK with the bare
     `fieldName` and `surfaceFamily=vault`, driven over the paymentElementCreate protocol. */
  let mapFieldTypeToInternalFieldName = CardFormShared.mapFieldTypeToInternalFieldName

  // Mode A resolves async, so a `create()` that beats the fetch sees "unknown" (= Hyperswitch).
  let detectVaultType = (): string => {
    let declaredType =
      optionsDict
      ->Dict.get("vault")
      ->Option.flatMap(JSON.Decode.object)
      ->Option.map(d => d->getString("vault_type", ""))
      ->Option.getOr("")
    if declaredType->String.length > 0 {
      declaredType
    } else if VGSVaultBroker.isVGSProvider(vaultCredentialsRef.contents) {
      "vgs"
    } else if vaultCredentialsRef.contents !== JSON.Encode.null {
      "hyperswitch"
    } else {
      "hyperswitch"
    }
  }

  let getOrCreateVgsBroker = (): option<VGSVaultBroker.vgsBrokerHandle> => {
    switch vgsBrokerRef.contents {
    | Some(broker) => Some(broker)
    | None =>
      let vaultDataDict =
        optionsDict
        ->Dict.get("vault")
        ->Option.flatMap(JSON.Decode.object)
        ->Option.flatMap(d => d->Dict.get("vault_data"))
        ->Option.flatMap(JSON.Decode.object)
      let fromCredentials = vaultCredentialsRef.contents->getDictFromJson
      let vaultId = switch vaultDataDict {
      | Some(d) => d->getString("vault_id", "")
      | None => fromCredentials->getString("vaultId", "")
      }
      let environment = switch vaultDataDict {
      | Some(d) => d->getString("environment", "")
      | None => fromCredentials->getString("environment", "")
      }
      if vaultId->String.length == 0 || environment->String.length == 0 {
        // no usable VGS credentials — leave the broker unset and fall back to the error handle.
        None
      } else {
        let broker = VGSVaultBroker.make(~pmSessionId, ~vaultId, ~environment, ~eventCallbacksRef)
        vgsBrokerRef := Some(broker)
        Some(broker)
      }
    }
  }

  let buildMountConfig = (~options: JSON.t, ~fieldId: string) => {
    /* `options` here is the PER-FIELD bag from `cardForm.create(type, opts)`; do NOT shadow
       the outer merchant `optionsDict`, which is where the top-level `appearance` lives. */
    let fieldOptionsDict = options->getDictFromJson
    let savedCardDict = fieldOptionsDict->getDictFromDict("savedCard")
    let savedCardBrand = savedCardDict->getString("brand", "")
    let emptyJson = Dict.make()->JSON.Encode.object
    let fieldAppearance = fieldOptionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    let appearance = if (
      fieldAppearance
      ->JSON.Decode.object
      ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
      ->Option.getOr(false)
    ) {
      fieldAppearance
    } else {
      optionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    }
    let redirectionFlagsDict =
      [
        ("shouldUseTopRedirection", JSON.Encode.bool(false)),
        ("shouldRemoveBeforeUnloadEvents", JSON.Encode.bool(false)),
      ]->Dict.fromArray
    /* appearance must be wrapped in the widgetOptions envelope `CardTheme.itemToObjMapper`
       expects — the raw merchant bag warns "Unknown Key" and drops the customizations. */
    let paymentOptions =
      [
        ("appearance", appearance),
        ("fonts", []->JSON.Encode.array),
        ("locale", locale->JSON.Encode.string),
        ("sdkAuthorization", sdkAuthorizationRaw->JSON.Encode.string),
        ("pmSessionId", pmSessionId->JSON.Encode.string),
      ]->Dict.fromArray->JSON.Encode.object
    [
      ("paymentElementCreate", true->JSON.Encode.bool),
      ("otherElements", false->JSON.Encode.bool),
      ("componentType", "payment"->JSON.Encode.string),
      ("paymentOptions", paymentOptions),
      ("options", options),
      ("iframeId", fieldId->JSON.Encode.string),
      ("publishableKey", publishableKey->JSON.Encode.string),
      ("endpoint", ApiEndpoint.getVaultEndPoint(~publishableKey)->JSON.Encode.string),
      ("sdkSessionId", pmSessionId->JSON.Encode.string),
      ("customPodUri", ""->JSON.Encode.string),
      ("parentURL", "*"->JSON.Encode.string),
      ("sdkHandleOneClickConfirmPayment", false->JSON.Encode.bool),
      ("launchTime", Date.now()->JSON.Encode.float),
      ("loggerSource", "hyper_vault"->JSON.Encode.string),
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
    ]->Dict.fromArray
  }

  let createFieldHandle = (fieldType: string, options: JSON.t, fieldId: string): fieldEntry => {
    let iframeRef: ref<Nullable.t<Dom.element>> = ref(Nullable.null)

    let eventHandlersRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())

    let savedCardDict = options->getDictFromJson->getDictFromDict("savedCard")
    let savedCardBrandRef = ref(savedCardDict->getString("brand", ""))
    let savedCardLast4Ref = ref(savedCardDict->getString("last4", ""))

    let prevFocusReadyRef = ref(false)

    let mountPostMessage = (mountedIframeRef, _selectorString, _sdkHandleOneClick) => {
      let config = buildMountConfig(~options, ~fieldId)
      // MessageChannel Card Relay: ONE channel per field mount per portEpoch.
      portEpochCounterRef := portEpochCounterRef.contents + 1
      let epoch = portEpochCounterRef.contents
      let channel = MessageChannelBinding.makeChannel()
      let portKey = CardFormCoordinator.portKey(
        ~groupId=groupInstanceId,
        ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      )
      installedPortKeysRef := installedPortKeysRef.contents->Array.concat([portKey])
      CoordinatorMount.postFieldMountConfigWithPort(
        ~fieldIframe=mountedIframeRef,
        ~mountConfig=config->JSON.Encode.object,
        ~portKey,
        ~portEpoch=epoch,
        ~port=channel.port2,
      )
      pendingPortsRef := pendingPortsRef.contents->Array.concat([
        {fieldName: mapFieldTypeToInternalFieldName(fieldType), epoch, port: channel.port1},
      ])
      flushPendingPorts()
      if sessionsDataRef.contents != JSON.Encode.null {
        mountedIframeRef->Window.iframePostMessage(
          [("sessions", sessionsDataRef.contents)]->Dict.fromArray,
        )
      }
      /* a cardCvc mounted after the user finished the cardNumber would never see a brand
         CHANGE, so seed it at handshake time with the brand we already learned. */
      if fieldType === "cardCvc" && lastDetectedBrandRef.contents !== "" {
        mountedIframeRef->Window.iframePostMessage(
          [("detectedCardBrand", lastDetectedBrandRef.contents->JSON.Encode.string)]->Dict.fromArray,
        )
      }
    }

    /* match on the iframe's contentWindow AND origin: top-level `iframeId` is absent from
       `cardStateUpdate`, so source is the reliable cross-event matcher, and the origin check
       guards against our own iframe being redirected to a hostile origin mid-session. */
    let attachFieldListener = () => {
      let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.vaultSdkDomainUrl).origin
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => {
          let isOurIframe =
            iframeRef.contents
            ->Nullable.toOption
            ->Option.map(iframe =>
              ev.source === iframe->Window.contentWindow && ev.origin === innerIframeOrigin
            )
            ->Option.getOr(false)
          if isOurIframe {
            let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
            let dict = json->getDictFromJson
            let isReady = dict->getBool("ready", false)
            let isFocus = dict->getBool("focus", false)
            let isBlur = dict->getBool("blur", false)
            let isCardTokenEvent = dict->getBool("cardTokenEvent", false)
            let isCardTokenFail = dict->getBool("cardTokenFail", false)
            let isCvcTokenEvent = dict->getBool("savedCardCvcTokenEvent", false)
            let cardStateUpdate = dict->Dict.get("cardStateUpdate")
            let payload =
              [
                ("elementType", fieldType->JSON.Encode.string),
                ("iframeId", fieldId->JSON.Encode.string),
              ]->Dict.fromArray->JSON.Encode.object
            if isReady {
              eventHandlersRef.contents->Dict.get("ready")->Option.forEach(cb => cb(payload))
            } else if isFocus {
              eventHandlersRef.contents->Dict.get("focus")->Option.forEach(cb => cb(payload))
            } else if isBlur {
              eventHandlersRef.contents->Dict.get("blur")->Option.forEach(cb => cb(payload))
            } else if isCardTokenEvent || isCardTokenFail || isCvcTokenEvent {
              // confirms resolve only via the coordinator's masked `confirmResult`, so this arm is a no-op.
              ()
            } else {
              switch cardStateUpdate {
              | Some(stateJson) =>
                let stateDict = stateJson->getDictFromJson
                /* the raw half of `cardStateUpdate` goes straight to the coordinator on the port plane;
                   the SPLIT payload here never carries rawCardNumber, rawCardExpiry or rawCvc. */

                /* the iframe decides WHEN focus advances; this only routes it. `prevFocusReadyRef` latches
                   the false→true edge so steady-state keystrokes do not re-fire `doFocus`. */
                let prevFocusReady = prevFocusReadyRef.contents
                let newFocusReady = stateDict->getBool("focusReady", false)
                prevFocusReadyRef := newFocusReady
                if newFocusReady && !prevFocusReady {
                  nextFieldFor(fieldType)->Option.forEach(nextFieldType => {
                    let nextIframe =
                      fieldsRef.contents
                      ->Dict.valuesToArray
                      ->Array.find(e => e.fieldType === nextFieldType)
                      ->Option.flatMap(entry => entry.iframeRef.contents->Nullable.toOption)
                    nextIframe->Option.forEach(iframe =>
                      iframe
                      ->Nullable.make
                      ->Window.iframePostMessage(
                        [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray,
                      )
                    )
                  })
                }

                // push to the cardCvc iframe on brand CHANGE only; Flow B's `savedCardBrand` wins.
                if fieldType === "cardNumber" {
                  let cardBrand = stateDict->getString("cardBrand", "")->CardUtils.normalizeCardBrand
                  if cardBrand !== "" && cardBrand !== lastDetectedBrandRef.contents {
                    lastDetectedBrandRef := cardBrand
                    let cvcIframe =
                      fieldsRef.contents
                      ->Dict.valuesToArray
                      ->Array.find(e => e.fieldType === "cardCvc")
                      ->Option.flatMap(entry => entry.iframeRef.contents->Nullable.toOption)
                    cvcIframe->Option.forEach(iframe =>
                      iframe
                      ->Nullable.make
                      ->Window.iframePostMessage(
                        [("detectedCardBrand", cardBrand->JSON.Encode.string)]->Dict.fromArray,
                      )
                    )
                  }
                }

                let errorMessage = stateDict->getString("error", "")
                let changePayload = reshapeCardStateUpdateToChangePayload(
                  ~fieldType,
                  ~stateJson,
                )
                eventHandlersRef.contents
                ->Dict.get("change")
                ->Option.forEach(cb => cb(changePayload))
                if errorMessage->String.length > 0 {
                  let errorPayload = {
                    let errDict = Dict.make()
                    errDict->Dict.set("elementType", fieldType->JSON.Encode.string)
                    errDict->Dict.set("iframeId", fieldId->JSON.Encode.string)
                    errDict->Dict.set("message", errorMessage->JSON.Encode.string)
                    errDict->JSON.Encode.object
                  }
                  eventHandlersRef.contents
                  ->Dict.get("error")
                  ->Option.forEach(cb => cb(errorPayload))
                }
              | None => ()
              }
            }
          }
        },
        `onVaultField-${fieldId}`,
      )
    }

    let fieldOptionsDict = options->getDictFromJson
    let emptyJson = Dict.make()->JSON.Encode.object
    let fieldAppearance = fieldOptionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    let appearanceJson = if (
      fieldAppearance
      ->JSON.Decode.object
      ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
      ->Option.getOr(false)
    ) {
      fieldAppearance
    } else {
      optionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    }
    let fieldOptionsWithAppearanceDict = fieldOptionsDict->Dict.copy
    fieldOptionsWithAppearanceDict->Dict.set("appearance", appearanceJson)
    let optionsForElement = fieldOptionsWithAppearanceDict->JSON.Encode.object

    let element = LoaderPaymentElement.make(
      "paymentMethodsSDK",
      optionsForElement,
      ref => {
        iframeRef := ref
      },
      [],
      mountPostMessage,
      ~appearance=appearanceJson,
      ~redirectionFlags=JotaiAtoms.defaultRedirectionFlags,
      ~sdkDomainUrl=ApiEndpoint.vaultSdkDomainUrl,
      ~logger=None,
      ~confirmPayment=(_json => Promise.resolve(JSON.Encode.null)),
      ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      ~surfaceFamily="vault",
      ~groupId=groupInstanceId,
    )

    attachFieldListener()

    let handle: fieldHandle = {
      mount: selector => {
        element.mount(selector)
      },
      unmount: () => {
        element.unmount()
      },
      destroy: () => {
        element.destroy()
        iframeRef := Nullable.null
        /* remove THIS field's smartEventListener — `fieldId` is unique per `create()`, so dead
           listeners would accumulate across remounts. Idempotent; `deinit()` reaches it too. */
        EventListenerManager.removeSmartEventListener(
          "message",
          `onVaultField-${fieldId}`,
        )
      },
      update: newOptions => {
        iframeRef.contents->Window.iframePostMessage(
          [
            ("paymentElementsUpdate", true->JSON.Encode.bool),
            ("options", newOptions),
          ]->Dict.fromArray,
        )
        // LoaderController expects `savedCard.brand` as a top-level key, not nested.
        let newSavedCardDict = newOptions->getDictFromJson->getDictFromDict("savedCard")
        let brand = newSavedCardDict->getString("brand", "")
        if brand->String.length > 0 {
          iframeRef.contents->Window.iframePostMessage(
            [("savedCardBrand", brand->JSON.Encode.string)]->Dict.fromArray,
          )
        }
        // refresh the captured hints, else the Flow B union keeps the create()-time values.
        let last4 = newSavedCardDict->getString("last4", "")
        if brand !== "" {
          savedCardBrandRef := brand
        }
        if last4 !== "" {
          savedCardLast4Ref := last4
        }
      },
      focus: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      blur: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doBlur", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      clear: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doClearValues", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      on: (event, cb) => {
        eventHandlersRef.contents->Dict.set(event, cb)
      },
    }

    {
      iframeRef,
      handle,
      fieldType,
      savedCardBrandRef,
      savedCardLast4Ref,
      prevFocusReadyRef,
    }
  }

  let create = (fieldType: string, options: JSON.t): fieldHandle => {
    if sessionStateRef.contents != Active {
      Console.warn(
        `[PaymentMethodsSessionGroup] create("${fieldType}") called on consumed/deinitialized session`,
      )
      Types.defaultFieldHandle
    } else {
      switch mapFieldTypeToInternalFieldName(fieldType) {
      | "" => {
          Console.error(
            `[PaymentMethodsSessionGroup] invalid_field_type: ${fieldType}`,
          )
          Types.defaultFieldHandle
        }
      | _ =>
        let vaultType = detectVaultType()
        switch vaultType {
        | "vgs" =>
          switch getOrCreateVgsBroker() {
          | Some(broker) => {
              let fieldId = `${fieldType}-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
              let savedCardDict = options->getDictFromJson->getDictFromDict("savedCard")
              let savedCardBrand = savedCardDict->getString("brand", "")
              let savedCardLast4 = savedCardDict->getString("last4", "")
              if (
                fieldType === "cardCvc" &&
                  (savedCardBrand->String.length > 0 || savedCardLast4->String.length > 0)
              ) {
                vgsSavedCardBrandRef := savedCardBrand
                vgsSavedCardLast4Ref := savedCardLast4
              }
              let fieldsDict = fields.contents->getDictFromJson
              let fieldMeta =
                [
                  ("id", fieldId->JSON.Encode.string),
                  ("type", fieldType->JSON.Encode.string),
                  ("provider", "vgs"->JSON.Encode.string),
                ]
                ->Dict.fromArray
                ->JSON.Encode.object
              fieldsDict->Dict.set(fieldId, fieldMeta)
              fields := fieldsDict->JSON.Encode.object

              let uniqueSelectorRef: ref<option<string>> = ref(None)

              let fieldOptionsDict = options->getDictFromJson
              let emptyJson = Dict.make()->JSON.Encode.object
              let fieldAppearance = fieldOptionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
              let appearanceJson = if (
                fieldAppearance
                ->JSON.Decode.object
                ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
                ->Option.getOr(false)
              ) {
                fieldAppearance
              } else {
                optionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
              }
              let fieldOptionsWithAppearanceDict = fieldOptionsDict->Dict.copy
              fieldOptionsWithAppearanceDict->Dict.set("appearance", appearanceJson)
              let optionsForBroker = fieldOptionsWithAppearanceDict->JSON.Encode.object

              /* The broker stores handles as opaque JSON.t; this consumer boundary
                 reclaims the typed `VGSTypes.field` view once, via `fieldFromJson`. */
              let getFieldHandle = (): option<VGSTypes.field> => {
                switch broker.fieldsRef.contents->Dict.get(fieldId) {
                | Some(entry) => entry.fieldHandle->Option.map(VGSTypes.fieldFromJson)
                | None => None
                }
              }

              let handle: fieldHandle = {
                mount: selector => {
                  uniqueSelectorRef := Some(selector)
                  broker
                  .mountField(~fieldId, ~fieldType, ~selector, ~options=optionsForBroker)
                  ->Promise.catch(err => {
                    Console.error2(
                      `[PaymentMethodsSessionGroup] VGS mountField(${fieldType}, ${selector}) failed`,
                      err->Identity.anyTypeToJson,
                    )
                    Promise.resolve()
                  })
                  ->ignore
                },
                unmount: () => {
                  broker.unmountField(~fieldId)
                  uniqueSelectorRef := None
                },
                destroy: () => {
                  broker.unmountField(~fieldId)
                  uniqueSelectorRef := None
                },
                update: newOptions => {
                  broker.updateField(~fieldId, ~options=newOptions)
                  // refresh captured hints; `!== ""` guards keep a partial update from blanking a sibling.
                  let newSavedCardDict = newOptions->getDictFromJson->getDictFromDict("savedCard")
                  let newSavedCardBrand = newSavedCardDict->getString("brand", "")
                  let newSavedCardLast4 = newSavedCardDict->getString("last4", "")
                  if newSavedCardBrand !== "" {
                    vgsSavedCardBrandRef := newSavedCardBrand
                  }
                  if newSavedCardLast4 !== "" {
                    vgsSavedCardLast4Ref := newSavedCardLast4
                  }
                },
                focus: () => {
                  switch getFieldHandle() {
                  | Some(vgsFieldHandle) =>
                    try {
                      vgsFieldHandle.focus->Option.forEach(invoke => invoke())
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS focus(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS focus(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                blur: () => {
                  switch getFieldHandle() {
                  | Some(vgsFieldHandle) =>
                    try {
                      vgsFieldHandle.blur->Option.forEach(invoke => invoke())
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS blur(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS blur(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                clear: () => {
                  // VGSCollect 2.27 exposes clear(); the warn fires if a future version drops it.
                  switch getFieldHandle() {
                  | Some(vgsFieldHandle) =>
                    try {
                      let cleared = switch vgsFieldHandle.clear {
                      | Some(invoke) => {
                          invoke()
                          true
                        }
                      | None => false
                      }
                      if !cleared {
                        Console.warn(
                          `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) — field has no clear() method; use update({placeholder: ..., validations: ...}) instead`,
                        )
                      }
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                on: (event, cb) => {
                    /* keyed "<fieldId>::<event>" so the broker's dispatchers find them by composite key —
                       must match `VGSVaultBroker.eventKey` exactly. */
                  let key = `${fieldId}::${event}`
                  eventCallbacksRef.contents->Dict.set(key, cb)
                },
              }
              handle
            }
          | None => {
              Console.error(
                `[PaymentMethodsSessionGroup] vault_type="vgs" declared but vault_data has no vault_id/environment — cannot mount`,
              )
              Types.defaultFieldHandle
            }
          }
        | "hyperswitch" =>
          /* the first hosted-field mount also creates the hidden confirm owner. VGS-only groups
             never reach this branch, so no coordinator is created that it could not exercise. */
          ensureCoordinatorMounted()
          let fieldId = `${fieldType}-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
          let entry = createFieldHandle(fieldType, options, fieldId)
          fieldsRef.contents->Dict.set(fieldId, entry)
          let fieldsDict = fields.contents->getDictFromJson
          let fieldMeta =
            [
              ("id", fieldId->JSON.Encode.string),
              ("type", fieldType->JSON.Encode.string),
            ]->Dict.fromArray->JSON.Encode.object
          fieldsDict->Dict.set(fieldId, fieldMeta)
          fields := fieldsDict->JSON.Encode.object
          entry.handle
        | other => {
            Console.error(
              `[PaymentMethodsSessionGroup] unsupported_provider: vault_type "${other}" not yet supported`,
            )
            Types.defaultFieldHandle
          }
        }
      }
    }
  }

  let update = (_options: JSON.t): unit => {
    Console.warn(
      "[PaymentMethodsSessionGroup] session options are fixed at creation; create a new session to change them",
    )
  }

  let on = (event: string, cb: JSON.t => unit): unit => {
    eventCallbacksRef.contents->Dict.set(event, cb)
  }

  /* unified confirm(). Guards: non-Active → session_consumed, in flight → confirm_in_progress,
     past expires_at → session_expired, then flow inference — cardNumber or cardExpiry → Flow A,
     only cardCvc → Flow B, nothing → incomplete_field_set. Success consumes the session. */

  // the first mounted field of the type wins; confirm is single-shot.
  let findFieldOfType = (matchFieldType: string): option<fieldEntry> => {
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.find(entry => entry.fieldType === matchFieldType)
  }

  let emitGroupError = (envelope: JSON.t): unit => {
    eventCallbacksRef.contents->Dict.get("error")->Option.forEach(cb => cb(envelope))
  }

  let settleResult = (resolve: JSON.t => unit, result: JSON.t): unit => {
    // invariant: promise resolution and the `error` event fire exactly once per failure.
    let outcomeDict = result->getDictFromJson
    let isError = outcomeDict->getString("status", "") === "error"
    if isError {
      emitGroupError(result)
    }
    resolve(result)
  }

  /* the VGS path calls the broker's submitForm() directly — one vault.submit for both flows;
     Flow A gets all four aliases back, Flow B only `card_cvc`. */
  let confirmVgsFlowA = (): promise<JSON.t> => {
    switch getOrCreateVgsBroker() {
    | None =>
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "validation_error",
            message: Some(
              "VGS vault declared but vault_data missing vault_id/environment — cannot confirm",
            ),
            locale,
            typeOverride: Some(ValidationError),
          }),
        ),
      )
    | Some(broker) =>
      // precondition is "a cardNumber field is mounted"; VGSCollect surfaces empty fields itself.
      let cardNumberMounted =
        broker.fieldsRef.contents
        ->Dict.valuesToArray
        ->Array.some(entry => entry.fieldType === "cardNumber" && entry.fieldHandle->Option.isSome)
      if !cardNumberMounted {
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "validation_error",
              message: Some(
                "cardNumber field not mounted — call cardForm.create(\"cardNumber\", opts) then mount() before confirm()",
              ),
              locale,
              typeOverride: None,
            }),
          ),
        )
      } else {
        confirmingRef := true
        broker
        .submitForm()
        ->Promise.then(result => {
          let resultDict = result->getDictFromJson
          let status = resultDict->getString("status", "")
          if status == "error" {
            confirmingRef := false
            let errDict = resultDict->getDictFromDict("error")
            let code = errDict->getString("code", "tokenization_failed")
            let message = errDict->getString("message", "")
            let envelope = buildConfirmResult(
              ~outcome=Failure({
                code,
                message: if message->String.length > 0 {
                  Some(message)
                } else {
                  None
                },
                locale,
                typeOverride: Some(ApiError),
              }),
            )
            emitGroupError(envelope)
            Promise.resolve(envelope)
          } else {
            /* a successful round-trip means the vault already stored the data, so consume the
               session even if the alias fails to decode. */
            sessionStateRef := Consumed
            let cardNumberAlias = resultDict->getString("card_number", "")
            let expMonth = resultDict->getString("card_exp_month", "")
            let expYear = resultDict->getString("card_exp_year", "")
            // brand from the BIN prefix retained in the format-preserving alias; "" when unmatched.
            let brand = detectBrandFromAlias(cardNumberAlias)
            let last4 =
              cardNumberAlias->String.length >= 4
                ? cardNumberAlias->String.sliceToEnd(~start=cardNumberAlias->String.length - 4)
                : ""
            let envelope = buildConfirmResult(
              ~outcome=FlowASuccess({
                token: cardNumberAlias,
                /* no backend session-confirm: the card_number alias IS the merchant's VGS reference, so
                   paymentMethodId stays None. */
                paymentMethodId: None,
                brand,
                last4,
                expiryMonth: expMonth,
                expiryYear: expYear,
              }),
            )
            confirmingRef := false
            Promise.resolve(envelope)
          }
        })
        ->Promise.catch(_exn => {
          confirmingRef := false
          let envelope = buildConfirmResult(
            ~outcome=Failure({
              code: "tokenization_failed",
              message: Some("VGS submitForm rejected unexpectedly"),
              locale,
              typeOverride: Some(ApiError),
            }),
          )
          emitGroupError(envelope)
          Promise.resolve(envelope)
        })
      }
    }
  }

  let confirmVgsFlowB = (): promise<JSON.t> => {
    switch getOrCreateVgsBroker() {
    | None =>
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "validation_error",
            message: Some(
              "VGS vault declared but vault_data missing vault_id/environment — cannot confirm Flow B (saved-card CVC recollect)",
            ),
            locale,
            typeOverride: Some(ValidationError),
          }),
        ),
      )
    | Some(broker) =>
      let cardCvcMounted =
        broker.fieldsRef.contents
        ->Dict.valuesToArray
        ->Array.some(entry => entry.fieldType === "cardCvc" && entry.fieldHandle->Option.isSome)
      if !cardCvcMounted {
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "validation_error",
              message: Some(
                "cardCvc field not mounted — for saved-card recollect, call cardForm.create(\"cardCvc\", {savedCard: {brand, last4}}) then mount() before confirm()",
              ),
              locale,
              typeOverride: None,
            }),
          ),
        )
      } else {
        confirmingRef := true
        broker
        .submitForm()
        ->Promise.then(result => {
          let resultDict = result->getDictFromJson
          let status = resultDict->getString("status", "")
          if status == "error" {
            confirmingRef := false
            let errDict = resultDict->getDictFromDict("error")
            let code = errDict->getString("code", "tokenization_failed")
            let message = errDict->getString("message", "")
            let envelope = buildConfirmResult(
              ~outcome=Failure({
                code,
                message: if message->String.length > 0 {
                  Some(message)
                } else {
                  None
                },
                locale,
                typeOverride: Some(ApiError),
              }),
            )
            emitGroupError(envelope)
            Promise.resolve(envelope)
          } else {
            sessionStateRef := Consumed
            let cvcAlias = resultDict->getString("card_cvc", "")
            let brand = vgsSavedCardBrandRef.contents
            let last4 = vgsSavedCardLast4Ref.contents
            let envelope = buildConfirmResult(
              ~outcome=FlowBSuccess({cvcToken: cvcAlias, brand, last4}),
            )
            confirmingRef := false
            Promise.resolve(envelope)
          }
        })
        ->Promise.catch(_exn => {
          confirmingRef := false
          let envelope = buildConfirmResult(
            ~outcome=Failure({
              code: "tokenization_failed",
              message: Some("VGS submitForm rejected unexpectedly"),
              locale,
              typeOverride: Some(ApiError),
            }),
          )
          emitGroupError(envelope)
          Promise.resolve(envelope)
        })
      }
    }
  }

  /* settle is keyed on the confirmId echoed in the coordinator's `confirmResult`; an
     exactly-once sink plus a hang backstop keeps a dropped frame deterministic. */
  let runCoordinatorRelay = (
    ~flow: string,
    ~savedCardBrand: string="",
    ~savedCardLast4: string="",
  ): promise<JSON.t> => {
    switch coordinatorMountRef.contents {
    | None =>
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "tokenization_failed",
            message: Some(
              "cardFormCoordinator is not mounted — create + mount a hosted (non-VGS) card field before calling confirm()",
            ),
            locale,
            typeOverride: Some(ApiError),
          }),
        ),
      )
    | Some(mount) =>
      Promise.make((resolve, _reject) => {
        let confirmId = `${Date.now()->Float.toString}-${Math.random()->Float.toString}`
        let settledRef = ref(false)
        let settleTimeoutRef = ref(None)
        let settle = result => {
          if !settledRef.contents {
            settledRef := true
            settleTimeoutRef.contents->Option.forEach(clearTimeout)
            coordinatorConfirmPendingRef := None
            confirmingRef := false
            if result->getDictFromJson->getString("status", "") == "success" {
              sessionStateRef := Consumed
            }
            settleResult(resolve, result)
          }
        }
        coordinatorConfirmPendingRef := Some((confirmId, settle))
        settleTimeoutRef := Some(
          setTimeout(
            () =>
              settle(
                buildConfirmResult(
                  ~outcome=Failure({
                    code: "tokenization_failed",
                    message: Some(
                      "confirm relay timed out waiting for the coordinator — it may be degraded. Retry; the session is still active.",
                    ),
                    locale,
                    typeOverride: Some(ApiError),
                  }),
                ),
              ),
            confirmSettleTimeoutMs,
          ),
        )
        try
          mount.iframe->Nullable.make->Window.iframePostMessage(
            [
              ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
              ("flow", flow->JSON.Encode.string),
              ("confirmId", confirmId->JSON.Encode.string),
              ("savedCardBrand", savedCardBrand->JSON.Encode.string),
              ("savedCardLast4", savedCardLast4->JSON.Encode.string),
              ("locale", locale->JSON.Encode.string),
            ]->Dict.fromArray,
          )
        catch {
        | _ => ()
        }
      })
    }
  }

  /* Flow A posts `flow: "save"` to the coordinator (content-free; state rides the port
     plane); Flow B posts `flow: "update"`. VGS branches go through a single vault.submit. */
  let confirm = (): promise<JSON.t> =>
    if sessionStateRef.contents != Active {
      Promise.resolve(sessionConsumedResult(~locale, ()))
    } else if confirmingRef.contents {
      Promise.resolve(confirmInFlightResult(~locale, ()))
    } else if isExpired(~expiresAtMs=expiresAtRef.contents) {
      Promise.resolve(sessionExpiredResult(~locale, ()))
    } else {
      let incompleteFieldSet = () =>
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "incomplete_field_set",
              message: None,
              locale,
              typeOverride: Some(ValidationError),
            }),
          ),
        )
      if detectVaultType() == "vgs" {
        let (numberMounted, cvcMounted) = switch vgsBrokerRef.contents {
        | Some(broker) => {
            let entries = broker.fieldsRef.contents->Dict.valuesToArray
            (
              entries->Array.some(e => e.fieldType === "cardNumber" && e.fieldHandle->Option.isSome),
              entries->Array.some(e => e.fieldType === "cardCvc" && e.fieldHandle->Option.isSome),
            )
          }
        | None => (false, false)
        }
        if numberMounted {
          confirmVgsFlowA()
        } else if cvcMounted {
          confirmVgsFlowB()
        } else {
          incompleteFieldSet()
        }
      } else {
        switch (findFieldOfType("cardNumber"), findFieldOfType("cardExpiry"), findFieldOfType("cardCvc")) {
        | (None, None, None) => incompleteFieldSet()
        | (Some(_field), _, _) =>
          confirmingRef := true
          runCoordinatorRelay(~flow="save")
        | (None, Some(_), _) =>
          // cardExpiry w/o cardNumber can't tokenize on its own — reject.
          incompleteFieldSet()
        | (None, None, Some(field)) =>
          // Flow B — savedCard hints ride the command so the masked result can echo them back.
          confirmingRef := true
          runCoordinatorRelay(
            ~flow="update",
            ~savedCardBrand=field.savedCardBrandRef.contents,
            ~savedCardLast4=field.savedCardLast4Ref.contents,
          )
        }
      }
    }

  // idempotent teardown: field iframes, refs, and (for VGS) the broker plus script marker.
  let deinit = (): unit => {
    if sessionStateRef.contents != Deinitialized {
      fieldsRef.contents
      ->Dict.valuesToArray
      ->Array.forEach(entry => {
        try {
          entry.handle.destroy()
        } catch {
        | _ => ()
        }
      })
      fieldsRef := Dict.make()

      vgsBrokerRef.contents->Option.forEach(broker => broker.unmountAll())
      vgsBrokerRef := None

        /* removing the <script> also removes the data-vgs-script-loaded marker, which is the
           point: the broker's script dedupe is one-shot per page. */
      switch Window.querySelector(`script[data-vgs-script-loaded]`)->Nullable.toOption {
      | Some(script) =>
        try {
          script->Window.remove
        } catch {
        | _ => ()
        }
      | None => ()
      }

      fields := Dict.make()->JSON.Encode.object
      sessionStateRef := Deinitialized
      confirmingRef := false

      // close ports queued but never transferred, remove the coordinator iframe and listener.
      installedPortKeysRef.contents->Array.forEach(key => SadPortRegistry.closePort(~key))
      installedPortKeysRef := []
      coordinatorMountRef.contents->Option.forEach(
        mount => CoordinatorMount.teardown(~mount, ~pendingPorts=pendingPortsRef.contents),
      )
      pendingPortsRef := []
      coordinatorMountRef := None
      coordinatorReadyRef := false
      coordinatorConfirmPendingRef := None
      EventListenerManager.removeSmartEventListener("message", coordinatorListenerName)
      EventListenerManager.removeSmartEventListener(
        "message",
        `onVaultCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.removeSmartEventListener(
        "message",
        CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
      )
    }
  }

  let cardForm = (): cardForm => {
    create,
    on,
    confirm,
    deinit,
    update,
    fields,
  }

  {
    cardForm,
    update,
    on,
    deinit,
    fields,
  }
}
