open PaymentType
open RecoilAtoms

let cardsToRender = (width: int) => {
  let minWidth = 130
  let noOfCards = (width - 40) / minWidth
  noOfCards
}
@react.component
let make = (
  ~cardProps,
  ~expiryProps,
  ~cvcProps,
  ~countryProps,
  ~paymentType: CardThemeType.mode,
) => {
  let sessionsObj = Recoil.useRecoilValueFromAtom(sessions)
  let {
    showCardFormByDefault,
    paymentMethodOrder,
    layout,
    customerPaymentMethods,
    displaySavedPaymentMethods,
  } = Recoil.useRecoilValueFromAtom(optionAtom)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let optionAtomValue = Recoil.useRecoilValueFromAtom(optionAtom)
  let isApplePayReady = Recoil.useRecoilValueFromAtom(isApplePayReady)
  let isGooglePayReady = Recoil.useRecoilValueFromAtom(isGooglePayReady)
  let methodslist = Recoil.useRecoilValueFromAtom(list)
  let paymentOrder = paymentMethodOrder->Utils.getOptionalArr->Utils.removeDuplicate
  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (paymentOptions, setPaymentOptions) = React.useState(_ => [])
  let (walletOptions, setWalletOptions) = React.useState(_ => [])
  let {sdkHandleConfirmPayment} = Recoil.useRecoilValueFromAtom(optionAtom)

  let (list, setList) = React.useState(_ => PaymentMethodsRecord.defaultList)
  let (cardsContainerWidth, setCardsContainerWidth) = React.useState(_ => 0)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)
  let (dropDownOptions: array<string>, setDropDownOptions) = React.useState(_ => [])
  let (cardOptions: array<string>, setCardOptions) = React.useState(_ => [])
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isShowOrPayUsing = Recoil.useRecoilValueFromAtom(isShowOrPayUsing)

  let (showFields, setShowFields) = Recoil.useRecoilState(showCardFieldsAtom)
  let (paymentToken, setPaymentToken) = Recoil.useRecoilState(paymentTokenAtom)
  let (savedMethods, setSavedMethods) = React.useState(_ => [])
  let (
    loadSavedCards: PaymentType.savedCardsLoadState,
    setLoadSavedCards: (PaymentType.savedCardsLoadState => PaymentType.savedCardsLoadState) => unit,
  ) = React.useState(_ => PaymentType.LoadingSavedCards)

  React.useEffect(() => {
    switch (displaySavedPaymentMethods, customerPaymentMethods) {
    | (false, _) => {
        setShowFields(_ => true)
        setLoadSavedCards(_ => LoadedSavedCards([], true))
      }
    | (_, LoadingSavedCards) => ()
    | (_, LoadedSavedCards(savedPaymentMethods, isGuestCustomer)) => {
        let defaultPaymentMethod =
          savedPaymentMethods->Array.find(savedCard => savedCard.defaultPaymentMethodSet)

        let savedCardsWithoutDefaultPaymentMethod = savedPaymentMethods->Array.filter(savedCard => {
          !savedCard.defaultPaymentMethodSet
        })

        let finalSavedPaymentMethods = switch defaultPaymentMethod {
        | Some(defaultPaymentMethod) =>
          [defaultPaymentMethod]->Array.concat(savedCardsWithoutDefaultPaymentMethod)
        | None => savedCardsWithoutDefaultPaymentMethod
        }

        setSavedMethods(_ => finalSavedPaymentMethods)
        setLoadSavedCards(_ =>
          finalSavedPaymentMethods->Array.length == 0
            ? NoResult(isGuestCustomer)
            : LoadedSavedCards(finalSavedPaymentMethods, isGuestCustomer)
        )
        setShowFields(prev => finalSavedPaymentMethods->Array.length == 0 || prev)
      }
    | (_, NoResult(isGuestCustomer)) => {
        setLoadSavedCards(_ => NoResult(isGuestCustomer))
        setShowFields(_ => true)
      }
    }

    None
  }, (customerPaymentMethods, displaySavedPaymentMethods))

  React.useEffect(() => {
    let defaultPaymentMethod =
      savedMethods->Array.find(savedMethod => savedMethod.defaultPaymentMethodSet)

    let isSavedMethodsEmpty = savedMethods->Array.length === 0

    let tokenObj = switch (isSavedMethodsEmpty, defaultPaymentMethod) {
    | (false, Some(defaultPaymentMethod)) => Some(defaultPaymentMethod)
    | (false, None) => Some(savedMethods->Array.get(0)->Option.getOr(defaultCustomerMethods))
    | _ => None
    }

    switch tokenObj {
    | Some(obj) => setPaymentToken(_ => (obj.paymentToken, obj.customerId))
    | None => ()
    }
    None
  }, [savedMethods])

  let areAllGooglePayRequiredFieldsPrefilled = DynamicFieldsUtils.useAreAllRequiredFieldsPrefilled(
    ~list,
    ~paymentMethod="wallet",
    ~paymentMethodType="google_pay",
  )

  let areAllApplePayRequiredFieldsPrefilled = DynamicFieldsUtils.useAreAllRequiredFieldsPrefilled(
    ~list,
    ~paymentMethod="wallet",
    ~paymentMethodType="apple_pay",
  )

  let (walletList, paymentOptionsList, actualList) = React.useMemo6(() => {
    switch methodslist {
    | Loaded(paymentlist) =>
      let paymentOrder =
        paymentOrder->Array.length > 0 ? paymentOrder : PaymentModeType.defaultOrder
      let plist = paymentlist->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper
      let (wallets, otherOptions) =
        plist->PaymentUtils.paymentListLookupNew(
          ~order=paymentOrder,
          ~showApplePay=isApplePayReady,
          ~showGooglePay=isGooglePayReady,
          ~areAllGooglePayRequiredFieldsPrefilled,
          ~areAllApplePayRequiredFieldsPrefilled,
        )
      (
        wallets->Utils.removeDuplicate,
        paymentOptions->Array.concat(otherOptions)->Utils.removeDuplicate,
        otherOptions,
      )
    | SemiLoaded =>
      showCardFormByDefault && Utils.checkPriorityList(paymentMethodOrder)
        ? ([], ["card"], [])
        : ([], [], [])
    | _ => ([], [], [])
    }
  }, (
    methodslist,
    paymentMethodOrder,
    isApplePayReady,
    isGooglePayReady,
    areAllGooglePayRequiredFieldsPrefilled,
    areAllApplePayRequiredFieldsPrefilled,
  ))

  React.useEffect(() => {
    switch methodslist {
    | Loaded(paymentlist) =>
      let plist = paymentlist->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper

      setPaymentOptions(_ => {
        paymentOptionsList
      })
      setWalletOptions(_ => walletList)
      setList(_ => plist)
      showCardFormByDefault
        ? if !(actualList->Array.includes(selectedOption)) && selectedOption !== "" {
            ErrorUtils.manageErrorWarning(
              SDK_CONNECTOR_WARNING,
              ~dynamicStr="Please enable Card Payment in the dashboard, or 'ShowCard.FormByDefault' to false.",
              ~logger=loggerState,
              (),
            )
          } else if !Utils.checkPriorityList(paymentMethodOrder) {
            ErrorUtils.manageErrorWarning(
              SDK_CONNECTOR_WARNING,
              ~dynamicStr=`'paymentMethodOrder' is ${Array.joinWith(
                  paymentMethodOrder->Utils.getOptionalArr,
                  ", ",
                )} . Please enable Card Payment as 1st priority to show it as default.`,
              ~logger=loggerState,
              (),
            )
          }
        : ()
    | LoadError(_)
    | SemiLoaded =>
      setPaymentOptions(_ =>
        showCardFormByDefault && Utils.checkPriorityList(paymentMethodOrder) ? ["card"] : []
      )
    | _ => ()
    }
    None
  }, (methodslist, walletList, paymentOptionsList, actualList))
  React.useEffect(() => {
    switch sessionsObj {
    | Loaded(ssn) => setSessions(_ => ssn)
    | _ => ()
    }
    None
  }, [sessionsObj])
  React.useEffect(() => {
    let cardsCount: int = cardsToRender(cardsContainerWidth)
    let cardOpts = Array.slice(~start=0, ~end=cardsCount, paymentOptions)
    let dropOpts = paymentOptions->Array.sliceToEnd(~start=cardsCount)
    let isCard: bool = cardOpts->Array.includes(selectedOption)
    if !isCard && selectedOption !== "" && paymentOptions->Array.includes(selectedOption) {
      let (cardArr, dropdownArr) = CardUtils.swapCardOption(cardOpts, dropOpts, selectedOption)
      setCardOptions(_ => cardArr)
      setDropDownOptions(_ => dropdownArr)
    } else {
      setCardOptions(_ => cardOpts)
      setDropDownOptions(_ => dropOpts)
    }
    None
  }, (cardsContainerWidth, paymentOptions))
  let cardShimmerCount = React.useMemo1(() => {
    cardsToRender(cardsContainerWidth)
  }, [cardsContainerWidth])
  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit && selectedOption == "" {
      Utils.postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message="Select a payment method",
      )
    }
  }, [selectedOption])
  Utils.useSubmitPaymentData(submitCallback)
  React.useEffect(() => {
    setSelectedOption(prev =>
      selectedOption !== ""
        ? prev
        : layoutClass.defaultCollapsed
        ? ""
        : switch methodslist {
          | SemiLoaded
          | LoadError(_) =>
            showCardFormByDefault && Utils.checkPriorityList(paymentMethodOrder) ? "card" : ""
          | Loaded(_) =>
            paymentOptions->Array.includes(selectedOption) && showCardFormByDefault
              ? selectedOption
              : paymentOptions->Array.get(0)->Option.getOr("")
          | _ => paymentOptions->Array.get(0)->Option.getOr("")
          }
    )
    None
  }, (layoutClass.defaultCollapsed, paymentOptions, methodslist, selectedOption))
  React.useEffect(() => {
    if layoutClass.\"type" == Tabs {
      let isCard: bool = cardOptions->Array.includes(selectedOption)
      if !isCard {
        let (cardArr, dropdownArr) = CardUtils.swapCardOption(
          cardOptions,
          dropDownOptions,
          selectedOption,
        )
        setCardOptions(_ => cardArr)
        setDropDownOptions(_ => dropdownArr)
      }
    }
    if selectedOption !== "" {
      loggerState.setLogInfo(
        ~value="",
        ~eventName=PAYMENT_METHOD_CHANGED,
        ~paymentMethod=selectedOption->String.toUpperCase,
        (),
      )
    }
    None
  }, [selectedOption])
  let checkRenderOrComp = () => {
    walletOptions->Array.includes("paypal") || isShowOrPayUsing
  }
  let dict = sessions->Utils.getDictFromJson
  let sessionObj = SessionsType.itemToObjMapper(dict, Others)
  let applePaySessionObj = SessionsType.itemToObjMapper(dict, ApplePayObject)
  let applePayToken = SessionsType.getPaymentSessionObj(applePaySessionObj.sessionsToken, ApplePay)
  let klarnaTokenObj = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Klarna)
  let gPayToken = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Gpay)
  let googlePayThirdPartySessionObj = SessionsType.itemToObjMapper(dict, GooglePayThirdPartyObject)
  let googlePayThirdPartyToken = SessionsType.getPaymentSessionObj(
    googlePayThirdPartySessionObj.sessionsToken,
    Gpay,
  )

  let loader = () => {
    Utils.handlePostMessageEvents(
      ~complete=false,
      ~empty=false,
      ~paymentType=selectedOption,
      ~loggerState,
    )
    <PaymentShimmer />
  }
  let checkoutEle = {
    <ErrorBoundary key={selectedOption}>
      {switch selectedOption->PaymentModeType.paymentMode {
      | Card => <CardPayment cardProps expiryProps cvcProps paymentType list />
      | Klarna =>
        <SessionPaymentWrapper type_=Others>
          {switch klarnaTokenObj {
          | OtherTokenOptional(optToken) =>
            switch optToken {
            | Some(token) =>
              <React.Suspense fallback={loader()}>
                <KlarnaSDKLazy sessionObj=token list />
              </React.Suspense>
            | None =>
              <React.Suspense fallback={loader()}>
                <KlarnaPaymentLazy paymentType countryProps list />
              </React.Suspense>
            }
          | _ =>
            <React.Suspense fallback={loader()}>
              <KlarnaPaymentLazy paymentType countryProps list />
            </React.Suspense>
          }}
        </SessionPaymentWrapper>
      | ACHTransfer =>
        <React.Suspense fallback={loader()}>
          <ACHBankTransferLazy paymentType list />
        </React.Suspense>
      | SepaTransfer =>
        <React.Suspense fallback={loader()}>
          <SepaBankTransferLazy paymentType list countryProps />
        </React.Suspense>
      | BacsTransfer =>
        <React.Suspense fallback={loader()}>
          <BacsBankTransferLazy paymentType list />
        </React.Suspense>
      | ACHBankDebit =>
        <React.Suspense fallback={loader()}>
          <ACHBankDebitLazy paymentType list />
        </React.Suspense>
      | SepaBankDebit =>
        <React.Suspense fallback={loader()}>
          <SepaBankDebitLazy paymentType list />
        </React.Suspense>
      | BacsBankDebit =>
        <React.Suspense fallback={loader()}>
          <BacsBankDebitLazy paymentType list />
        </React.Suspense>
      | BanContactCard =>
        <CardPayment cardProps expiryProps cvcProps paymentType isBancontact=true list />
      | BecsBankDebit =>
        <React.Suspense fallback={loader()}>
          <BecsBankDebitLazy paymentType list />
        </React.Suspense>
      | GooglePay =>
        switch gPayToken {
        | OtherTokenOptional(optToken) =>
          switch googlePayThirdPartyToken {
          | GooglePayThirdPartyTokenOptional(googlePayThirdPartyOptToken) =>
            <React.Suspense fallback={loader()}>
              <GPayLazy
                paymentType
                sessionObj=optToken
                list
                thirdPartySessionObj=googlePayThirdPartyOptToken
                walletOptions
              />
            </React.Suspense>
          | _ =>
            <React.Suspense fallback={loader()}>
              <GPayLazy
                paymentType sessionObj=optToken list thirdPartySessionObj=None walletOptions
              />
            </React.Suspense>
          }
        | _ => React.null
        }
      | ApplePay =>
        switch applePayToken {
        | ApplePayTokenOptional(optToken) =>
          <ApplePayLazy sessionObj=optToken list walletOptions paymentType />
        | _ => React.null
        }
      | Boleto =>
        <React.Suspense fallback={loader()}>
          <BoletoLazy paymentType list />
        </React.Suspense>
      | _ =>
        <React.Suspense fallback={loader()}>
          <PaymentMethodsWrapperLazy paymentType list paymentMethodName=selectedOption />
        </React.Suspense>
      }}
    </ErrorBoundary>
  }

  let paymentLabel = if displaySavedPaymentMethods {
    showFields
      ? optionAtomValue.paymentMethodsHeaderText
      : optionAtomValue.savedPaymentMethodsHeaderText
  } else {
    optionAtomValue.paymentMethodsHeaderText
  }

  <>
    <RenderIf condition={paymentLabel->Option.isSome}>
      <div className="text-2xl font-semibold text-[#151619] mb-6">
        {paymentLabel->Option.getOr("")->React.string}
      </div>
    </RenderIf>
    <RenderIf condition={!showFields && displaySavedPaymentMethods}>
      <SavedMethods
        paymentToken setPaymentToken savedMethods loadSavedCards cvcProps paymentType list
      />
    </RenderIf>
    <RenderIf
      condition={(paymentOptions->Array.length > 0 || walletOptions->Array.length > 0) &&
        showFields}>
      <div className="flex flex-col place-items-center">
        <ErrorBoundary key="payment_request_buttons_all" level={ErrorBoundary.RequestButton}>
          <PaymentRequestButtonElement sessions walletOptions list />
        </ErrorBoundary>
        <RenderIf
          condition={paymentOptions->Array.length > 0 &&
          walletOptions->Array.length > 0 &&
          checkRenderOrComp()}>
          <Or />
        </RenderIf>
        {switch layoutClass.\"type" {
        | Tabs =>
          <PaymentOptions
            setCardsContainerWidth cardOptions dropDownOptions checkoutEle cardShimmerCount
          />
        | Accordion => <AccordionContainer paymentOptions checkoutEle />
        }}
      </div>
    </RenderIf>
    <RenderIf
      condition={displaySavedPaymentMethods && savedMethods->Array.length > 0 && showFields}>
      <div
        className="Label flex flex-row gap-3 items-end cursor-pointer my-4"
        style={ReactDOMStyle.make(
          ~fontSize="14px",
          ~float="left",
          ~fontWeight=themeObj.fontWeightNormal,
          ~width="fit-content",
          ~color=themeObj.colorPrimary,
          (),
        )}
        onClick={_ => setShowFields(_ => false)}>
        <Icon name="circle_dots" size=20 width=19 />
        {React.string(localeString.useExistingPaymentMethods)}
      </div>
    </RenderIf>
    <RenderIf condition={sdkHandleConfirmPayment.handleConfirm}>
      <div className="mt-4">
        <PayNowButton
          cvcProps
          cardProps
          expiryProps
          selectedOption={selectedOption->PaymentModeType.paymentMode}
          savedMethods
          paymentToken
        />
      </div>
    </RenderIf>
    <PoweredBy />
    {switch methodslist {
    | LoadError(_) => React.null
    | _ =>
      <RenderIf condition={paymentOptions->Array.length == 0 && walletOptions->Array.length == 0}>
        <PaymentElementShimmer />
      </RenderIf>
    }}
  </>
}
