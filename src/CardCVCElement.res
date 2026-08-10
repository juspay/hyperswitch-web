open JotaiAtoms
open Utils

// `isSavedCardCvcFlow` reuses this CVC element for the unified saved-card
// (return user) flow. The single submit handler below has two mutually-exclusive
// paths:
//   • default (Elements CVC widget): listens for `requestCVCConfirm` and confirms
//     the payment-session intent itself with the entered CVC.
//   • saved-card flow: listens for the forwarded doSubmit and returns either the
//     raw CVC (non-vault) or a tokenised CVC (vault) to SavedMethods, which remains
//     the submit owner.
@react.component
let make = (
  ~cvcProps: CardUtils.cvcProps,
  ~paymentType: CardThemeType.mode,
  ~isSavedCardCvcFlow=false,
  ~isVaultCvcFlow=false,
  ~savedCardBrand="",
) => {
  let {config, localeString} = Jotai.useAtomValue(configAtom)
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  let {innerLayout} = config.appearance
  let keys = Jotai.useAtomValue(keys)
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let redirectionFlags = Jotai.useAtomValue(JotaiAtoms.redirectionFlagsAtom)
  // Vault credentials (pmSessionId / sdkAuthorization) for the saved-card tokenise
  // call; populated by PaymentMethodsSDK in the inner iframe. Only used in vault mode.
  let vaultCredentials = Jotai.useAtomValue(JotaiAtoms.vaultCredentials)

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
  let savedCardBrand = savedCardBrand->CardUtils.normalizeCardBrand
  let isCvcEmpty = cvcNumber === ""
  let isCvcComplete = isSavedCardCvcFlow
    ? CardUtils.checkCardCVC(cvcNumber, savedCardBrand)
    : cvcNumber->String.length >= 3
  let maxCvcLength = isSavedCardCvcFlow
    ? CardValidations.getobjFromCardPattern(savedCardBrand).maxCVCLength
    : 4
  let compressedLayoutStyleForCvcError =
    !isSavedCardCvcFlow && innerLayout === Compressed && cvcError->String.length > 0
      ? "!border-l-0"
      : ""

  // Single submit handler for both modes:
  //   • saved-card flow: SavedMethods forwards doSubmit (carrying the selected
  //     payment_token). Validation happens here; non-vault flows return the raw CVC,
  //     while vault flows tokenise it first.
  //   • Elements CVC widget: confirms the payment-session intent itself on the
  //     `requestCVCConfirm` message, posting the response back to the parent window.
  let submitCallback = React.useCallback((ev: Window.event) => {
    open Promise
    if isSavedCardCvcFlow {
      let confirmDict = ev.data->safeParse->getDictFromJson
      let confirm = confirmDict->ConfirmType.itemToObjMapper
      let isOuterValid = confirmDict->getBool("isOuterValid", true)

      if confirm.doSubmit {
        let isCvcValid = isCVCValid->Option.getOr(false)

        if isCvcValid && isOuterValid {
          setCvcError(_ => "")
          if isVaultCvcFlow {
            let (pmSessionId, sdkAuthorization) = switch vaultCredentials {
            | HyperswitchVault(creds) => (creds.pmSessionId, creds.sdkAuthorization)
            | _ => ("", "")
            }
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
                messageParentWindow(
                  [
                    ("savedCardCvcTokenEvent", true->JSON.Encode.bool),
                    ("cvcToken", vaultTokenData.token->JSON.Encode.string),
                  ],
                  ~targetOrigin=keys.parentURL,
                )
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
          } else {
            messageParentWindow(
              [
                ("savedCardCvcDataEvent", true->JSON.Encode.bool),
                ("cvcNumber", cvcNumber->JSON.Encode.string),
              ],
              ~targetOrigin=keys.parentURL,
            )
          }
        } else if !isCvcValid {
          let errorMsg =
            cvcNumber->String.length == 0
              ? localeString.cvcNumberEmptyText
              : localeString.inCompleteCVCErrorText
          setCvcError(_ => errorMsg)
          if isOuterValid {
            postFailedSubmitResponse(~errortype="validation_error", ~message=errorMsg)
          }
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
    isSavedCardCvcFlow,
    isVaultCvcFlow,
    isCVCValid,
    cvcNumber,
    keys,
    paymentType,
    loggerState,
    customPodUri,
    redirectionFlags,
    localeString,
    vaultCredentials,
  ))
  useSubmitPaymentDataFromParent(submitCallback, ~parentOrigin=keys.parentURL)

  React.useEffect(() => {
    SubscriptionEventHooks.emitReady(
      ~iframeId=keys.iframeId,
      ~elementType=CardThemeType.getPaymentModeToString(paymentType),
    )
    None
  }, (keys.iframeId, paymentType))

  React.useEffect(() => {
    if !isSavedCardCvcFlow {
      let cvcInfoDict = [("isCvcEmpty", isCvcEmpty->JSON.Encode.bool)]->Dict.fromArray
      Utils.messageParentWindow([("cvcInfo", cvcInfoDict->JSON.Encode.object)])
    }
    None
  }, [isCvcEmpty])

  React.useEffect(() => {
    if isSavedCardCvcFlow {
      let status =
        [
          ("empty", isCvcEmpty->JSON.Encode.bool),
          ("complete", isCVCValid->Option.getOr(false)->JSON.Encode.bool),
          ("valid", isCVCValid->Option.getOr(false)->JSON.Encode.bool),
          ("error", cvcError->JSON.Encode.string),
        ]->Dict.fromArray
      Utils.messageParentWindow(
        [("savedCardCvcStatus", status->JSON.Encode.object)],
        ~targetOrigin=keys.parentURL,
      )
    }
    None
  }, (isSavedCardCvcFlow, isCvcEmpty, isCvcComplete, isCVCValid, cvcError, keys.parentURL))

  React.useEffect(() => {
    if !isSavedCardCvcFlow {
      emitter.emitCvcStatus(~iframeId=keys.iframeId, ~isCvcEmpty, ~isCvcComplete)
    }
    None
  }, (isSavedCardCvcFlow, isCvcEmpty, isCvcComplete, keys.iframeId))

  React.useEffect(() => {
    if isSavedCardCvcFlow {
      cvcRef.current
      ->Nullable.toOption
      ->Option.forEach(input => input->CardUtils.focus)
      ->ignore
    }
    None
  }, [isSavedCardCvcFlow])

  <PaymentInputField
    fieldName={isSavedCardCvcFlow ? "" : localeString.cvcTextLabel}
    isValid=isCVCValid
    setIsValid=setIsCVCValid
    value=cvcNumber
    onChange=changeCVCNumber
    onBlur=handleCVCBlur
    errorString={isSavedCardCvcFlow ? "" : cvcError}
    type_="tel"
    className={`tracking-widest w-full ${compressedLayoutStyleForCvcError}`}
    maxLength=maxCvcLength
    inputRef=cvcRef
    placeholder="123"
    height={isSavedCardCvcFlow ? "1.8rem" : ""}
    name=TestUtils.cardCVVInputTestId
    autocomplete="cc-csc"
  />
}
