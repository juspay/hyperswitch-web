type target = {checked: bool}
type event = {target: target}

@react.component
let make = (
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~isBancontact=false,
  ~isVault=None,
) => {
  open PaymentType
  open PaymentModeType
  open Utils
  open UtilityHooks
  open PaymentTypeContext
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {innerLayout} = config.appearance
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let email = Recoil.useRecoilValueFromAtom(RecoilAtoms.userEmailAddress)
  let fullName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userFullName)
  let phoneNumber = Recoil.useRecoilValueFromAtom(RecoilAtoms.userPhoneNumber)
  let (isSaveDetailsWithClickToPay, setIsSaveDetailsWithClickToPay) = React.useState(_ => false)
  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let (clickToPayCardBrand, setClickToPayCardBrand) = React.useState(_ => "")
  let (isClickToPayRememberMe, setIsClickToPayRememberMe) = React.useState(_ => false)
  let ctpCards = clickToPayConfig.clickToPayCards->Option.getOr([])
  let nickname = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCardNickName)
  let {clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let paymentTypeFromUrl = componentName->CardThemeType.getPaymentMode
  let isPMMFlow = switch paymentTypeFromUrl {
  | PaymentMethodsManagement => true
  | _ => false
  }

  let paymentMethod = isBancontact ? "bank_redirect" : "card"
  let paymentMethodType = isBancontact ? "bancontact_card" : "debit"

  let paymentType = usePaymentType()
  let {isCardValid, isCardSupported, cardNumber, cardBrand} = cardProps

  let {isExpiryValid, cardExpiry} = expiryProps

  let {isCVCValid, cvcNumber} = cvcProps
  let {displaySavedPaymentMethodsCheckbox} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let saveCard = PaymentHelpersV2.useSaveCard(Some(loggerState), Card)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Recoil.useRecoilState(
    RecoilAtoms.showPaymentMethodsScreen,
  )
  let setComplete = Recoil.useSetRecoilState(RecoilAtoms.fieldsComplete)
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ => false)

  let {clickToPayProvider} = clickToPayConfig
  React.useEffect(() => {
    if (
      cardBrand === "" ||
        clickToPayConfig.availableCardBrands->Array.includes(cardBrand->String.toLowerCase)->not
    ) {
      setClickToPayCardBrand(_ => "")
    } else if cardBrand !== clickToPayCardBrand {
      setClickToPayCardBrand(_ => cardBrand)
    }
    None
  }, (cardBrand, clickToPayConfig.availableCardBrands))

  let combinedCardNetworks = React.useMemo1(() => {
    let cardPaymentMethod =
      paymentMethodListValue.payment_methods
      ->Array.find(ele => ele.payment_method === "card")
      ->Option.getOr(PaymentMethodsRecord.defaultMethods)

    let cardNetworks = cardPaymentMethod.payment_method_types->Array.map(ele => ele.card_networks)

    let cardNetworkNames =
      cardNetworks->Array.map(ele =>
        ele->Array.map(val => val.card_network->CardUtils.getCardStringFromType->String.toLowerCase)
      )

    cardNetworkNames
    ->Array.reduce([], (acc, ele) => acc->Array.concat(ele))
    ->Utils.getUniqueArray
  }, [paymentMethodListValue])
  let isCardBrandValid = combinedCardNetworks->Array.includes(cardBrand->String.toLowerCase)

  let (requiredFieldsBody, _) = React.useState(_ => Dict.make())

  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)

  let complete = isAllValid(
    isCardValid,
    isCardSupported,
    isCVCValid,
    isExpiryValid,
    true,
    "payment",
  )
  let empty = cardNumber == "" || cardExpiry == "" || cvcNumber == ""
  React.useEffect(() => {
    setComplete(_ => complete)
    setShowPaymentMethodsScreen(_ => true)
    None
  }, [complete])

  useHandlePostMessages(~complete=complete && areRequiredFieldsValid, ~empty, ~paymentType="card")

  let isGuestCustomer = useIsGuestCustomer()

  let isCustomerAcceptanceRequired = useIsCustomerAcceptanceRequired(
    ~displaySavedPaymentMethodsCheckbox,
    ~isSaveCardsChecked,
    ~isGuestCustomer,
  )

  let isRecognizedClickToPayPayment = ctpCards->Array.length > 0
  let isUnrecognizedClickToPayPayment = isSaveDetailsWithClickToPay

  let isClickToPayFlow = isRecognizedClickToPayPayment || isUnrecognizedClickToPayPayment

  let clickToPayCustomFields = ClickToPayHelpers.clickToPayCustomFields(
    ~clickToPayProvider,
    ~localeString,
  )

  let submitCallback = React.useCallback(
    (ev: Window.event, formValuesWithInitialValues, values) => {
      let json = ev.data->safeParse
      let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
      let (month, year) = CardUtils.getExpiryDates(cardExpiry)

      let onSessionBody = [("customer_acceptance", PaymentBody.customerAcceptanceBody)]

      if confirm.doSubmit {
        let defaultCardBody = switch GlobalVars.sdkVersion {
        | V1 =>
          PaymentBody.cardPaymentBodySuperposition(
            ~nickname=nickname.value,
            ~formValuesWithInitialValues,
          )
        | V2 =>
          PaymentManagementBody.saveCardBodySuperposition(
            ~nickname=nickname.value,
            ~formValuesWithInitialValues,
          )
        }

        let banContactBody = PaymentBody.bancontactBody()
        let cardBody = if isCustomerAcceptanceRequired {
          defaultCardBody->Array.concat(onSessionBody)
        } else {
          defaultCardBody
        }

        let isNicknameValid = nickname.value === "" || nickname.isValid->Option.getOr(false)

        let validFormat = isNicknameValid

        if validFormat && (showPaymentMethodsScreen || isBancontact) {
          if isClickToPayFlow {
            ClickToPayHelpers.handleOpenClickToPayWindow()

            switch clickToPayProvider {
            | MASTERCARD =>
              try {
                (
                  async () => {
                    Console.log2("Card,", values)
                    let res = await ClickToPayHelpers.encryptCardForClickToPay(
                      ~cardNumber=cardNumber->CardValidations.clearSpaces,
                      ~expiryMonth=month,
                      ~expiryYear=year->CardUtils.formatExpiryToTwoDigit,
                      ~cvcNumber,
                      ~logger=loggerState,
                    )

                    Console.log2("Encrypted card for Click to Pay", res)

                    // switch res {
                    // | Ok(res) => {
                    //     let resp = await ClickToPayHelpers.handleProceedToPay(
                    //       ~encryptedCard=res,
                    //       ~isCheckoutWithNewCard=true,
                    //       ~isUnrecognizedUser=ctpCards->Array.length == 0,
                    //       ~email=email.value,
                    //       ~phoneNumber=phoneNumber.value,
                    //       ~countryCode=phoneNumber.countryCode
                    //       ->Option.getOr("")
                    //       ->String.replace("+", ""),
                    //       ~rememberMe=isClickToPayRememberMe,
                    //       ~logger=loggerState,
                    //       ~clickToPayProvider,
                    //       ~clickToPayToken=clickToPayConfig.clickToPayToken,
                    //     )
                    //     let dict = resp.payload->Utils.getDictFromJson
                    //     let headers = dict->Utils.getDictFromDict("headers")
                    //     let merchantTransactionId =
                    //       headers->Utils.getString("merchant-transaction-id", "")
                    //     let xSrcFlowId = headers->Utils.getString("x-src-cx-flow-id", "")
                    //     let correlationId =
                    //       dict
                    //       ->Utils.getDictFromDict("checkoutResponseData")
                    //       ->Utils.getString("srcCorrelationId", "")

                    //     let clickToPayBody = PaymentBody.mastercardClickToPayBody(
                    //       ~merchantTransactionId,
                    //       ~correlationId,
                    //       ~xSrcFlowId,
                    //     )
                    //     // intent(
                    //     //   ~bodyArr=clickToPayBody->mergeAndFlattenToTuples(requiredFieldsBody),
                    //     //   ~confirmParam=confirm.confirmParams,
                    //     //   ~handleUserError=false,
                    //     //   ~manualRetry=isManualRetryEnabled,
                    //     // )
                    //   }
                    // | Error(err) =>
                    //   loggerState.setLogError(
                    //     ~value={
                    //       "message": `Error during checkout - ${err
                    //         ->Utils.formatException
                    //         ->JSON.stringify}`,
                    //       "scheme": clickToPayProvider,
                    //     }
                    //     ->JSON.stringifyAny
                    //     ->Option.getOr(""),
                    //     ~eventName=CLICK_TO_PAY_FLOW,
                    //   )
                    // }
                  }
                )()->ignore
              } catch {
              | err =>
                loggerState.setLogError(
                  ~value={
                    "message": `Error during checkout - ${err
                      ->Utils.formatException
                      ->JSON.stringify}`,
                    "scheme": clickToPayProvider,
                  }
                  ->JSON.stringifyAny
                  ->Option.getOr(""),
                  ~eventName=CLICK_TO_PAY_FLOW,
                )
              }

            | VISA => {
                let expiry = cardExpiry->String.split("/")->Array.map(String.trim)
                let month = expiry->Array.at(0)->Option.getOr("")
                let year = "20" ++ expiry->Array.at(1)->Option.getOr("")
                let payload = [
                  convertKeyValueToJsonStringPair(
                    "primaryAccountNumber",
                    cardNumber->String.replaceAll(" ", ""),
                  ),
                  convertKeyValueToJsonStringPair("panExpirationMonth", month),
                  convertKeyValueToJsonStringPair("panExpirationYear", year),
                  convertKeyValueToJsonStringPair("cardSecurityCode", cvcNumber->String.trim),
                  convertKeyValueToJsonStringPair("cardHolderName", fullName.value->String.trim),
                ]

                let dict = Dict.make()
                payload->Array.forEach(((key, value)) => Dict.set(dict, key, value))
                let cardPayloadJson = JSON.Encode.object(dict)
                Console.log2("Card payload json", cardPayloadJson)

                (
                  async () => {
                    let encryptedCard =
                      await cardPayloadJson->ClickToPayCardEncryption.getEncryptedCard
                    Console.log2("Encrypted card", encryptedCard)

                    try {
                      let res = await ClickToPayHelpers.handleProceedToPay(
                        ~visaEncryptedCard=encryptedCard,
                        ~isCheckoutWithNewCard=true,
                        ~isUnrecognizedUser=ctpCards->Array.length == 0,
                        ~email=email.value,
                        ~phoneNumber=phoneNumber.value,
                        ~countryCode=phoneNumber.countryCode
                        ->Option.getOr("")
                        ->String.replace("+", ""),
                        ~rememberMe=isClickToPayRememberMe,
                        ~logger=loggerState,
                        ~clickToPayProvider,
                        ~clickToPayToken=clickToPayConfig.clickToPayToken,
                        ~orderId=clientSecret->Option.getOr(""),
                        ~fullName=fullName.value,
                      )
                      let dict = res.payload->Utils.getDictFromJson
                      let clickToPayBody = PaymentBody.visaClickToPayBody(
                        ~email=clickToPayConfig.email,
                        ~encryptedPayload=dict->Utils.getString("checkoutResponse", ""),
                      )
                      intent(
                        ~bodyArr=clickToPayBody,
                        ~confirmParam=confirm.confirmParams,
                        ~handleUserError=false,
                        ~manualRetry=isManualRetryEnabled,
                      )
                    } catch {
                    | err =>
                      loggerState.setLogError(
                        ~value={
                          "message": `Error during checkout - ${err
                            ->Utils.formatException
                            ->JSON.stringify}`,
                          "scheme": clickToPayProvider,
                        }
                        ->JSON.stringifyAny
                        ->Option.getOr(""),
                        ~eventName=CLICK_TO_PAY_FLOW,
                      )
                    }
                  }
                )()->ignore
              }
            | NONE => ()
            }
          } else if isPMMFlow {
            saveCard(
              ~bodyArr=cardBody,
              ~confirmParam={
                return_url: options.sdkHandleSavePayment.confirmParams.return_url,
                publishableKey,
              },
              ~handleUserError=true,
            )
          } else {
            intent(
              ~bodyArr={
                isBancontact ? banContactBody : cardBody
              },
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        }
      }
    },
    (
      areRequiredFieldsValid,
      requiredFieldsBody,
      empty,
      complete,
      isCustomerAcceptanceRequired,
      nickname,
      isCardBrandValid,
      isManualRetryEnabled,
      cardProps,
      clickToPayConfig,
      clickToPayCardBrand,
      isClickToPayRememberMe,
    ),
  )

  let conditionsForShowingSaveCardCheckbox =
    paymentMethodListValue.mandate_payment->Option.isNone &&
    !isGuestCustomer &&
    paymentMethodListValue.payment_type !== SETUP_MANDATE &&
    options.displaySavedPaymentMethodsCheckbox &&
    !isBancontact

  let vaultClass = switch isVault {
  | Some(_) => "mb-[4px] mr-[4px] ml-[4px] mt-[4px]"
  | None => ""
  }

  <div className="animate-slowShow">
    <RenderIf condition={showPaymentMethodsScreen || isBancontact}>
      <div className={`flex flex-col ${vaultClass}`} style={gridGap: themeObj.spacingGridColumn}>
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
          <DynamicFieldsSuperposition
            paymentMethod
            paymentMethodType
            submitCallback
            customFields=clickToPayCustomFields
            showOnlyCustomFields={clickToPayProvider !== NONE}
          />
          <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
            <div className="flex items-center justify-start">
              <SaveDetailsCheckbox
                isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked
              />
            </div>
          </RenderIf>
          <RenderIf
            condition={(!options.hideCardNicknameField && isCustomerAcceptanceRequired) ||
              paymentType == PaymentMethodsManagement}>
            <NicknamePaymentInput />
          </RenderIf>
        </div>
      </div>
    </RenderIf>
    <RenderIf condition={showPaymentMethodsScreen || isBancontact}>
      <Surcharge paymentMethod paymentMethodType cardBrand={cardBrand->CardUtils.getCardType} />
    </RenderIf>
    <RenderIf condition={!isBancontact}>
      {switch (
        paymentMethodListValue.mandate_payment,
        options.terms.card,
        paymentMethodListValue.payment_type,
      ) {
      | (Some(_), Auto, NEW_MANDATE)
      | (Some(_), Auto, SETUP_MANDATE)
      | (_, Always, NEW_MANDATE)
      | (_, Always, SETUP_MANDATE)
      | (_, _, SETUP_MANDATE)
      | (_, _, NEW_MANDATE) =>
        <Terms
          mode={Card}
          styles={
            marginTop: themeObj.spacingGridColumn,
          }
        />
      | (_, _, _) => React.null
      }}
    </RenderIf>
    <RenderIf condition={clickToPayCardBrand !== ""}>
      <div className="space-y-3 mt-2">
        <ClickToPayHelpers.SrcMark cardBrands=clickToPayCardBrand height="32" />
        <ClickToPayDetails
          isSaveDetailsWithClickToPay
          setIsSaveDetailsWithClickToPay
          clickToPayCardBrand
          isClickToPayRememberMe
          setIsClickToPayRememberMe
        />
      </div>
    </RenderIf>
  </div>
}
