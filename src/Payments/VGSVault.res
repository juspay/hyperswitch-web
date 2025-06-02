open Utils
open VGSTypes

@react.component
let make = (~isBancontact=false) => {
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {innerLayout} = config.appearance
  let ssn = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let vaultMode = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.vaultMode)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)

  let (vgsScriptLoaded, setVgsScriptLoaded) = React.useState(() => false)
  let (isCardFocused, setIsCardFocused) = React.useState(() => None)
  let (isCVCFocused, setIsCVCFocused) = React.useState(() => None)
  let (isExpiryFocused, setIsExpiryFocused) = React.useState(() => None)
  let (vgsCardError, setVgsCardError) = React.useState(() => "")
  let (vgsExpiryError, setVgsExpiryError) = React.useState(() => "")
  let (vgsCVCError, setVgsCVCError) = React.useState(() => "")
  let (form, setForm) = React.useState(() => None)
  let (id, setId) = React.useState(() => None)
  let (env, setEnv) = React.useState(() => None)
  let (cardField, setCardField) = React.useState(() => None)
  let (expiryField, setExpiryField) = React.useState(() => None)
  let (cvcField, setCVCField) = React.useState(() => None)

  let setUserError = message => {
    Utils.postFailedSubmitResponse(~errortype="validation_error", ~message)
  }

  VGSHelpers.useVGSEvents(
    cardField,
    expiryField,
    cvcField,
    setIsCardFocused,
    setIsExpiryFocused,
    setIsCVCFocused,
    setVgsCardError,
    setVgsExpiryError,
    setVgsCVCError,
  )

  let handleCard = (dict, ~isSubmit=false) => {
    let cardData = dict->Dict.get("card_number")->Option.flatMap(JSON.Decode.object)
    let isCardFocused = cardData->VGSHelpers.getBoolValueFromOptionalDict("isFocused")
    let isCardEmpty = cardData->VGSHelpers.getBoolValueFromOptionalDict("isEmpty")
    let isCardValid = cardData->VGSHelpers.getBoolValueFromOptionalDict("isValid")
    switch (isCardFocused, isCardEmpty, isCardValid, isSubmit) {
    | (false, true, _, true) => {
        setVgsCardError(_ => localeString.cardNumberEmptyText)
        setUserError(localeString.enterFieldsText)
      }
    | (false, false, false, _) => {
        setVgsCardError(_ => localeString.enterValidCardNumberErrorText)
        setUserError(localeString.enterValidDetailsText)
      }
    | _ => ()
    }
  }
  let handleExpiry = (dict, ~isSubmit=false) => {
    let expiryData = dict->Dict.get("card_exp")->Option.flatMap(JSON.Decode.object)
    let isExpiryFocused = expiryData->VGSHelpers.getBoolValueFromOptionalDict("isFocused")
    let isExpiryEmpty = expiryData->VGSHelpers.getBoolValueFromOptionalDict("isEmpty")
    let isExpiryValid = expiryData->VGSHelpers.getBoolValueFromOptionalDict("isValid")
    switch (isExpiryFocused, isExpiryEmpty, isExpiryValid, isSubmit) {
    | (false, true, _, true) => {
        setVgsExpiryError(_ => localeString.cardExpiryDateEmptyText)
        setUserError(localeString.enterFieldsText)
      }
    | (false, false, false, _) => {
        setVgsExpiryError(_ => localeString.inValidExpiryErrorText)
        setUserError(localeString.enterValidDetailsText)
      }
    | _ => ()
    }
  }
  let handleCVC = (dict, ~isSubmit=false) => {
    let cvcData = dict->Dict.get("card_cvc")->Option.flatMap(JSON.Decode.object)
    let isCvcFocused = cvcData->VGSHelpers.getBoolValueFromOptionalDict("isFocused")
    let isCvcEmpty = cvcData->VGSHelpers.getBoolValueFromOptionalDict("isEmpty")
    let isCvcValid = cvcData->VGSHelpers.getBoolValueFromOptionalDict("isValid")
    switch (isCvcFocused, isCvcEmpty, isCvcValid, isSubmit) {
    | (false, true, _, true) => {
        setVgsCVCError(_ => localeString.cvcNumberEmptyText)
        setUserError(localeString.enterFieldsText)
      }
    | (false, false, false, _) => {
        setVgsCVCError(_ => localeString.inValidCvcErrorText)
        setUserError(localeString.enterValidDetailsText)
      }
    | _ => ()
    }
  }

  let initializeVGS = (vault: VGSTypes.returnValue) => {
    let cardNumberOptions: VGSTypes.fieldOptions = {
      \"type": "card-number",
      name: "card_number",
      placeholder: "1234 1234 1234 1234",
      validations: ["required", "validCardNumber"],
      showCardIcon: true,
    }

    let cardExpiryOptions: VGSTypes.fieldOptions = {
      \"type": "card-expiration-date",
      name: "card_exp",
      placeholder: localeString.expiryPlaceholder,
      validations: ["required", "validCardExpirationDate"],
      showCardIcon: false,
    }

    let cardCvcOptions: VGSTypes.fieldOptions = {
      \"type": "card-security-code",
      name: "card_cvc",
      placeholder: "123",
      validations: ["required", "validCardSecurityCode"],
      showCardIcon: true,
    }

    setCardField(_ => Some(vault.field("#vgs-cc-number", cardNumberOptions)))
    setExpiryField(_ => Some(vault.field("#vgs-cc-expiry", cardExpiryOptions)))
    setCVCField(_ => Some(vault.field("#vgs-cc-cvc", cardCvcOptions)))

    setForm(_ => Some(vault))
  }

  let mountVGSSDK = () => {
    let vgsScriptURL = `https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js`
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
      let vault = VGSTypes.create(id->Option.getOr(""), env->Option.getOr(""), vgsState => {
        let dict = vgsState->Utils.getDictFromJson
        handleCard(dict)
        handleExpiry(dict)
        handleCVC(dict)
      })
      initializeVGS(vault)
    })
    Window.body->Window.appendChild(vgsScript)
  }

  React.useEffect(() => {
    let (vaultId, vaultEnv) = VaultHelpers.getVGSVaultDetails(
      ssn,
      vaultMode->VaultHelpers.getVaultNameFromMode,
    )
    setEnv(_ => vaultEnv)
    setId(_ => vaultId)
    None
  }, (ssn, vaultMode))

  React.useEffect(() => {
    if !vgsScriptLoaded && id->Option.isSome && env->Option.isSome {
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
            let (cardNumber, month, year, cvcNumber) = VGSHelpers.getTokenizedData(data)
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
            let dict = err->Utils.getDictFromJson
            handleCard(dict, ~isSubmit=true)
            handleExpiry(dict, ~isSubmit=true)
            handleCVC(dict, ~isSubmit=true)
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
        <VGSInputDiv
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
            <VGSInputDiv
              fieldName={localeString.validThruText}
              id="vgs-cc-expiry"
              isFocused={isExpiryFocused->Option.getOr(false)}
              errorStr=vgsExpiryError
            />
          </div>
          <div className={innerLayout === Spaced ? "w-[47%]" : "w-[50%]"}>
            <VGSInputDiv
              fieldName={localeString.cvcTextLabel}
              id="vgs-cc-cvc"
              isFocused={isCVCFocused->Option.getOr(false)}
              errorStr=vgsCVCError
            />
          </div>
        </div>
        <RenderIf condition={innerLayout === Compressed}>
          <div
            className="Error pt-1"
            style={
              color: themeObj.colorDangerText,
              fontSize: themeObj.fontSizeSm,
              alignSelf: "start",
              textAlign: "left",
            }>
            {React.string("Invalid input")}
          </div>
        </RenderIf>
      </div>
    </div>
  </div>
}

let default = make
