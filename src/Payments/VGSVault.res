open Utils
open VGSTypes
open VGSHelpers
open VGSConstants

@react.component
let make = (~isBancontact=false) => {
  let vaultMode = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.vaultMode)

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let sessionToken = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {innerLayout} = config.appearance

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
  let (id, setId) = React.useState(() => "")
  let (env, setEnv) = React.useState(() => "")
  let (vgsScriptLoaded, setVgsScriptLoaded) = React.useState(() => false)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)

  handleVGSField(cardField, setIsCardFocused, setVgsCardError)
  handleVGSField(expiryField, setIsExpiryFocused, setVgsExpiryError)
  handleVGSField(cvcField, setIsCVCFocused, setVgsCVCError)

  let initializeVGS = (vault: returnValue) => {
    setCardField(_ => Some(vault.field("#vgs-cc-number", cardNumberOptions)))
    setExpiryField(_ => Some(
      vault.field("#vgs-cc-expiry", cardExpiryOptions(localeString.expiryPlaceholder)),
    ))
    setCVCField(_ => Some(vault.field("#vgs-cc-cvc", cardCvcOptions)))

    setForm(_ => Some(vault))
  }

  let mountVGSSDK = () => {
    let vgsScript = Window.createElement("script")
    vgsScript->Window.setAttribute(
      "integrity",
      "sha384-ddxU1XAc77oB4EIpKOgJQ3FN2a6STYPK0JipRqg1x/eW+n5MFn1XbbZa7+KRjkqc",
    )
    vgsScript->Window.setAttribute("type", "text/javascript")
    vgsScript->Window.setAttribute("crossorigin", "anonymous")
    vgsScript->Window.elementSrc(vgsScriptURL)
    vgsScript->Window.elementOnerror(exn => {
      Console.error2("Error in loading VGS script", exn)
    })
    vgsScript->Window.elementOnload(_ => {
      setVgsScriptLoaded(_ => true)
      let vault = create(id, env, vgsState => {
        let dict = vgsState->getDictFromJson
        setVgsCardError(_ => vgsErrorHandler(dict, "card_number", localeString))
        setVgsExpiryError(_ => vgsErrorHandler(dict, "card_exp", localeString))
        setVgsCVCError(_ => vgsErrorHandler(dict, "card_cvc", localeString))
      })
      initializeVGS(vault)
    })
    Window.body->Window.appendChild(vgsScript)
  }

  React.useEffect(() => {
    let (vaultId, vaultEnv) = VaultHelpers.getVGSVaultDetails(
      sessionToken,
      vaultMode->VaultHelpers.getVaultNameFromMode,
    )
    setEnv(_ => vaultEnv)
    setId(_ => vaultId)
    None
  }, (sessionToken, vaultMode))

  React.useEffect(() => {
    if !vgsScriptLoaded && id != "" && env != "" {
      mountVGSSDK()
    }
    None
  }, (id, env, vgsScriptLoaded))

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      switch form {
      | Some(vault) =>
        let emptyPayload = JSON.Encode.object(Dict.make())
        vault.submit(
          "/post",
          emptyPayload,
          (_, data) => {
            let (cardNumber, month, year, cvcNumber) = getTokenizedData(data)
            let cardBody = PaymentManagementBody.vgsCardBody(~cardNumber, ~month, ~year, ~cvcNumber)
            intent(
              ~bodyArr={
                cardBody
              },
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          },
          err => {
            let dict = err->getDictFromJson
            setVgsCardError(_ => vgsErrorHandler(dict, "card_number", ~isSubmit=true, localeString))
            setVgsExpiryError(_ => vgsErrorHandler(dict, "card_exp", ~isSubmit=true, localeString))
            setVgsCVCError(_ => vgsErrorHandler(dict, "card_cvc", ~isSubmit=true, localeString))
          },
        )
      | None => Console.error("VGS Vault not initialized for submission")
      }
    }
  }, [form])

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
