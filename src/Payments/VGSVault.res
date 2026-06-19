// VGSVault
// Rendered inside the Cards SDK iframe (via <CardsSDK />) when the session's vault
// provider is VGS.  It loads the VGS Collect.js SDK, mounts three secure fields
// (card / expiry / cvc) styled to match the native Hyperswitch fields, and on
// submit tokenises the card.  The resulting aliases are posted back to
// ParentCardComponent (via `vgsTokenEvent`), which confirms the payment with the
// full business-logic body — exactly mirroring the Hyperswitch `cardTokenEvent`
// path so required fields / installments / customer-acceptance are preserved.
open Utils
open VGSTypes
open VGSHelpers
open VGSConstants

// Subresource-integrity hash for the pinned vgs-collect 2.27.2 bundle (see VGSConstants).
let vgsScriptIntegrity = "sha384-ddxU1XAc77oB4EIpKOgJQ3FN2a6STYPK0JipRqg1x/eW+n5MFn1XbbZa7+KRjkqc"

@react.component
let make = () => {
  let vaultCredentials = Recoil.useRecoilValueFromAtom(RecoilAtoms.vaultCredentials)
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {innerLayout} = config.appearance

  let (vaultId, environment) = switch vaultCredentials {
  | VGS(creds) => (creds.vaultId, creds.environment)
  | _ => ("", "")
  }

  let (isCardFocused, setIsCardFocused) = React.useState(() => None)
  let (isCVCFocused, setIsCVCFocused) = React.useState(() => None)
  let (isExpiryFocused, setIsExpiryFocused) = React.useState(() => None)

  let (form, setForm) = React.useState(() => None)
  let (cardField, setCardField) = React.useState(() => None)
  let (expiryField, setExpiryField) = React.useState(() => None)
  let (cvcField, setCVCField) = React.useState(() => None)

  let (vgsCardError, setVgsCardError) = React.useState(() => "")
  let (vgsExpiryError, setVgsExpiryError) = React.useState(() => "")
  let (vgsCVCError, setVgsCVCError) = React.useState(() => "")

  let (vgsScriptLoaded, setVgsScriptLoaded) = React.useState(() => false)

  // Latest VGS form-state snapshot (per-field isEmpty/isValid/isFocused), kept in
  // a ref so the submit handler can validate synchronously — without depending on
  // VGS's async submit error callback, whose blur-driven state change used to race
  // with and swallow the first submit's errors.
  let formStateRef = React.useRef(Dict.make())

  // Register each field's focus/blur listeners exactly once — when that field is
  // first created (None → Some) — rather than on every render, which would stack
  // duplicate `on` listeners. One effect per field so each registers exactly once
  // regardless of how the field state updates are batched.
  React.useEffect(() => {
    handleVGSField(cardField, setIsCardFocused, setVgsCardError)
    None
  }, [cardField])
  React.useEffect(() => {
    handleVGSField(expiryField, setIsExpiryFocused, setVgsExpiryError)
    None
  }, [expiryField])
  React.useEffect(() => {
    handleVGSField(cvcField, setIsCVCFocused, setVgsCVCError)
    None
  }, [cvcField])

  let initializeVGSFields = (vault: returnValue) => {
    setCardField(_ => Some(vault.field("#vgs-cc-number", cardNumberOptions)))
    setExpiryField(_ => Some(
      vault.field("#vgs-cc-expiry", cardExpiryOptions(localeString.expiryPlaceholder)),
    ))
    setCVCField(_ => Some(vault.field("#vgs-cc-cvc", cardCvcOptions)))
    setForm(_ => Some(vault))
  }

  // Live form-state callback — keeps the inline field errors in sync as the user
  // types.  It only *surfaces* errors, never clears them: clearing is owned by the
  // field focus handler.  This stops a blur-triggered state change (e.g. the Pay
  // button stealing focus on click) from wiping an error the submit handler just
  // set — the bug where the first Pay click showed no error.
  let handleVGSErrors = vgsState => {
    let dict = vgsState->getDictFromJson
    formStateRef.current = dict
    let setIfPresent = (setError, errStr) =>
      if errStr != "" {
        setError(_ => errStr)
      }
    setIfPresent(setVgsCardError, vgsErrorHandler(dict, "card_number", localeString))
    setIfPresent(setVgsExpiryError, vgsErrorHandler(dict, "card_exp", localeString))
    setIfPresent(setVgsCVCError, vgsErrorHandler(dict, "card_cvc", localeString))
  }

  let mountVGSSDK = () => {
    let scriptEl = Window.createElement("script")

    scriptEl->Window.setAttribute("type", "text/javascript")
    scriptEl->Window.setAttribute("crossorigin", "anonymous")
    scriptEl->Window.setAttribute("integrity", vgsScriptIntegrity)
    scriptEl->Window.elementSrc(vgsScriptURL)

    scriptEl->Window.elementOnerror(exn => {
      Console.error2("Error loading VGS script", exn)
      // Card payment can't work without VGS — tell the outer iframe so it can drop
      // the card method from the payment methods list.
      messageParentWindow([("vgsScriptLoadFailed", true->JSON.Encode.bool)])
    })

    scriptEl->Window.elementOnload(_ => {
      setVgsScriptLoaded(_ => true)
      let vault = create(vaultId, environment, handleVGSErrors)
      initializeVGSFields(vault)
    })

    Window.body->Window.appendChild(scriptEl)
  }

  React.useEffect(() => {
    if !vgsScriptLoaded && vaultId != "" && environment != "" {
      mountVGSSDK()
    }
    None
  }, (vaultId, environment, vgsScriptLoaded))

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirmDict = json->getDictFromJson
    let confirm = confirmDict->ConfirmType.itemToObjMapper
    let isOuterValid = confirmDict->getBool("isOuterValid", true)

    if confirm.doSubmit {
      switch form {
      | Some(vault) =>
        // Validate synchronously from the latest tracked field state (mirroring
        // the native CardPayment submit path) instead of relying on VGS's async
        // submit error callback, which raced with the focus-blur state change.
        let stateDict = formStateRef.current
        let cardErr = vgsErrorHandler(stateDict, "card_number", ~isSubmit=true, localeString)
        let expiryErr = vgsErrorHandler(stateDict, "card_exp", ~isSubmit=true, localeString)
        let cvcErr = vgsErrorHandler(stateDict, "card_cvc", ~isSubmit=true, localeString)
        setVgsCardError(_ => cardErr)
        setVgsExpiryError(_ => expiryErr)
        setVgsCVCError(_ => cvcErr)

        let cardFieldsValid = cardErr == "" && expiryErr == "" && cvcErr == ""

        if cardFieldsValid && isOuterValid {
          // Card fields AND outer required fields are valid → tokenise with VGS.
          // Gating on isOuterValid here (rather than inside onSuccess) means we
          // never send card data to VGS when the outer fields are invalid:
          // ParentCardComponent has already reported that error and isn't
          // listening for the token. Mirrors CardPayment's submit gate.
          let emptyPayload = JSON.Encode.object(Dict.make())

          // Tokenisation succeeded — forward the aliases to ParentCardComponent so
          // it can build the confirm body and call intent.
          let onSuccess = (_, data) => {
            let (cardNumber, month, year, cvcNumber) = getTokenizedData(data)
            messageParentWindow([
              ("vgsTokenEvent", true->JSON.Encode.bool),
              (
                "vgsCardData",
                [
                  ("cardNumber", cardNumber->JSON.Encode.string),
                  ("month", month->JSON.Encode.string),
                  ("year", year->JSON.Encode.string),
                  ("cvcNumber", cvcNumber->JSON.Encode.string),
                ]->getJsonFromArrayOfJson,
              ),
            ])
          }

          // Fields are valid, so onError here is a genuine tokenisation/network
          // failure (not a validation error) — reject the merchant promise.
          let onError = _ =>
            postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")

          vault.submit("/post", emptyPayload, onSuccess, onError)
        } else if !cardFieldsValid {
          // Card fields invalid → reject the merchant's confirm promise once, with
          // the message that matches the failure (missing field vs. invalid
          // details). When only the outer fields are invalid, ParentCardComponent
          // has already reported it, so there is nothing to do here.
          let anyEmpty =
            isFieldEmpty(stateDict, "card_number") ||
            isFieldEmpty(stateDict, "card_exp") ||
            isFieldEmpty(stateDict, "card_cvc")
          submitUserError(
            anyEmpty ? localeString.enterFieldsText : localeString.enterValidDetailsText,
          )
        }

      | None => Console.error("VGS Vault not initialized for submission")
      }
    }
  }, (form, localeString))

  useSubmitPaymentData(submitCallback)

  <div className="animate-slowShow">
    <div className="flex flex-col" style={gridGap: themeObj.spacingGridColumn}>
      <div className="flex flex-col w-full" style={gridGap: themeObj.spacingGridColumn}>
        <RenderIf condition={innerLayout === Compressed}>
          <div
            style={
              marginBottom: "5px",
              fontSize: themeObj.fontSizeLg,
              opacity: "0.6",
            }>
            {React.string(localeString.cardHeader)}
          </div>
        </RenderIf>
        <VGSInputComponent
          fieldName={localeString.cardNumberLabel}
          id="vgs-cc-number"
          isFocused={isCardFocused->Option.getOr(false)}
          errorStr=vgsCardError
        />
        <div
          className="flex flex-row w-full place-content-between"
          style={
            gridColumnGap: {innerLayout === Spaced ? themeObj.spacingGridRow : ""},
          }>
          <div className={innerLayout === Spaced ? "w-[47%]" : "w-[50%]"}>
            <VGSInputComponent
              fieldName={localeString.validThruText}
              id="vgs-cc-expiry"
              isFocused={isExpiryFocused->Option.getOr(false)}
              errorStr=vgsExpiryError
            />
          </div>
          <div className={innerLayout === Spaced ? "w-[47%]" : "w-[50%]"}>
            <VGSInputComponent
              fieldName={localeString.cvcTextLabel}
              id="vgs-cc-cvc"
              isFocused={isCVCFocused->Option.getOr(false)}
              errorStr=vgsCVCError
            />
          </div>
        </div>
        <ErrorComponent cardError=vgsCardError expiryError=vgsExpiryError cvcError=vgsCVCError />
      </div>
    </div>
  </div>
}

let default = make
