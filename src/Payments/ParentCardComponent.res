open Utils
open UtilityHooks
open PaymentType

let innerIframeContainerDivId = "parent-card-inner-iframe-container"

@react.component
let make = () => {
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let optionsPayment = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let sdkConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let nickname = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCardNickName)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let sessionToken = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(RecoilAtoms.redirectionFlagsAtom)

  let {
    displaySavedPaymentMethodsCheckbox,
    savedPaymentMethodsCheckboxCheckedByDefault,
    alwaysSendCustomerAcceptance,
    hideCardNicknameField,
    layout,
  } = optionsPayment
  let layoutClass = CardUtils.getLayoutClass(layout)
  let {themeObj, localeString} = sdkConfig

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ =>
    savedPaymentMethodsCheckboxCheckedByDefault
  )
  let (selectedInstallmentPlan, setSelectedInstallmentPlan) = React.useState(_ => None)
  let (showInstallments, setShowInstallments) = React.useState(_ => false)
  let (installmentsError, setInstallmentsError) = React.useState(_ => "")

  let iframeRef = React.useRef(Nullable.null)
  let (iframeMounted, setIframeMounted) = React.useState(_ => false)
  let (cardBrand, setCardBrand) = React.useState(_ => "")
  let setIsVgsScriptReady = Recoil.useSetRecoilState(RecoilAtoms.isVgsScriptReady)

  // mountPostMessage is captured once (in useEffect0) and fires later when the
  // inner iframe signals readiness, so it must read the LATEST config values
  // via refs rather than its stale-at-creation closure.
  let sdkConfigRef = React.useRef(sdkConfig)
  let publishableKeyRef = React.useRef(publishableKey)
  React.useEffect(() => {
    sdkConfigRef.current = sdkConfig
    publishableKeyRef.current = publishableKey
    None
  }, (sdkConfig, publishableKey))

  let isGuestCustomer = useIsGuestCustomer()
  let isCustomerAcceptanceFromHook = useIsCustomerAcceptanceRequired(
    ~displaySavedPaymentMethodsCheckbox,
    ~isSaveCardsChecked,
    ~isGuestCustomer,
  )
  let isCustomerAcceptanceRequired =
    (!isGuestCustomer && alwaysSendCustomerAcceptance) || isCustomerAcceptanceFromHook

  let conditionsForShowingSaveCardCheckbox =
    paymentMethodListValue.mandate_payment->Option.isNone &&
    !isGuestCustomer &&
    paymentMethodListValue.payment_type !== SETUP_MANDATE &&
    displaySavedPaymentMethodsCheckbox

  // ── Step 1: Inject the inner iframe via LoaderPaymentElement.make().mount() ──
  // The inner iframe is rendered by <LoaderController> (see App.res), exactly like
  // the first iframe. So `mountPostMessage` — which LoaderPaymentElement invokes
  // when the inner iframe signals { iframeMounted: true } — sends the standard
  // `paymentElementCreate` message that LoaderController consumes. We send only the
  // minimal fields needed to replicate current behaviour: paymentOptions (drives
  // setConfigs → theme/locale/keys), iframeId (used for height), publishableKey.
  // Height management is handled automatically by LoaderPaymentElement.mount's
  // built-in { iframeHeight, iframeId } listener. Vault data is forwarded separately
  // via the standard `sessions` message (Step 2).
  let mountPostMessage = React.useCallback(
    (mountedIframeRef, selectorString, _sdkHandleOneClickConfirmPayment) => {
      let sdkConfig = sdkConfigRef.current
      let publishableKey = publishableKeyRef.current

      // sdkConfig.config is the resolved config blob; LoaderController.setConfigs
      // re-parses it via CardTheme.itemToObjMapper (it already carries
      // clientSecret / sdkAuthorization / pmSessionId / loader).
      let message =
        [
          ("paymentElementCreate", true->JSON.Encode.bool),
          ("paymentOptions", sdkConfig.config->Identity.anyTypeToJson),
          ("iframeId", selectorString->JSON.Encode.string),
          ("publishableKey", publishableKey->JSON.Encode.string),
        ]->Dict.fromArray

      mountedIframeRef->Window.iframePostMessage(message)
      setIframeMounted(_ => true)
    },
    [],
  )

  React.useEffect0(() => {
    let setIframeRefFn = ref => {
      iframeRef.current = ref
    }
    let element = LoaderPaymentElement.make(
      "paymentMethodsSDK",
      Dict.make()->JSON.Encode.object,
      setIframeRefFn,
      [],
      mountPostMessage,
      ~appearance=Dict.make()->JSON.Encode.object,
      ~redirectionFlags,
      ~logger=Some(loggerState),
    )
    element.mount(`#${innerIframeContainerDivId}`)
    Some(
      () => {
        element.unmount()
        setIframeMounted(_ => false)
      },
    )
  })

  // ── Step 2: Forward sessions to the inner iframe (reactive) ─────────────────
  // Mirrors Hyper.res's sessionUpdate push: when sessions resolve (or change),
  // forward them via the standard `sessions` message that the inner LoaderController
  // already handles. The inner iframe derives the vault from its own `sessions` atom,
  // so ParentCardComponent stays vault-agnostic.
  React.useEffect(() => {
    switch (iframeMounted, sessionToken) {
    | (true, Loaded(s)) =>
      iframeRef.current->Window.iframePostMessage([("sessions", s)]->Dict.fromArray)
    | _ => ()
    }
    None
  }, (iframeMounted, sessionToken))

  // ── Step 3: Re-forward config (appearance) to the inner iframe (reactive) ────
  // mountPostMessage forwards paymentOptions exactly once — when the inner iframe
  // first signals readiness. If the merchant's custom appearance only resolves
  // into sdkConfig AFTER that first send (a mount-time race), the inner iframe
  // keeps the default appearance until a remount (e.g. switching payment-method
  // tabs and back). Re-posting the latest config whenever sdkConfig changes applies
  // the appearance immediately on first render. paymentElementCreate=false takes
  // LoaderController's lightweight path: it re-runs setConfigs (theme/appearance)
  // without re-initialising sessionId / options / render logs.
  React.useEffect(() => {
    if iframeMounted {
      iframeRef.current->Window.iframePostMessage(
        [
          ("paymentElementCreate", false->JSON.Encode.bool),
          ("paymentOptions", sdkConfig.config->Identity.anyTypeToJson),
        ]->Dict.fromArray,
      )
    }
    None
  }, (iframeMounted, sdkConfig))

  React.useEffect(() => {
    let handleMessage = (ev: Window.event) => {
      let dict = ev.data->Identity.anyTypeToJson->getDictFromJson

      if dict->Dict.get("cardBrandUpdate")->Option.isSome {
        setCardBrand(_ => dict->getString("cardBrandUpdate", ""))
      }

      // The VGS Collect.js script failed to load in the inner iframe — card
      // payment is impossible, so mark the vault script as unavailable. The
      // payment methods list filters out "card" when this is false.
      if dict->Dict.get("vgsScriptLoadFailed")->Option.isSome {
        loggerState.setLogError(
          ~value=`Error during loading VGS script`->Identity.anyTypeToJson->JSON.stringify,
          ~eventName=VGS_VAULT_FLOW,
        )
        setIsVgsScriptReady(_ => false)
      }
    }
    Window.addEventListener("message", handleMessage)
    Some(() => Window.removeEventListener("message", handleMessage))
  }, [iframeMounted])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      let isNicknameValid = nickname.value === "" || nickname.isValid->Option.getOr(false)
      let isInstallmentValid = !showInstallments || selectedInstallmentPlan->Option.isSome
      let outerValid = areRequiredFieldsValid && isNicknameValid && isInstallmentValid
      let innerMessage = json->getDictFromJson
      innerMessage->Dict.set("isOuterValid", outerValid->JSON.Encode.bool)
      iframeRef.current->Window.iframePostMessage(innerMessage)
      if !outerValid {
        // Report the error back to Hyper.res immediately — do not forward to inner iframe.
        let setUserError = message =>
          postFailedSubmitResponse(~errortype="validation_error", ~message)
        if !areRequiredFieldsValid {
          setUserError(localeString.enterValidDetailsText)
        } else if !isNicknameValid {
          setUserError(localeString.enterValidDetailsText)
        } else if !isInstallmentValid {
          setUserError(localeString.installmentSelectPlanError)
        }
      } else {
        // Forward the full doSubmit message (including confirmParams) to the inner iframe.
        // iframeRef.current->Window.iframePostMessage(json->getDictFromJson)

        let handle = (ev: Types.event) => {
          let dict = ev.data->Identity.anyTypeToJson->getDictFromJson

          // Vault-agnostic confirm: takes the per-vault card body and merges the
          // outer business-logic (customer-acceptance, installments, required
          // fields) before calling intent. Shared by every vault token path.
          let confirmWithVaultBody = baseBody => {
            let onSessionBody = [("customer_acceptance", PaymentBody.customerAcceptanceBody)]
            let cardBody = isCustomerAcceptanceRequired
              ? baseBody->Array.concat(onSessionBody)
              : baseBody
            let installmentBody = selectedInstallmentPlan->PaymentBody.installmentBody
            let finalBody =
              cardBody->Array.concat(installmentBody)->mergeAndFlattenToTuples(requiredFieldsBody)
            intent(
              ~bodyArr=finalBody,
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }

          if dict->Dict.get("cardTokenEvent")->Option.isSome {
            // Hyperswitch vault: inner iframe sends the full vault API response.
            // Decode it into a typed record; ParentCardComponent (or the merchant
            // in a future direct-SDK flow) can then act on the structured fields.
            let vaultResponse = dict->getJsonObjectFromDict("vaultResponse")
            let {token, last4Digits, binNumber} = VaultHelpers.decodeVaultTokenData(vaultResponse)
            if token !== "" {
              confirmWithVaultBody(PaymentBody.vaultCardBody(~token, ~last4Digits, ~binNumber))
            } else {
              Console.error("ParentCardComponent: payment token not found in vaultResponse")
            }
          } else if dict->Dict.get("vgsTokenEvent")->Option.isSome {
            // VGS vault: inner iframe sends the aliased card fields (a distinct
            // alias per field) after VGS tokenisation.
            let vgsCardData = dict->getJsonObjectFromDict("vgsCardData")->getDictFromJson
            let cardNumber = vgsCardData->getString("cardNumber", "")
            let month = vgsCardData->getString("month", "")
            let year = vgsCardData->getString("year", "")
            let cvcNumber = vgsCardData->getString("cvcNumber", "")
            // VGS returns a format-preserving card_number alias, so bin / last4 are
            // derived from it the same way a real PAN would be (mirrors vaultCardBody).
            let last4Digits = cardNumber->CardUtils.getCardLast4
            let binNumber = cardNumber->CardUtils.getCardBin
            confirmWithVaultBody(
              PaymentBody.vgsVaultCardBody(
                ~cardNumber,
                ~month,
                ~year,
                ~cvcNumber,
                ~last4Digits,
                ~binNumber,
              ),
            )
          } else if dict->Dict.get("cardTokenFail")->Option.isSome {
            postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
          }

          // Validation / tokenization error from inner iframe — forward to Hyper.res
          // so it can reject the merchant's confirmPayment() promise.
          if dict->Dict.get("submitSuccessful")->Option.isSome {
            messageParentWindow(dict->Dict.toArray)
          }
        }
        EventListenerManager.addSmartEventListener("message", handle, "onParentCardTokenResponse")
      }
    }
  }, (
    iframeRef,
    areRequiredFieldsValid,
    isCustomerAcceptanceRequired,
    selectedInstallmentPlan,
    showInstallments,
    nickname,
    requiredFieldsBody,
    isManualRetryEnabled,
    localeString,
    intent,
  ))
  useSubmitPaymentData(submitCallback)

  let cardType = cardBrand->CardUtils.getCardType
  // Match the mt-4 top margin that other payment methods (e.g. CardPayment) add
  // in accordion layout so the gap between the accordion title row and the
  // payment content is consistent across all methods.
  let accordionMarginClass = layoutClass.\"type" === Accordion ? "mt-4" : ""

  // Mirror the flex-col + gridGap layout that CardPayment used when everything
  // was in a single component, so the iframe (card fields) and the outer
  // business-logic elements (DynamicFields, checkbox, etc.) stay evenly spaced.
  <div
    className={`ParentCardComponent flex flex-col w-full ${accordionMarginClass}`}
    style={gridGap: themeObj.spacingGridColumn}>
    // Inner iframe container — LoaderPaymentElement.mount injects the iframe here
    // and manages its height automatically via { iframeHeight, iframeId } messages.

    <div
      id=innerIframeContainerDivId
      style={
        position: "relative",
      }
    />
    <DynamicFields
      paymentMethod="card"
      paymentMethodType="debit"
      setRequiredFieldsBody
      isBancontact=false
      isSaveDetailsWithClickToPay=false
    />
    <RenderIf condition={conditionsForShowingSaveCardCheckbox && !alwaysSendCustomerAcceptance}>
      <div className="flex items-center justify-start">
        <SaveDetailsCheckbox isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked />
      </div>
    </RenderIf>
    <RenderIf condition={!hideCardNicknameField && isCustomerAcceptanceRequired}>
      <NicknamePaymentInput />
    </RenderIf>
    <InstallmentOptions
      setSelectedInstallmentPlan
      showInstallments
      setShowInstallments
      paymentMethod="card"
      errorString=installmentsError
      setErrorString=setInstallmentsError
    />
    <RenderIf condition={cardBrand !== ""}>
      <Surcharge paymentMethod="card" paymentMethodType="debit" cardBrand=cardType />
    </RenderIf>
    <Terms paymentMethod="card" paymentMethodType="debit" />
  </div>
}
