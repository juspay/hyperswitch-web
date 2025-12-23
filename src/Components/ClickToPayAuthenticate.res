open ClickToPayHelpers
open Promise
open Utils

@react.component
let make = (
  ~loggerState,
  ~savedMethods,
  ~isClickToPayAuthenticateError,
  ~setIsClickToPayAuthenticateError,
  ~setPaymentToken,
  ~paymentTokenVal,
  ~cvcProps,
  ~getVisaCards,
  ~setIsClickToPayRememberMe,
  ~closeComponentIfSavedMethodsAreEmpty,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  let setShowPaymentMethodsScreen = Recoil.useSetRecoilState(RecoilAtoms.showPaymentMethodsScreen)
  let (_, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (_, setAreRequiredFieldsValid) = React.useState(_ => true)
  let (_, setAreRequiredFieldsEmpty) = React.useState(_ => false)
  let (isShowClickToPayNotYou, setIsShowClickToPayNotYou) = React.useState(_ => false)
  let (isCTPAuthenticateNotYouClicked, setIsCTPAuthenticateNotYouClicked) = React.useState(_ =>
    false
  )

  let {
    consumerIdentity,
    clickToPayCards,
    email,
    availableCardBrands,
    visaComponentState,
    clickToPayProvider,
  } = clickToPayConfig

  let ctpCards = clickToPayCards->Option.getOr([])

  let mastercardAuth = cards => {
    if cards->Array.length == 0 {
      if !isClickToPayAuthenticateError && email !== "" {
        let iframe = CommonHooks.createElement("iframe")
        iframe.id = "mastercard-account-verification-iframe"
        iframe.width = "100%"
        iframe.height = "410px"
        let element = ClickToPayHelpers.getElementById(
          Window.myDocument,
          "mastercard-account-verification",
        )
        try {
          switch element->Nullable.toOption {
          | Some(ele) =>
            if ele.children->Array.length === 0 {
              ele.appendChild(iframe)
              switch iframe.contentWindow {
              | Some(iframeContentWindow) => {
                  let authenticateConsumerIdentity = {
                    identityType: consumerIdentity.identityType,
                    identityValue: consumerIdentity.identityValue->String.replaceAll(" ", ""),
                  }
                  let authenticatePayload: ClickToPayHelpers.authenticateInputPayload = {
                    windowRef: iframeContentWindow,
                    consumerIdentity: authenticateConsumerIdentity,
                  }
                  ClickToPayHelpers.authenticate(authenticatePayload, loggerState)
                  ->then(res => {
                    switch res {
                    | Ok(data) =>
                      let cards =
                        data
                        ->getDictFromJson
                        ->getJsonFromDict("cards", JSON.Encode.null)
                        ->JSON.Decode.array
                        ->Option.flatMap(arr => Some(
                          arr->Array.map(ClickToPayHelpers.clickToPayCardItemToObjMapper),
                        ))
                        ->Option.getOr([])
                      setClickToPayConfig(prev => {
                        ...prev,
                        clickToPayCards: Some(cards),
                      })
                      ele.replaceChildren()
                      if cards->Array.length === 0 {
                        setIsClickToPayAuthenticateError(_ => true)
                      }
                      if cards->Array.length === 0 && savedMethods->Array.length === 0 {
                        setShowPaymentMethodsScreen(_ => true)
                      }
                      resolve()
                    | Error(err) => {
                        let errException = err->formatException
                        loggerState.setLogError(
                          ~value={
                            "message": `Error authenticating consumer identity - ${errException->JSON.stringify}`,
                            "scheme": clickToPayProvider,
                          }
                          ->JSON.stringifyAny
                          ->Option.getOr(""),
                          ~eventName=CLICK_TO_PAY_FLOW,
                        )
                        let exceptionMessage =
                          errException
                          ->getDictFromJson
                          ->getJsonFromDict("message", JSON.Encode.null)
                          ->JSON.Decode.string
                          ->Option.getOr("")

                        let isNotYouClicked = exceptionMessage->String.includes("Not you clicked")

                        if isNotYouClicked {
                          setIsCTPAuthenticateNotYouClicked(_ => true)
                          setIsShowClickToPayNotYou(_ => true)
                        } else {
                          setIsClickToPayAuthenticateError(_ => true)
                        }

                        ele.replaceChildren()

                        resolve()
                      }
                    }
                  })
                  ->catch(err => {
                    loggerState.setLogError(
                      ~value={
                        "message": `Error authenticating consumer identity - ${err
                          ->formatException
                          ->JSON.stringify}`,
                        "scheme": clickToPayProvider,
                      }
                      ->JSON.stringifyAny
                      ->Option.getOr(""),
                      ~eventName=CLICK_TO_PAY_FLOW,
                    )
                    closeComponentIfSavedMethodsAreEmpty()
                    resolve()
                  })
                  ->ignore
                }
              | None => closeComponentIfSavedMethodsAreEmpty()
              }
            }
          | None => ()
          }
        } catch {
        | err => {
            loggerState.setLogError(
              ~value={
                "message": `Error - ${err->formatException->JSON.stringify}`,
                "scheme": clickToPayProvider,
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
            closeComponentIfSavedMethodsAreEmpty()
          }
        }
      } else if isClickToPayAuthenticateError {
        closeComponentIfSavedMethodsAreEmpty()
      }
    }
  }

  let switchCtpAuthenticate = switch clickToPayProvider {
  | MASTERCARD =>
    if !(clickToPayCards->Option.isNone) {
      mastercardAuth(ctpCards)
    }
    <div id="mastercard-account-verification" />
  | VISA =>
    switch visaComponentState {
    | CARDS_LOADING => <ClickToPayUiComponents.LoadingState />
    | OTP_INPUT =>
      <>
        <ClickToPayNotYou.ClickToPayNotYouText setIsShowClickToPayNotYou />
        <div className="h-4 w-1" />
        <ClickToPayUiComponents.OtpInput
          getCards={otp => {
            (
              async _ => {
                await getVisaCards(
                  ~identityValue=consumerIdentity.identityValue,
                  ~otp,
                  ~identityType=consumerIdentity.identityType,
                )
              }
            )()
          }}
          setIsClickToPayRememberMe
        />
      </>
    | NONE => React.null
    }
  | NONE => React.null
  }

  let ctpCardList =
    <>
      <ClickToPayNotYou.ClickToPayNotYouText setIsShowClickToPayNotYou />
      {ctpCards
      ->Array.mapWithIndex((obj, i) => {
        let customerMethod =
          obj->PaymentType.convertClickToPayCardToCustomerMethod(clickToPayProvider)
        <SavedCardItem
          key={"ctp_" ++ i->Int.toString}
          setPaymentToken
          isActive={paymentTokenVal == customerMethod.paymentToken}
          paymentItem=customerMethod
          brandIcon={customerMethod->CardUtils.getPaymentMethodBrand}
          index=i
          savedCardlength={ctpCards->Array.length}
          cvcProps
          setRequiredFieldsBody
          setAreRequiredFieldsValid
          setAreRequiredFieldsEmpty
        />
      })
      ->React.array}
    </>

  <>
    <RenderIf condition={!isClickToPayAuthenticateError && email !== ""}>
      <ClickToPayHelpers.SrcMark cardBrands={availableCardBrands->Array.join(",")} height="32" />
    </RenderIf>
    {if isShowClickToPayNotYou {
      <ClickToPayNotYou setIsShowClickToPayNotYou isCTPAuthenticateNotYouClicked getVisaCards />
    } else if ctpCards->Array.length == 0 {
      switchCtpAuthenticate
    } else {
      ctpCardList
    }}
  </>
}
