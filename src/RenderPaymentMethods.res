open RecoilAtoms
open Utils
@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~zipProps: CardUtils.zipProps,
  ~handleElementFocus,
  ~blurState,
  ~isFocus,
) => {
  let {showLoader} = Recoil.useRecoilValueFromAtom(configAtom)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {
    isCardValid,
    setIsCardValid,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    maxCardLength,
  } = cardProps

  let {
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
  } = expiryProps

  let {isCVCValid, setIsCVCValid, cvcNumber, changeCVCNumber, handleCVCBlur, cvcRef} = cvcProps

  let keys = Recoil.useRecoilValueFromAtom(keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(RecoilAtoms.redirectionFlagsAtom)
  let (cvcErrorMessage, setCvcErrorMessage) = React.useState(_ => "")

  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.elementOptions)
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

              let cardBrandFromMessage = confirmParamsDict->getString("cardBrand", "")

              let isCvcComplete = CardUtils.checkCardCVC(cvcNumber, cardBrandFromMessage)

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
                  messageParentWindow([
                    ("cvcWidgetConfirmResponse", response),
                    ("success", true->JSON.Encode.bool),
                  ])
                  resolve()
                })
                ->catch(err => {
                  messageParentWindow([
                    (
                      "cvcWidgetConfirmResponse",
                      err->formatException->JSON.stringify->JSON.Encode.string,
                    ),
                    ("success", false->JSON.Encode.bool),
                  ])
                  resolve()
                })
                ->ignore
              } else if requiresCvv {
                let isEmptyCVC = cvcNumber->String.length == 0
                let cardPatternObj = CardValidations.getobjFromCardPattern(cardBrandFromMessage)
                let isTooLong = cvcNumber->String.length > cardPatternObj.maxCVCLength
                let errorMsg = if isEmptyCVC {
                  localeString.cvcNumberEmptyText
                } else if isTooLong {
                  localeString.cvcTooLongErrorText(cardPatternObj.maxCVCLength)
                } else {
                  localeString.inCompleteCVCErrorText
                }

                setCvcErrorMessage(_ => errorMsg)

                let failedResponseMsg = if isEmptyCVC {
                  localeString.enterFieldsText
                } else {
                  localeString.enterValidDetailsText
                }
                postFailedSubmitResponse(~errortype="validation_error", ~message=failedResponseMsg)

                messageParentWindow([
                  ("cvcWidgetConfirmResponse", errorMsg->JSON.Encode.string),
                  ("success", false->JSON.Encode.bool),
                ])
              } else {
                messageParentWindow([
                  ("cvcWidgetConfirmResponse", JSON.Encode.null),
                  ("success", true->JSON.Encode.bool),
                ])
              }
            }
          }
        | None => ()
        }
      } catch {
      | _ => ()
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
    let handleCheckCVCWidgetPresent = (ev: Window.event) => {
      let json = ev.data->safeParse
      try {
        let dict = json->getDictFromJson
        if dict->Dict.get("checkCVCWidgetPresent")->Option.isSome {
          if paymentType === CardCVCElement {
            messageParentWindow([("cvcWidgetPresent", true->JSON.Encode.bool)])
          }
        }
      } catch {
      | _ => ()
      }
    }
    Window.addEventListener("message", handleCheckCVCWidgetPresent)
    Some(
      () => {
        Window.removeEventListener("message", handleCheckCVCWidgetPresent)
      },
    )
  })

  let blur = blurState ? "blur(2px)" : ""
  let frameRef = React.useRef(Nullable.null)
  <div
    className={`flex flex-col justify-between PaymentMethodContainer`}
    style={
      color: themeObj.colorText,
      background: "transparent",
      marginLeft: "4px",
      marginRight: "4px",
      marginTop: "4px",
      fontFamily: themeObj.fontFamily,
      fontSize: themeObj.fontSizeBase,
      filter: blur,
    }
    dir=localeString.localeDirection>
    <div
      ref={frameRef->ReactDOM.Ref.domRef}
      className={`m-auto flex justify-center md:h-auto  w-full h-auto `}>
      <div className="w-full font-medium">
        {switch paymentType {
        | Card =>
          <ReusableReactSuspense
            loaderComponent={<RenderIf condition={showLoader}>
              <CardElementShimmer />
            </RenderIf>}
            componentName="SingleLineCardPaymentLazy">
            <SingleLineCardPaymentLazy
              paymentType cardProps expiryProps cvcProps zipProps handleElementFocus isFocus
            />
          </ReusableReactSuspense>
        | GooglePayElement
        | PayPalElement
        | ApplePayElement
        | SamsungPayElement
        | KlarnaElement
        | PazeElement
        | ExpressCheckoutElement
        | Payment =>
          <ReusableReactSuspense
            loaderComponent={<RenderIf condition={showLoader}>
              {paymentType->Utils.checkIsWalletElement
                ? <WalletShimmer />
                : <PaymentElementShimmer />}
            </RenderIf>}
            componentName="PaymentElementRendererLazy">
            <PaymentElementRendererLazy paymentType cardProps expiryProps cvcProps />
          </ReusableReactSuspense>
        | CardNumberElement =>
          <InputField
            isValid=isCardValid
            setIsValid=setIsCardValid
            value=cardNumber
            onChange=changeCardNumber
            onBlur=handleCardBlur
            onFocus=handleElementFocus
            type_="tel"
            maxLength=maxCardLength
            inputRef=cardRef
            placeholder="1234 1234 1234 1234"
            id="card-number"
            isFocus
            autocomplete="cc-number"
          />
        | CardExpiryElement =>
          <InputField
            isValid=isExpiryValid
            setIsValid=setIsExpiryValid
            value=cardExpiry
            onChange=changeCardExpiry
            onBlur=handleExpiryBlur
            onFocus=handleElementFocus
            type_="tel"
            maxLength=7
            inputRef=expiryRef
            placeholder=localeString.expiryPlaceholder
            id="card-expiry"
            isFocus
            autocomplete="cc-exp"
          />
        | CardCVCElement =>
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
            placeholder={options.placeholder === ""
              ? localeString.cvcTextLabel
              : options.placeholder}
            id="card-cvc"
            isFocus
            autocomplete="cc-csc"
            errorString=displayErrorMessage
            errorStringClasses="text-xs text-red-950"
          />
        | PaymentMethodsManagement =>
          <ReusableReactSuspense
            loaderComponent={<RenderIf condition={showLoader}>
              <PaymentElementShimmer />
            </RenderIf>}
            componentName="PaymentManagementLazy">
            <PaymentManagementLazy paymentType cardProps cvcProps expiryProps />
          </ReusableReactSuspense>
        | PaymentMethodCollectElement
        | NONE => React.null
        }}
      </div>
    </div>
  </div>
}
