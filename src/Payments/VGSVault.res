open Utils
open VGSTypes
open VGSHelpers
open VGSConstants

let submitVaultTokenization = (vault: returnValue, ~scope, ~onData) => {
  let startedAt = Date.now()
  let event = SdkLogger.VaultTokenization({scope: scope})
  let details = [("vault", "vgs"->JSON.Encode.string)]
  let paymentMethod = LoggerPaymentMethod.Card
  SdkLogger.logApi(~event, ~outcome=Started, ~details, ~paymentMethod)
  let onSuccess = (_, data) => {
    SdkLogger.logApi(~event, ~outcome=Done, ~details, ~startedAt, ~paymentMethod)
    onData(data)
  }
  let onError = err => {
    SdkLogger.logApi(
      ~event,
      ~outcome=Failed,
      ~details,
      ~startedAt,
      ~exn=err->Identity.anyTypeToJson,
      ~paymentMethod,
    )
    postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
  }
  vault.submit("/post", JSON.Encode.object(Dict.make()), onSuccess, onError)
}

@react.component
let make = (~cvcOnly=false) => {
  let vaultCredentials = Jotai.useAtomValue(JotaiAtoms.vaultCredentials)
  let {themeObj, localeString, config} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let {parentURL, iframeId} = Jotai.useAtomValue(JotaiAtoms.keys)
  let cardFlowType = Jotai.useAtomValue(JotaiAtoms.cardFlowType)
  let savedCardBrand = Jotai.useAtomValue(JotaiAtoms.savedCardBrand)->CardUtils.normalizeCardBrand
  let {innerLayout} = config.appearance
  let elementType = cardFlowType->CardThemeType.getPaymentModeToString

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

  let vgsScriptStatus = CommonHooks.useScript(
    vgsScriptURL,
    ~integrity=vgsScriptIntegrity,
    ~crossorigin="anonymous",
    ~resourceEvent=SdkLogger.VaultScript,
  )

  let vaultInitializedRef = React.useRef(false)

  let formStateRef = React.useRef(Dict.make())
  let savedCvcStatusRef = React.useRef(None)

  let emitSavedCardCvcStatus = (~dict, ~error) => {
    let cvcState =
      dict
      ->Dict.get("card_cvc")
      ->Option.flatMap(JSON.Decode.object)
      ->Option.getOr(Dict.make())
    let empty = cvcState->getBool("isEmpty", true)
    let valid = cvcState->getBool("isValid", false)
    savedCvcStatusRef.current = Some((empty, valid, valid))
    let status =
      [
        ("empty", empty->JSON.Encode.bool),
        ("complete", valid->JSON.Encode.bool),
        ("valid", valid->JSON.Encode.bool),
        ("error", error->JSON.Encode.string),
      ]->Dict.fromArray
    messageParentWindow(
      [("savedCardCvcStatus", status->JSON.Encode.object)],
      ~targetOrigin=parentURL,
    )
  }

  React.useEffect(() => {
    handleVGSField(
      cardField,
      setIsCardFocused,
      setVgsCardError,
      () => Utils.handleOnFocusPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL),
      () => Utils.handleOnBlurPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL),
    )
    None
  }, [cardField])
  React.useEffect(() => {
    handleVGSField(
      expiryField,
      setIsExpiryFocused,
      setVgsExpiryError,
      () => Utils.handleOnFocusPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL),
      () => Utils.handleOnBlurPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL),
    )
    None
  }, [expiryField])
  React.useEffect(() => {
    handleVGSField(
      cvcField,
      setIsCVCFocused,
      setVgsCVCError,
      () => Utils.handleOnFocusPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL),
      () => Utils.handleOnBlurPostMessage(~iframeId, ~elementType, ~targetOrigin=parentURL),
    )
    None
  }, [cvcField])

  React.useEffect(() => {
    if cvcOnly {
      cvcField->Option.forEach(field =>
        field.update({validations: savedCardCvcValidations(savedCardBrand)})
      )
    }
    None
  }, (cvcOnly, cvcField, savedCardBrand))

  let initializeVGSFields = (vault: returnValue) => {
    if !cvcOnly {
      setCardField(_ => Some(vault.field("#vgs-cc-number", cardNumberOptions)))
      setExpiryField(_ => Some(
        vault.field("#vgs-cc-expiry", cardExpiryOptions(localeString.expiryPlaceholder)),
      ))
    }

    setCVCField(_ => Some(
      vault.field("#vgs-cc-cvc", cvcOnly ? savedCardCvcOptions(savedCardBrand) : cardCvcOptions),
    ))
    setForm(_ => Some(vault))
  }

  let handleVGSErrors = vgsState => {
    let dict = vgsState->getDictFromJson
    formStateRef.current = dict

    let fieldState = fieldName =>
      dict
      ->Dict.get(fieldName)
      ->Option.flatMap(JSON.Decode.object)
      ->Option.getOr(Dict.make())
    if cvcOnly {
      emitSavedCardCvcStatus(~dict, ~error=vgsErrorHandler(dict, "card_cvc", localeString))
    } else {
      let hasCardState = dict->Dict.get("card_number")->Option.isSome
      let hasExpiryState = dict->Dict.get("card_exp")->Option.isSome
      let hasCvcState = dict->Dict.get("card_cvc")->Option.isSome
      let cardState = fieldState("card_number")
      let expiryState = fieldState("card_exp")
      let cvcState = fieldState("card_cvc")
      let cardValid = cardState->getBool("isValid", false)
      let expiryValid = expiryState->getBool("isValid", false)
      let cvcValid = cvcState->getBool("isValid", false)
      let empty =
        cardState->getBool("isEmpty", true) ||
        expiryState->getBool("isEmpty", true) ||
        cvcState->getBool("isEmpty", true)
      let status =
        [
          ("complete", (cardValid && expiryValid && cvcValid)->JSON.Encode.bool),
          ("empty", empty->JSON.Encode.bool),
          ("isCvcEmpty", cvcState->getBool("isEmpty", true)->JSON.Encode.bool),
          ("isCvcComplete", cvcValid->JSON.Encode.bool),
          ("isCardValid", cardValid->JSON.Encode.bool),
          ("isExpiryValid", expiryValid->JSON.Encode.bool),
          ("isCvcValid", cvcValid->JSON.Encode.bool),
          ("hasCardValidationStatus", hasCardState->JSON.Encode.bool),
          ("hasExpiryValidationStatus", hasExpiryState->JSON.Encode.bool),
          ("hasCvcValidationStatus", hasCvcState->JSON.Encode.bool),
        ]->Dict.fromArray
      messageParentWindow(
        [("cardFieldStatus", status->JSON.Encode.object)],
        ~targetOrigin=parentURL,
      )
    }

    let setIfPresent = (setError, errStr) =>
      if errStr != "" {
        setError(_ => errStr)
      }
    setIfPresent(setVgsCardError, vgsErrorHandler(dict, "card_number", localeString))
    setIfPresent(setVgsExpiryError, vgsErrorHandler(dict, "card_exp", localeString))
    setIfPresent(setVgsCVCError, vgsErrorHandler(dict, "card_cvc", localeString))
  }

  React.useEffect(() => {
    if cvcOnly {
      switch savedCvcStatusRef.current {
      | Some((empty, complete, valid)) =>
        let status =
          [
            ("empty", empty->JSON.Encode.bool),
            ("complete", complete->JSON.Encode.bool),
            ("valid", valid->JSON.Encode.bool),
            ("error", vgsCVCError->JSON.Encode.string),
          ]->Dict.fromArray
        messageParentWindow(
          [("savedCardCvcStatus", status->JSON.Encode.object)],
          ~targetOrigin=parentURL,
        )
      | None => ()
      }
    }
    None
  }, (cvcOnly, vgsCVCError, parentURL))

  React.useEffect(() => {
    switch vgsScriptStatus {
    | "ready" =>
      if vaultId != "" && environment != "" && !vaultInitializedRef.current {
        vaultInitializedRef.current = true
        let vault = create(vaultId, environment, handleVGSErrors)
        initializeVGSFields(vault)
      }
    | "error" =>
      messageParentWindow(
        [("vgsScriptLoadFailed", true->JSON.Encode.bool)],
        ~targetOrigin=parentURL,
      )
    | _ => ()
    }
    None
  }, (vaultId, environment, vgsScriptStatus))

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirmDict = json->getDictFromJson
    let confirm = confirmDict->ConfirmType.itemToObjMapper
    let isOuterValid = confirmDict->getBool("isOuterValid", true)

    if confirm.doSubmit {
      switch form {
      | Some(vault) =>
        let stateDict = formStateRef.current
        if cvcOnly {
          let cvcErr = vgsErrorHandler(stateDict, "card_cvc", ~isSubmit=true, localeString)
          setVgsCVCError(_ => cvcErr)
          emitSavedCardCvcStatus(~dict=stateDict, ~error=cvcErr)
          if cvcErr == "" && isOuterValid {
            vault->submitVaultTokenization(~scope=SaveCardCvc, ~onData=data => {
              let cvcToken = data->getDictFromJson->getString("card_cvc", "")
              messageParentWindow(
                [
                  ("savedCardCvcTokenEvent", true->JSON.Encode.bool),
                  ("cvcToken", cvcToken->JSON.Encode.string),
                ],
                ~targetOrigin=parentURL,
              )
            })
          } else if cvcErr != "" {
            submitUserError(
              isFieldEmpty(stateDict, "card_cvc")
                ? localeString.enterFieldsText
                : localeString.enterValidDetailsText,
            )
          }
        } else {
          let cardErr = vgsErrorHandler(stateDict, "card_number", ~isSubmit=true, localeString)
          let expiryErr = vgsErrorHandler(stateDict, "card_exp", ~isSubmit=true, localeString)
          let cvcErr = vgsErrorHandler(stateDict, "card_cvc", ~isSubmit=true, localeString)
          setVgsCardError(_ => cardErr)
          setVgsExpiryError(_ => expiryErr)
          setVgsCVCError(_ => cvcErr)

          let cardFieldsValid = cardErr == "" && expiryErr == "" && cvcErr == ""

          if cardFieldsValid && isOuterValid {
            vault->submitVaultTokenization(~scope=FullCard, ~onData=data => {
              let (cardNumber, month, year, cvcNumber) = getTokenizedData(data)
              messageParentWindow(
                [
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
                ],
                ~targetOrigin=parentURL,
              )
            })
          } else if !cardFieldsValid {
            let anyEmpty =
              isFieldEmpty(stateDict, "card_number") ||
              isFieldEmpty(stateDict, "card_exp") ||
              isFieldEmpty(stateDict, "card_cvc")
            submitUserError(
              anyEmpty ? localeString.enterFieldsText : localeString.enterValidDetailsText,
            )
          }
        }

      | None =>
        SdkLogger.logLifecycle(
          ~event=VaultFlowFailed({reason: FormCreationFailed}),
          ~details=[("vault", "vgs"->JSON.Encode.string)],
        )
        Console.error("VGS Vault not initialized for submission")
      }
    }
  }, (form, localeString, cvcOnly, parentURL))

  useSubmitPaymentDataFromParent(submitCallback, ~parentOrigin=parentURL)

  <div className="animate-slowShow">
    <div className="flex flex-col" style={gridGap: themeObj.spacingGridColumn}>
      {if cvcOnly {
        <div className="flex flex-col w-full" style={gridGap: themeObj.spacingGridColumn}>
          <VGSInputComponent
            fieldName=""
            id="vgs-cc-cvc"
            isFocused={isCVCFocused->Option.getOr(false)}
            compact=true
            height=SavedCardCvcStyles.fieldHeight
          />
        </div>
      } else {
        <div className="flex flex-col w-full" style={gridGap: themeObj.spacingGridColumn}>
          <RenderIf condition={innerLayout === Compressed}>
            <div
              style={
                marginBottom: "5px",
                fontSize: themeObj.fontSizeLg,
                opacity: "0.6",
              }
            >
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
            }
          >
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
      }}
    </div>
  </div>
}

let default = make
