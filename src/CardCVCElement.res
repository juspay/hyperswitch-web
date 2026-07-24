open RecoilAtoms
open Utils

// `isVaultCvcFlow` reuses this CVC element for the Hyperswitch-vault saved-card
// (return user) flow. The single submit handler below has two mutually-exclusive
// paths:
//   • default (Elements CVC widget): listens for `requestCVCConfirm` and confirms
//     the payment-session intent itself with the entered CVC.
//   • vault saved-card flow: listens for the forwarded doSubmit, tokenises the CVC
//     through the payment-method-session update call, and posts `savedCardCvcTokenEvent`
//     back to SavedMethods, which owns the confirm (mirrors the VGS saved-card flow).
@react.component
let make = (
  ~cvcProps: CardUtils.cvcProps,
  ~paymentType: CardThemeType.mode,
  ~isVaultCvcFlow=false,
) => {
  let {config, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  let {innerLayout} = config.appearance
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(RecoilAtoms.redirectionFlagsAtom)
  // Vault credentials (pmSessionId / sdkAuthorization) for the saved-card tokenise
  // call; populated by PaymentMethodsSDK in the inner iframe. Only used in vault mode.
  let vaultCredentials = Recoil.useRecoilValueFromAtom(RecoilAtoms.vaultCredentials)

  let {
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    cvcError,
    setCvcError,
  } = cvcProps
  let isCvcEmpty = cvcNumber === ""
  let isCvcComplete = cvcNumber->String.length >= 3
  let compressedLayoutStyleForCvcError =
    innerLayout === Compressed && cvcError->String.length > 0 ? "!border-l-0" : ""

  // Single submit handler for both modes (mutually exclusive on `isVaultCvcFlow`):
  //   • vault saved-card flow: SavedMethods forwards the validated doSubmit (carrying
  //     the selected card's payment_token); we tokenise the CVC via the
  //     payment-method-session update call and post the token back as
  //     `savedCardCvcTokenEvent`. SavedMethods builds the vault_card_token_data confirm
  //     body and calls intent. Validation / tokenisation failures post a failed-submit
  //     response, which SavedMethods forwards to Hyper.res to reject confirmPayment().
  //   • Elements CVC widget: confirms the payment-session intent itself on the
  //     `requestCVCConfirm` message, posting the response back to the parent window.
  let submitCallback = React.useCallback((ev: Window.event) => {
    open Promise
    if isVaultCvcFlow {
      let confirmDict = ev.data->safeParse->getDictFromJson
      let confirm = confirmDict->ConfirmType.itemToObjMapper
      let isOuterValid = confirmDict->getBool("isOuterValid", true)

      if confirm.doSubmit {
        let paymentMethodToken = confirmDict->getString("paymentToken", "")
        let (pmSessionId, sdkAuthorization) = switch vaultCredentials {
        | HyperswitchVault(creds) => (creds.pmSessionId, creds.sdkAuthorization)
        | _ => ("", "")
        }
        let isCvcComplete = cvcNumber->String.length >= 3

        if isCvcComplete && isOuterValid {
          setCvcError(_ => "")
          PaymentHelpersV2.updatePaymentMethod(
            ~bodyArr=PaymentManagementBody.vaultUpdateCVVBody(~cvcNumber),
            ~pmSessionId,
            ~logger=loggerState,
            ~customPodUri,
            ~sdkAuthorization,
          )
          ->then(res => {
            let vaultTokenData = VaultHelpers.decodeVaultTokenData(res)
            if vaultTokenData.token !== "" {
              messageParentWindow([
                ("savedCardCvcTokenEvent", true->JSON.Encode.bool),
                ("cvcToken", vaultTokenData.token->JSON.Encode.string),
              ])
            } else {
              postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
            }
            resolve()
          })
          ->catch(_ => {
            postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
            resolve()
          })
          ->ignore
        } else if isOuterValid {
          // Only the CVC is invalid/empty (outer fields are validated upstream).
          let errorMsg =
            cvcNumber->String.length == 0
              ? localeString.cvcNumberEmptyText
              : localeString.inCompleteCVCErrorText
          setCvcError(_ => errorMsg)
          postFailedSubmitResponse(~errortype="validation_error", ~message=errorMsg)
        }
      }
    } else {
      let json = ev.data->safeParse
      try {
        let dict = json->getDictFromJson
        switch dict->Dict.get("requestCVCConfirm") {
        | Some(confirmParams) => {
            let confirmParamsDict = confirmParams->getDictFromJson
            let requiresCvv = confirmParamsDict->getBool("requiresCvv", true)
            if paymentType === CardCVCElement {
              let body = confirmParamsDict->getJsonObjectFromDict("body")
              let bodyArr = body->JSON.Decode.object->Option.getOr(Dict.make())->Dict.toArray
              let payload = confirmParamsDict->getJsonFromDict("payload", JSON.Encode.null)
              let paymentTypeStr = confirmParamsDict->getString("paymentType", "card")
              let publishableKeyVal =
                confirmParamsDict->getString("publishableKey", keys.publishableKey)
              let clientSecretVal =
                confirmParamsDict->getString("clientSecret", keys.clientSecret->Option.getOr(""))

              let isCvcComplete = cvcNumber->String.length >= 3
              if requiresCvv && isCvcComplete {
                setCvcError(_ => "")

                let bodyWithCvc = bodyArr->Array.concat([PaymentBody.cardTokenCvcTuple(~cvcNumber)])

                let paymentType = paymentTypeStr->PaymentHelpers.getPaymentType

                PaymentHelpers.paymentIntentForPaymentSession(
                  ~body=bodyWithCvc,
                  ~paymentType,
                  ~payload,
                  ~publishableKey=publishableKeyVal,
                  ~clientSecret=clientSecretVal,
                  ~logger=loggerState,
                  ~customPodUri,
                  ~redirectionFlags,
                  ~sdkAuthorization=keys.sdkAuthorization,
                  ~mode=CardCVCElement,
                )
                ->then(response => {
                  messageParentWindow([("cvcWidgetConfirmResponse", response)])
                  resolve()
                })
                ->catch(err => {
                  messageParentWindow([
                    (
                      "cvcWidgetConfirmErrorResponse",
                      err->formatException->JSON.stringify->JSON.Encode.string,
                    ),
                  ])
                  resolve()
                })
                ->ignore
              } else if requiresCvv {
                // Future improvement: We can check if the CVC entered is more than 3 digits and show an appropriate error message. For now, we are just checking if it's less than 3 digits.
                let isEmptyCVC = cvcNumber->String.length == 0

                let errorMsg = if isEmptyCVC {
                  localeString.cvcNumberEmptyText
                } else {
                  localeString.inCompleteCVCErrorText
                }

                setCvcError(_ => errorMsg)

                messageParentWindow([
                  (
                    "cvcWidgetConfirmErrorResponse",
                    handleFailureResponse(~message=errorMsg, ~errorType="cvc_validation_failed"),
                  ),
                ])
              } else {
                messageParentWindow([
                  (
                    "cvcWidgetConfirmErrorResponse",
                    handleFailureResponse(
                      ~message="Something went wrong",
                      ~errorType="cvc_validation_failed",
                    ),
                  ),
                ])
              }
            }
          }
        | None => ()
        }
      } catch {
      | _ =>
        messageParentWindow([
          (
            "cvcWidgetConfirmErrorResponse",
            handleFailureResponse(
              ~message="Something went wrong",
              ~errorType="cvc_validation_failed",
            ),
          ),
        ])
      }
    }
  }, (
    isVaultCvcFlow,
    cvcNumber,
    keys,
    paymentType,
    loggerState,
    customPodUri,
    redirectionFlags,
    localeString,
    vaultCredentials,
  ))
  useSubmitPaymentData(submitCallback)

  React.useEffect(() => {
    SubscriptionEventHooks.emitReady(
      ~iframeId=keys.iframeId,
      ~elementType=CardThemeType.getPaymentModeToString(paymentType),
    )
    None
  }, (keys.iframeId, paymentType))

  React.useEffect(() => {
    if !isVaultCvcFlow {
      let cvcInfoDict = [("isCvcEmpty", isCvcEmpty->JSON.Encode.bool)]->Dict.fromArray
      Utils.messageParentWindow([("cvcInfo", cvcInfoDict->JSON.Encode.object)])
    }
    None
  }, [isCvcEmpty])
  React.useEffect(() => {
    emitter.emitCvcStatus(~iframeId=keys.iframeId, ~isCvcEmpty, ~isCvcComplete)
    None
  }, (isCvcEmpty, isCvcComplete, keys.iframeId))

  <PaymentInputField
    fieldName={isVaultCvcFlow ? "" : localeString.cvcTextLabel}
    isValid=isCVCValid
    setIsValid=setIsCVCValid
    value=cvcNumber
    onChange=changeCVCNumber
    onBlur=handleCVCBlur
    errorString=cvcError
    type_="tel"
    className={`tracking-widest w-full ${compressedLayoutStyleForCvcError}`}
    maxLength=4
    inputRef=cvcRef
    placeholder="123"
    height={isVaultCvcFlow ? "1.8rem" : ""}
    name=TestUtils.cardCVVInputTestId
    autocomplete="cc-csc"
  />
}
