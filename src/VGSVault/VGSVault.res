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
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)

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
  let (vgsEnv, setVgsEnv) = React.useState(() => "")

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let status = CommonHooks.useScript(vgsScriptURL)

  handleVGSField(cardField, setIsCardFocused, setVgsCardError)
  handleVGSField(expiryField, setIsExpiryFocused, setVgsExpiryError)
  handleVGSField(cvcField, setIsCVCFocused, setVgsCVCError)

  let initializeVGSFields = (vault: vgsCollect) => {
    setCardField(_ => Some(vault.field("#vgs-cc-number", cardNumberOptions)))
    setExpiryField(_ => Some(
      vault.field(
        "#vgs-cc-expiry",
        cardExpiryOptions(~expiryPlaceholder=localeString.expiryPlaceholder, ~vault),
      ),
    ))
    setCVCField(_ => Some(vault.field("#vgs-cc-cvc", cardCvcOptions)))
    setForm(_ => Some(vault))
  }

  let handleVGSErrors = vgsState => {
    let dict = vgsState->getDictFromJson
    setVgsCardError(_ => vgsErrorHandler(dict, "card_number", localeString))
    setVgsExpiryError(_ => vgsErrorHandler(dict, "card_exp", localeString))
    setVgsCVCError(_ => vgsErrorHandler(dict, "card_cvc", localeString))
  }

  React.useEffect(() => {
    let {vaultId, vaultEnv} = VaultHelpers.getVGSVaultDetails(
      sessionToken,
      vaultMode->VaultHelpers.getVaultNameFromMode,
    )
    setVgsEnv(_ => vaultEnv)
    setId(_ => vaultId)
    None
  }, (sessionToken, vaultMode))

  React.useEffect(() => {
    if status == "ready" && id != "" && vgsEnv != "" {
      let vault = create(id, vgsEnv, handleVGSErrors)
      initializeVGSFields(vault)
    }
    None
  }, (id, vgsEnv, status))

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      switch form {
      | Some(vault) =>
        let emptyPayload = JSON.Encode.object(Dict.make())

        let onSuccess = (_, data) => {
          let (cardNumber, month, year, cvcNumber) = getTokenizedData(data)

          let cardBody = PaymentManagementBody.vgsCardBody(~cardNumber, ~month, ~year, ~cvcNumber)
          if areRequiredFieldsValid && !areRequiredFieldsEmpty {
            intent(
              ~bodyArr={cardBody->mergeAndFlattenToTuples(requiredFieldsBody)},
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
              ~isExternalVaultFlow=true,
            )
          } else {
            postFailedSubmitResponse(
              ~errortype="validation_error",
              ~message=localeString.enterValidDetailsText,
            )
          }
        }

        let onError = err => {
          let errorDict = err->getDictFromJson
          setVgsCardError(_ =>
            vgsErrorHandler(errorDict, "card_number", ~isSubmit=true, localeString)
          )
          setVgsExpiryError(_ =>
            vgsErrorHandler(errorDict, "card_exp", ~isSubmit=true, localeString)
          )
          setVgsCVCError(_ => vgsErrorHandler(errorDict, "card_cvc", ~isSubmit=true, localeString))
        }

        vault.submit("/post", emptyPayload, onSuccess, onError)

      | None => Console.error("VGS Vault not initialized for submission")
      }
    }
  }, (form, requiredFieldsBody, areRequiredFieldsValid, areRequiredFieldsEmpty))

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
        <DynamicFields paymentMethod="card" paymentMethodType="credit" setRequiredFieldsBody />
      </div>
    </div>
  </div>
}

let default = make
