open ClickToPayHelpers
open Promise
open Utils

@react.component
let make = (
  ~loggerState,
  ~savedMethods,
  ~setShowFields,
  ~isClickToPayAuthenticateError,
  ~setIsClickToPayAuthenticateError,
  ~loadSavedCards,
  ~setPaymentToken,
  ~paymentTokenVal,
  ~cvcProps,
  ~paymentType,
  ~getVisaCards: (
    ~identityValue: string=?,
    ~otp: string=?,
    ~identityType: ClickToPayHelpers.identityType=?,
  ) => promise<unit>,
  ~visaComponentState,
  ~otpError,
  ~setOtpError,
  ~maskedIdentity,
  ~consumerIdentity,
  ~setConsumerIdentity,
  ~setClickToPayRememberMe,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  //TODO - To be discussed
  let (_, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (isShowClickToPayNotYou, setIsShowClickToPayNotYou) = React.useState(_ => false)
  let (isCTPAuthenticateNotYouClicked, setIsCTPAuthenticateNotYouClicked) = React.useState(_ =>
    false
  )

  let closeComponentIfSavedMethodsAreEmpty = () => {
    if savedMethods->Array.length === 0 && loadSavedCards !== PaymentType.LoadingSavedCards {
      setShowFields(_ => true)
    }
  }

  let (clickToPayProvider, _) = Recoil.useRecoilState(RecoilAtoms.clickToPayProvider)
  let ctpCards = clickToPayConfig.clickToPayCards->Option.getOr([])
  let mastercardAuth = cards => {
    if cards->Array.length == 0 {
      if !isClickToPayAuthenticateError && clickToPayConfig.email !== "" {
        let iframe = CommonHooks.createElement("iframe")
        iframe.id = "mastercard-account-verification-iframe"
        iframe.width = "100%"
        iframe.height = "410px"
        let element = ClickToPayHelpers.getElementById(
          ClickToPayHelpers.myDocument,
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
                  Console.log(authenticateConsumerIdentity)
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
                        setShowFields(_ => true)
                      }
                      resolve()
                    | Error(err) => {
                        let errException = err->formatException

                        loggerState.setLogError(
                          ~value=`Error authenticating consumer identity - ${errException->JSON.stringify}`,
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
                      ~value=`Error authenticating consumer identity - ${err
                        ->formatException
                        ->JSON.stringify}`,
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
              ~value=`Error - ${err->formatException->JSON.stringify}`,
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

  <>
    <RenderIf
      condition={ctpCards->Array.length == 0 &&
      !isClickToPayAuthenticateError &&
      clickToPayConfig.email !== ""}>
      <ClickToPayHelpers.SrcMark
        cardBrands={clickToPayConfig.availableCardBrands->Array.joinWith(",")} height="32"
      />
    </RenderIf>
    <div id="mastercard-account-verification" />
    <RenderIf condition={clickToPayProvider == VISA && ctpCards->Array.length == 0}>
      {switch visaComponentState {
      | CARDS_LOADING => <ClickToPayUiComponents.LoadingState />
      | OTP_INPUT =>
        <ClickToPayUiComponents.OtpInput
          getCards={otp => getVisaCards(~identityValue=consumerIdentity.identityValue, ~otp)}
          otpError
          setOtpError
          maskedIdentity
          setClickToPayRememberMe
        />
      | ERROR => <ClickToPayUiComponents.ErrorOccured />
      | NONE => React.null
      }}
    </RenderIf>
    {if isShowClickToPayNotYou {
      <ClickToPayNotYou
        setIsShowClickToPayNotYou
        isCTPAuthenticateNotYouClicked
        setConsumerIdentity
        getVisaCards={(~identityValue, ~identityType) =>
          getVisaCards(~identityValue, ~identityType)->ignore}
      />
    } else {
      switch clickToPayConfig.clickToPayCards {
      | Some(cards) =>
        switch cards->Array.length {
        | 0 =>
          switch clickToPayProvider {
          | MASTERCARD =>
            mastercardAuth(cards)
            React.null
          | VISA => React.null
          | NONE => React.null
          }
        | _ =>
          <>
            <ClickToPayHelpers.SrcMark
              cardBrands={clickToPayConfig.availableCardBrands->Array.joinWith(",")} height="32"
            />
            <ClickToPayNotYou.ClickToPayNotYouText setIsShowClickToPayNotYou />
            {cards
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
                savedCardlength={cards->Array.length}
                cvcProps
                paymentType
                setRequiredFieldsBody
              />
            })
            ->React.array}
          </>
        }
      | None => {
          loggerState.setLogInfo(
            ~value="Click to Pay cards not found",
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          React.null
        }
      }
    }}
  </>
}
