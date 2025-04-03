open ClickToPayHelpers
open Promise
open Utils

@react.component
let make = (
  ~consumerIdentity,
  ~loggerState,
  ~savedMethods,
  ~setShowFields,
  ~setIsCTPAuthenticateNotYouClicked,
  ~setIsShowClickToPayNotYou,
  ~isClickToPayAuthenticateError,
  ~setIsClickToPayAuthenticateError,
  ~loadSavedCards,
  ~setPaymentToken,
  ~paymentTokenVal,
  ~cvcProps,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  //TODO - To be discussed
  let (_, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let closeComponentIfSavedMethodsAreEmpty = () => {
    if savedMethods->Array.length === 0 && loadSavedCards !== PaymentType.LoadingSavedCards {
      setShowFields(_ => true)
    }
  }

  <>
    {switch clickToPayConfig.clickToPayCards {
    | Some(cards) =>
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
        React.null
      } else {
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
              setRequiredFieldsBody
            />
          })
          ->React.array}
        </>
      }
    | None =>
      loggerState.setLogInfo(~value="Click to Pay cards not found", ~eventName=CLICK_TO_PAY_FLOW)
      React.null
    }}
  </>
}
