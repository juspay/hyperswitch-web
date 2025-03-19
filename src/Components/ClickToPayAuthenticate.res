open ClickToPayHelpers
open Promise
open Utils
type visaComponentState = CARDS_LOADING | CONSUMER_ID | OTP_INPUT | ERROR | NONE

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
  ~areClickToPayUIScriptsLoaded,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  //TODO - To be discussed
  let (_, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (isShowClickToPayNotYou, setIsShowClickToPayNotYou) = React.useState(_ => false)
  let (isCTPAuthenticateNotYouClicked, setIsCTPAuthenticateNotYouClicked) = React.useState(_ =>
    false
  )
  let (consumerIdentity, setConsumerIdentity) = React.useState(_ => {
    identityType: EMAIL_ADDRESS,
    identityValue: "",
  })
  let (visaComponentState, setVisaComponentState) = React.useState(_ => NONE)
  let (otpError, setOtpError) = React.useState(_ => "")
  let (maskedIdentity, setMaskedIdentity) = React.useState(_ => "")
  let closeComponentIfSavedMethodsAreEmpty = () => {
    if savedMethods->Array.length === 0 && loadSavedCards !== PaymentType.LoadingSavedCards {
      setShowFields(_ => true)
    }
  }

  let (clickToPayProvider, _) = Recoil.useRecoilState(RecoilAtoms.clickToPayProvider)

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

  let getCards = React.useCallback0(async (~otp="") => {
    Console.log("Geting Cards")

    let consumerIdentity = {
      identityProvider: "SRC",
      identityValue: "abhishek.c@juspay.in",
      identityType: EMAIL_ADDRESS,
    }
    let getCardsConfig = switch otp->String.length {
    | 6 => {consumerIdentity, validationData: otp}
    | _ => {consumerIdentity: consumerIdentity}
    }

    let cardsResult = await getCardsVisaUnified(~getCardsConfig)
    Console.log(cardsResult)
    switch cardsResult.actionCode {
    | SUCCESS => {
        let cards = switch cardsResult.profiles {
        | Some(profilesArray) =>
          switch profilesArray[0] {
          | Some(profile) => Some(profile.maskedCards)
          | None => None
          }
        | None => None
        }
        setVisaComponentState(_ => NONE)

        //TODO: handle the case when no cards were found

        let _ = setTimeout(() => {
          setClickToPayConfig(
            prev => {
              ...prev,
              clickToPayCards: cards,
            },
          )
        }, 800)
      }
    | PENDING_CONSUMER_IDV => {
        setVisaComponentState(_ => OTP_INPUT)
        setMaskedIdentity(_ => cardsResult.maskedValidationChannel->Option.getOr(""))
      }
    | FAILED
    | ERROR =>
      switch cardsResult.error {
      | Some(err) =>
        switch err.reason {
        | Some(reason) =>
          switch reason {
          | "VALIDATION_DATA_INVALID" => setOtpError(_ => "VALIDATION_DATA_INVALID")
          | "OTP_SEND_FAILED" =>
            //TODO: need to handle this casa properly

            {
              Console.log("OTP_SEND_FAILED")
            }

            ()
          | "ACCT_INACCESSIBLE" => //TODO: need to handle this casa properly
            ()
          | _ => setOtpError(_ => "NONE")
          }
        | None => ()
        }
      | None => ()
      }
    }
    ()
  })

  let initVisaUnified = async () => {
    Console.log("Visa script loaded")
    let initConfig = {
      dpaTransactionOptions: {
        dpaLocale: "en_US",
        transactionAmount: {
          transactionAmount: "10.00",
          transactionCurrencyCode: "USD",
        },
        merchantCountryCode: "US",
        merchantOrderId: "Merchant defined order ID",
      },
    }

    setVisaComponentState(_ => CARDS_LOADING)
    let _ = await vsdk.initialize(initConfig)
    let _ = await getCards()
  }

  React.useEffect(() => {
    if clickToPayConfig.email !== "" && consumerIdentity.identityValue === "" {
      setConsumerIdentity(_ => {
        identityType: EMAIL_ADDRESS,
        identityValue: clickToPayConfig.email,
      })
    }
    None
  }, [clickToPayConfig.email])

  React.useEffect(() => {
    if clickToPayConfig.isReady == Some(true) && clickToPayProvider == MASTERCARD {
      let fetchCards = async () => {
        let cardsResult = await ClickToPayHelpers.getCards(loggerState)
        switch cardsResult {
        | Ok(cards) =>
          setClickToPayConfig(prev => {
            ...prev,
            clickToPayCards: Some(cards),
          })
        | Error(_) => ()
        }
      }
      fetchCards()->ignore
    }
    None
  }, (clickToPayConfig.isReady, clickToPayProvider))

  React.useEffect(() => {
    if (
      clickToPayConfig.isReady == Some(true) &&
      clickToPayProvider == VISA &&
      areClickToPayUIScriptsLoaded
    ) {
      initVisaUnified()->ignore
      Console.log("INIT VISA HERE...")
      ()
    }
    None
  }, (clickToPayConfig.isReady, areClickToPayUIScriptsLoaded, clickToPayProvider))

  <>
    <RenderIf
      condition={clickToPayConfig.clickToPayCards->Option.getOr([])->Array.length == 0 &&
      !isClickToPayAuthenticateError &&
      clickToPayConfig.email !== ""}>
      <ClickToPayHelpers.SrcMark
        cardBrands={clickToPayConfig.availableCardBrands->Array.joinWith(",")} height="32"
      />
    </RenderIf>
    <div id="mastercard-account-verification" />
    <RenderIf condition={clickToPayProvider == VISA}>
      {switch visaComponentState {
      | CARDS_LOADING => <ClickToPayUiComponents.LoadingState />
      | CONSUMER_ID => <ClickToPayUiComponents.ConsumerIdInput />
      | OTP_INPUT =>
        <ClickToPayUiComponents.OtpInput
          getCards={otp => getCards(~otp)} otpError setOtpError maskedIdentity
        />
      | ERROR => <ClickToPayUiComponents.ErrorOccured />
      | NONE => React.null
      }}
    </RenderIf>
    {if isShowClickToPayNotYou {
      <ClickToPayNotYou
        setIsShowClickToPayNotYou isCTPAuthenticateNotYouClicked setConsumerIdentity
      />
    } else {
      switch clickToPayConfig.clickToPayCards {
      | Some(cards) =>
        switch cards->Array.length {
        | 0 => {
            mastercardAuth(cards)
            React.null
          }
        | _ =>
          <>
            <ClickToPayHelpers.SrcMark
              cardBrands={clickToPayConfig.availableCardBrands->Array.joinWith(",")} height="32"
            />
            <ClickToPayNotYou.ClickToPayNotYouText setIsShowClickToPayNotYou />
            {cards
            ->Array.mapWithIndex((obj, i) => {
              let customerMethod = obj->PaymentType.convertClickToPayCardToCustomerMethod
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
