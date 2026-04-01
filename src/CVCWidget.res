open RecoilAtoms
open Utils

@react.component
let make = (
  ~cvcProps: CardUtils.cvcProps,
  ~paymentType: CardThemeType.mode,
  ~handleElementFocus,
  ~isFocus,
) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(RecoilAtoms.redirectionFlagsAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.elementOptions)
  let (cvcErrorMessage, setCvcErrorMessage) = React.useState(_ => "")

  let {isCVCValid, setIsCVCValid, cvcNumber, changeCVCNumber, handleCVCBlur, cvcRef} = cvcProps

  let displayErrorMessage = if options.showError {
    cvcErrorMessage
  } else {
    ""
  }

  React.useEffect(() => {
    open Promise
    let handleRequestCVCConfirm = (ev: Window.event) => {
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
                setCvcErrorMessage(_ => "")

                let bodyWithCvc =
                  bodyArr->Array.concat([("card_cvc", cvcNumber->JSON.Encode.string)])

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
                  ~isPaymentSession=false,
                )
                ->then(response => {
                  messageParentWindow([("cvcWidgetConfirmResponse", response)])
                  resolve()
                })
                ->catch(err => {
                  messageParentWindow([
                    (
                      "cvcWidgetConfirmResponse",
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

                setCvcErrorMessage(_ => errorMsg)

                messageParentWindow([
                  (
                    "cvcWidgetConfirmResponse",
                    handleFailureResponse(~message=errorMsg, ~errorType="CVC validation failed"),
                  ),
                ])
              } else {
                messageParentWindow([
                  (
                    "cvcWidgetConfirmResponse",
                    handleFailureResponse(
                      ~message="Something went wrong",
                      ~errorType="CVC validation failed",
                    ),
                  ),
                ])
              }
            }
          }
        | None =>
          messageParentWindow([
            (
              "cvcWidgetConfirmResponse",
              handleFailureResponse(
                ~message="Something went wrong",
                ~errorType="CVC validation failed",
              ),
            ),
          ])
        }
      } catch {
      | _ =>
        messageParentWindow([
          (
            "cvcWidgetConfirmResponse",
            handleFailureResponse(
              ~message="Something went wrong",
              ~errorType="CVC validation failed",
            ),
          ),
        ])
      }
    }
    Window.addEventListener("message", handleRequestCVCConfirm)
    Some(
      () => {
        Window.removeEventListener("message", handleRequestCVCConfirm)
      },
    )
  }, [cvcNumber])

  React.useEffect0(() => {
    messageParentWindow([
      ("ready", true->JSON.Encode.bool),
      ("elementType", CardThemeType.getPaymentModeToString(paymentType)->JSON.Encode.string),
    ])
    None
  })

  React.useEffect(() => {
    let isCvcEmpty = cvcNumber->String.length == 0
    PaymentUtils.emitPaymentMethodInfo(
      ~paymentMethod="card",
      ~paymentMethodType="cvc",
      ~isCVCCardElement=true,
      ~isCvcEmpty,
    )
    None
  }, [cvcNumber])

  <InputField
    isValid=isCVCValid
    setIsValid=setIsCVCValid
    value=cvcNumber
    onChange=changeCVCNumber
    onBlur=handleCVCBlur
    onFocus=handleElementFocus
    type_="tel"
    className={`tracking-widest w-auto`}
    maxLength=4
    inputRef=cvcRef
    placeholder={options.placeholder === "" ? localeString.cvcTextLabel : options.placeholder}
    id="card-cvc"
    isFocus
    autocomplete="cc-csc"
    errorString=displayErrorMessage
    errorStringClasses="text-xs text-red-950"
  />
}
