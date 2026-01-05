open PaymentType
open Utils
open PaymentUtils

let cardsToRender = (width: int) => {
  let minWidth = 130
  let noOfCards = (width - 40) / minWidth
  noOfCards
}

@react.component
let make = (~cardProps, ~expiryProps, ~cvcProps, ~paymentType: CardThemeType.mode) => {
  let divRef = React.useRef(Nullable.null)

  let {
    paymentMethodOrder,
    layout,
    customerPaymentMethods,
    displaySavedPaymentMethods,
    sdkHandleConfirmPayment,
  } = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let optionAtomValue = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)
  let isApplePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isApplePayReady)
  let isGPayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isGooglePayReady)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let isShowOrPayUsing = Recoil.useRecoilValueFromAtom(RecoilAtoms.isShowOrPayUsing)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(RecoilAtoms.selectedOptionAtom)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Recoil.useRecoilState(
    RecoilAtoms.showPaymentMethodsScreen,
  )
  let (paymentToken, setPaymentToken) = Recoil.useRecoilState(RecoilAtoms.paymentTokenAtom)
  let (paymentMethodListValue, setPaymentMethodListValue) = Recoil.useRecoilState(
    paymentMethodListValue,
  )

  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (paymentOptions, setPaymentOptions) = React.useState(_ => [])
  let (walletOptions, setWalletOptions) = React.useState(_ => [])
  let (cardsContainerWidth, setCardsContainerWidth) = React.useState(_ => 0)
  let (dropDownOptions: array<string>, setDropDownOptions) = React.useState(_ => [])
  let (cardOptions: array<string>, setCardOptions) = React.useState(_ => [])
  let (savedMethods, setSavedMethods) = React.useState(_ => [])
  let (
    loadSavedCards: savedCardsLoadState,
    setLoadSavedCards: (savedCardsLoadState => savedCardsLoadState) => unit,
  ) = React.useState(_ => LoadingSavedCards)
  let (isClickToPayAuthenticateError, setIsClickToPayAuthenticateError) = React.useState(_ => false)
  let (areClickToPayUIScriptsLoaded, setAreClickToPayUIScriptsLoaded) = React.useState(_ => false)

  let isShowPaymentMethodsDependingOnClickToPay = React.useMemo(() => {
    (clickToPayConfig.clickToPayCards->Option.getOr([])->Array.length > 0 ||
    clickToPayConfig.isReady->Option.getOr(false) &&
      clickToPayConfig.clickToPayCards->Option.isNone ||
    clickToPayConfig.email !== "") && !isClickToPayAuthenticateError
  }, (clickToPayConfig, isClickToPayAuthenticateError))

  let layoutClass = CardUtils.getLayoutClass(layout)
  let groupSavedMethodsWithPaymentMethods =
    layoutClass.savedMethodCustomization.groupingBehavior == GroupByPaymentMethods

  let (getVisaCards, closeComponentIfSavedMethodsAreEmpty) = ClickToPayHook.useClickToPay(
    ~areClickToPayUIScriptsLoaded,
    ~setSessions,
    ~setAreClickToPayUIScriptsLoaded,
    ~savedMethods,
    ~loadSavedCards,
  )

  React.useEffect(() => {
    switch (displaySavedPaymentMethods, customerPaymentMethods) {
    | (false, _) => {
        setShowPaymentMethodsScreen(_ => isShowPaymentMethodsDependingOnClickToPay->not)
        setLoadSavedCards(_ => LoadedSavedCards([], true))
      }
    | (_, LoadingSavedCards) => ()
    | (_, LoadedSavedCards(savedPaymentMethods, isGuestCustomer)) => {
        let displayDefaultSavedPaymentIcon = optionAtomValue.displayDefaultSavedPaymentIcon
        let sortSavedPaymentMethods = (a, b) => {
          let defaultCompareVal = compareLogic(
            Date.fromString(a.lastUsedAt),
            Date.fromString(b.lastUsedAt),
          )
          if displayDefaultSavedPaymentIcon {
            if a.defaultPaymentMethodSet {
              -1.
            } else if b.defaultPaymentMethodSet {
              1.
            } else {
              defaultCompareVal
            }
          } else {
            defaultCompareVal
          }
        }

        let finalSavedPaymentMethods =
          savedPaymentMethods
          ->Array.copy
          ->Array.filter(savedMethod => {
            switch savedMethod.paymentMethodType {
            | Some("apple_pay") => isApplePayReady
            | Some("google_pay") => isGPayReady
            | _ => true
            }
          })
        finalSavedPaymentMethods->Array.sort(sortSavedPaymentMethods)

        let paymentOrder = paymentMethodOrder->getOptionalArr->removeDuplicate

        let sortSavedMethodsBasedOnPriority =
          finalSavedPaymentMethods->sortCustomerMethodsBasedOnPriority(
            paymentOrder,
            ~displayDefaultSavedPaymentIcon,
          )

        setSavedMethods(_ => sortSavedMethodsBasedOnPriority)
        setLoadSavedCards(_ =>
          finalSavedPaymentMethods->Array.length == 0
            ? NoResult(isGuestCustomer)
            : LoadedSavedCards(finalSavedPaymentMethods, isGuestCustomer)
        )
        setShowPaymentMethodsScreen(_ =>
          finalSavedPaymentMethods->Array.length == 0 &&
            isShowPaymentMethodsDependingOnClickToPay->not
        )
      }
    | (_, NoResult(isGuestCustomer)) => {
        setLoadSavedCards(_ => NoResult(isGuestCustomer))
        setShowPaymentMethodsScreen(_ => isShowPaymentMethodsDependingOnClickToPay->not)
      }
    }

    None
  }, (
    customerPaymentMethods,
    displaySavedPaymentMethods,
    optionAtomValue,
    isApplePayReady,
    isGPayReady,
    clickToPayConfig.isReady,
    isShowPaymentMethodsDependingOnClickToPay,
  ))

  React.useEffect(() => {
    let defaultSelectedPaymentMethod = optionAtomValue.displayDefaultSavedPaymentIcon
      ? savedMethods->Array.find(savedMethod => savedMethod.defaultPaymentMethodSet)
      : savedMethods->Array.get(0)

    let isSavedMethodsEmpty = savedMethods->Array.length === 0

    let tokenObj = switch (isSavedMethodsEmpty, defaultSelectedPaymentMethod) {
    | (false, Some(defaultSelectedPaymentMethod)) => Some(defaultSelectedPaymentMethod)
    | (false, None) => Some(savedMethods->Array.get(0)->Option.getOr(defaultCustomerMethods))
    | _ => None
    }

    switch tokenObj {
    | Some(obj) =>
      setPaymentToken(_ => {
        paymentToken: obj.paymentToken,
        customerId: obj.customerId,
      })
    | None => ()
    }
    None
  }, [savedMethods])

  let (walletList, paymentOptionsList, actualList) = useGetPaymentMethodList(
    ~paymentOptions,
    ~paymentType,
    ~sessions,
  )

  let dict = sessions->getDictFromJson
  let sessionObj = SessionsType.itemToObjMapper(dict, Others)
  let applePaySessionObj = SessionsType.itemToObjMapper(dict, ApplePayObject)
  let applePayToken = SessionsType.getPaymentSessionObj(applePaySessionObj.sessionsToken, ApplePay)
  let gPayToken = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Gpay)
  let googlePayThirdPartySessionObj = SessionsType.itemToObjMapper(dict, GooglePayThirdPartyObject)
  let googlePayThirdPartyToken = SessionsType.getPaymentSessionObj(
    googlePayThirdPartySessionObj.sessionsToken,
    Gpay,
  )
  let {paypalToken, isPaypalSDKFlow, isPaypalRedirectFlow} = PayPalHelpers.usePaymentMethodData(
    ~paymentMethodListValue,
    ~sessionObj,
  )
  let showAllPaymentMethods = switch layoutClass.paymentMethodsArrangement {
  | Grid => true
  | _ => false
  }

  React.useEffect(() => {
    switch paymentMethodList {
    | Loaded(paymentlist) =>
      let pList = paymentlist->getDictFromJson->PaymentMethodsRecord.itemToObjMapper

      setPaymentOptions(_ =>
        [
          ...checkPriorityList(paymentMethodOrder) ? ["card"] : [],
          ...paymentOptionsList,
        ]->removeDuplicate
      )
      setWalletOptions(_ => walletList)
      setPaymentMethodListValue(_ => pList)

      if !(actualList->Array.includes(selectedOption)) && selectedOption !== "" {
        ErrorUtils.manageErrorWarning(
          SDK_CONNECTOR_WARNING,
          ~dynamicStr="Please enable Card Payment in the dashboard, or 'ShowCard.FormByDefault' to false.",
          ~logger=loggerState,
        )
      } else if !checkPriorityList(paymentMethodOrder) {
        ErrorUtils.manageErrorWarning(
          SDK_CONNECTOR_WARNING,
          ~dynamicStr=`'paymentMethodOrder' is ${Array.join(
              paymentMethodOrder->getOptionalArr,
              ", ",
            )} . Please enable Card Payment as 1st priority to show it as default.`,
          ~logger=loggerState,
        )
      }

    | LoadError(_)
    | SemiLoaded =>
      setPaymentOptions(_ => checkPriorityList(paymentMethodOrder) ? ["card"] : [])
    | _ => ()
    }
    None
  }, (paymentMethodList, walletList, paymentOptionsList, actualList))

  React.useEffect(() => {
    if !showAllPaymentMethods {
      if layoutClass.\"type" == Tabs {
        let isCard = cardOptions->Array.includes(selectedOption)
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
        )
      }
    }
    None
  }, (selectedOption, cardOptions, dropDownOptions))

  React.useEffect(() => {
    let cardsCount: int = cardsToRender(cardsContainerWidth)
    let cardOpts = Array.slice(~start=0, ~end=cardsCount, paymentOptions)
    let dropOpts = paymentOptions->Array.sliceToEnd(~start=cardsCount)
    let isCard: bool = cardOpts->Array.includes(selectedOption)
    if (
      !isCard &&
      selectedOption !== "" &&
      paymentOptions->Array.includes(selectedOption) &&
      !showAllPaymentMethods
    ) {
      let (cardArr, dropdownArr) = CardUtils.swapCardOption(cardOpts, dropOpts, selectedOption)
      setCardOptions(_ => cardArr)
      setDropDownOptions(_ => dropdownArr)
    } else if !showAllPaymentMethods {
      setCardOptions(_ => cardOpts)
      setDropDownOptions(_ => dropOpts)
    } else {
      setCardOptions(_ => paymentOptions)
      setDropDownOptions(_ => [])
    }
    None
  }, (cardsContainerWidth, paymentOptions))
  let cardShimmerCount = React.useMemo(() => {
    cardsToRender(cardsContainerWidth)
  }, [cardsContainerWidth])
  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit && selectedOption == "" {
      postFailedSubmitResponse(~errortype="validation_error", ~message="Select a payment method")
    }
  }, [selectedOption])
  useSubmitPaymentData(submitCallback)
  React.useEffect(() => {
    setSelectedOption(prev =>
      selectedOption !== ""
        ? prev
        : layoutClass.defaultCollapsed
        ? ""
        : switch paymentMethodList {
          | SemiLoaded
          | LoadError(_) =>
            checkPriorityList(paymentMethodOrder) ? "card" : ""
          | Loaded(_) =>
            paymentOptions->Array.includes(selectedOption)
              ? selectedOption
              : paymentOptions->Array.get(0)->Option.getOr("")
          | _ => paymentOptions->Array.get(0)->Option.getOr("")
          }
    )
    None
  }, (layoutClass.defaultCollapsed, paymentOptions, paymentMethodList, selectedOption))

  let loader = () => {
    handlePostMessageEvents(
      ~complete=false,
      ~empty=false,
      ~paymentType=selectedOption,
      ~loggerState,
    )
    <PaymentShimmer />
  }
  let paymentFormElement = {
    <ErrorBoundary key={selectedOption} componentName="PaymentElement" publishableKey>
      {switch selectedOption->PaymentModeType.paymentMode {
      | Card => <CardPayment cardProps expiryProps cvcProps />
      | ACHTransfer =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="ACHBankTransferLazy">
          <ACHBankTransferLazy />
        </ReusableReactSuspense>
      | SepaTransfer =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="SepaBankTransferLazy">
          <SepaBankTransferLazy />
        </ReusableReactSuspense>
      | InstantTransfer =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="InstantBankTransferLazy">
          <InstantBankTransferLazy />
        </ReusableReactSuspense>
      | InstantTransferFinland =>
        <ReusableReactSuspense
          loaderComponent={loader()} componentName="InstantBankTransferFinlandLazy">
          <InstantBankTransferFinlandLazy />
        </ReusableReactSuspense>
      | InstantTransferPoland =>
        <ReusableReactSuspense
          loaderComponent={loader()} componentName="InstantBankTransferPolandLazy">
          <InstantBankTransferPolandLazy />
        </ReusableReactSuspense>
      | BacsTransfer =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="BacsBankTransferLazy">
          <BacsBankTransferLazy />
        </ReusableReactSuspense>
      | ACHBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="ACHBankDebitLazy">
          <ACHBankDebitLazy />
        </ReusableReactSuspense>
      | SepaBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="SepaBankDebitLazy">
          <SepaBankDebitLazy />
        </ReusableReactSuspense>
      | BacsBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="BacsBankDebitLazy">
          <BacsBankDebitLazy />
        </ReusableReactSuspense>
      | BanContactCard => <CardPayment cardProps expiryProps cvcProps isBancontact=true />
      | BecsBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="BecsBankDebitLazy">
          <BecsBankDebitLazy />
        </ReusableReactSuspense>
      | Boleto =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="BoletoLazy">
          <BoletoLazy />
        </ReusableReactSuspense>
      | ApplePay =>
        switch applePayToken {
        | ApplePayTokenOptional(optToken) =>
          <ReusableReactSuspense loaderComponent={loader()} componentName="ApplePayLazy">
            <ApplePayLazy sessionObj=optToken walletOptions />
          </ReusableReactSuspense>
        | _ => React.null
        }
      | GooglePay =>
        <SessionPaymentWrapper type_={Wallet}>
          {switch gPayToken {
          | OtherTokenOptional(optToken) =>
            <ReusableReactSuspense loaderComponent={loader()} componentName="GPayLazy">
              {switch googlePayThirdPartyToken {
              | GooglePayThirdPartyTokenOptional(googlePayThirdPartyOptToken) =>
                <GPayLazy
                  sessionObj=optToken thirdPartySessionObj=googlePayThirdPartyOptToken walletOptions
                />
              | _ => <GPayLazy sessionObj=optToken thirdPartySessionObj=None walletOptions />
              }}
            </ReusableReactSuspense>
          | _ => React.null
          }}
        </SessionPaymentWrapper>
      | PayPal =>
        <SessionPaymentWrapper type_={Wallet}>
          {switch paypalToken {
          | OtherTokenOptional(optToken) =>
            switch (optToken, isPaypalSDKFlow, isPaypalRedirectFlow) {
            | (Some(_token), true, _) => {
                loggerState.setLogInfo(
                  ~value="PayPal Invoke SDK Flow in Tabs",
                  ~eventName=PAYPAL_SDK_FLOW,
                )
                React.null
              }
            | (_, _, true) => <PayPalLazy walletOptions />
            | _ => React.null
            }
          | _ =>
            <RenderIf condition={isPaypalRedirectFlow}>
              <PayPalLazy walletOptions />
            </RenderIf>
          }}
        </SessionPaymentWrapper>
      | _ =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="PaymentMethodsWrapperLazy">
          <PaymentMethodsWrapperLazy paymentMethodName=selectedOption />
        </ReusableReactSuspense>
      }}
    </ErrorBoundary>
  }

  let checkoutEle = if groupSavedMethodsWithPaymentMethods {
    <SavedMethodsWithPaymentForm
      savedMethods
      setPaymentToken
      cvcProps
      paymentToken
      sessions
      loadSavedCards
      isClickToPayAuthenticateError
      setIsClickToPayAuthenticateError
      getVisaCards
      isShowPaymentMethodsDependingOnClickToPay
      closeComponentIfSavedMethodsAreEmpty>
      {paymentFormElement}
    </SavedMethodsWithPaymentForm>
  } else {
    paymentFormElement
  }

  let paymentLabel = if displaySavedPaymentMethods {
    showPaymentMethodsScreen
      ? optionAtomValue.paymentMethodsHeaderText
      : optionAtomValue.savedPaymentMethodsHeaderText
  } else {
    optionAtomValue.paymentMethodsHeaderText
  }

  React.useEffect(() => {
    if groupSavedMethodsWithPaymentMethods {
      setShowPaymentMethodsScreen(_ => true)
    }
    let evalMethodsList = () =>
      switch paymentMethodList {
      | SemiLoaded | LoadError(_) | Loaded(_) =>
        messageParentWindow([("ready", true->JSON.Encode.bool)])
      | _ => ()
      }
    if !displaySavedPaymentMethods {
      evalMethodsList()
    } else {
      switch customerPaymentMethods {
      | LoadingSavedCards => ()
      | LoadedSavedCards(list, _) =>
        list->Array.length > 0
          ? messageParentWindow([("ready", true->JSON.Encode.bool)])
          : evalMethodsList()
      | NoResult(_) => evalMethodsList()
      }
    }
    None
  }, (paymentMethodList, customerPaymentMethods))

  let shouldShowSavedMethods =
    displaySavedPaymentMethods || isShowPaymentMethodsDependingOnClickToPay

  let shouldShowSavedMethodsScreen =
    !groupSavedMethodsWithPaymentMethods && !showPaymentMethodsScreen && shouldShowSavedMethods

  let hasSavedPaymentMethods = displaySavedPaymentMethods && savedMethods->Array.length > 0

  let shouldShowUseExistingMethodsButton =
    !groupSavedMethodsWithPaymentMethods &&
    (hasSavedPaymentMethods || isShowPaymentMethodsDependingOnClickToPay) &&
    showPaymentMethodsScreen

  let isLoadingGroupedSavedMethods =
    customerPaymentMethods == LoadingSavedCards && groupSavedMethodsWithPaymentMethods

  let hasPaymentOrWalletOptions =
    paymentOptions->Array.length > 0 || walletOptions->Array.length > 0

  let shouldDisplayPaymentMethodsScreen =
    groupSavedMethodsWithPaymentMethods || showPaymentMethodsScreen

  let shouldShowShimmer = clickToPayConfig.isReady->Option.isNone || isLoadingGroupedSavedMethods

  let shouldRenderPaymentSection =
    !isLoadingGroupedSavedMethods &&
    hasPaymentOrWalletOptions &&
    shouldDisplayPaymentMethodsScreen &&
    clickToPayConfig.isReady->Option.isSome

  <>
    <RenderIf condition={paymentLabel->Option.isSome}>
      <div
        className="PaymentLabel text-2xl font-semibold text-[#151619] mb-6"
        role="heading"
        ariaLevel={1}>
        {paymentLabel->Option.getOr("")->React.string}
      </div>
    </RenderIf>
    {if shouldShowShimmer {
      if areClickToPayUIScriptsLoaded {
        <ClickToPayHelpers.SrcLoader />
      } else if groupSavedMethodsWithPaymentMethods {
        <PaymentElementShimmer />
      } else {
        <PaymentElementShimmer.SavedPaymentCardShimmer />
      }
    } else {
      <RenderIf condition=shouldShowSavedMethodsScreen>
        <SavedMethods
          paymentToken
          setPaymentToken
          savedMethods
          loadSavedCards
          cvcProps
          sessions
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
          getVisaCards
          closeComponentIfSavedMethodsAreEmpty
        />
      </RenderIf>
    }}
    <RenderIf condition=shouldRenderPaymentSection>
      <div
        className="flex flex-col place-items-center"
        role="region"
        ariaLabel="Payment Section"
        tabIndex={0}>
        <ErrorBoundary
          key="payment_request_buttons_all"
          level={ErrorBoundary.RequestButton}
          componentName="PaymentRequestButtonElement">
          <PaymentRequestButtonElement sessions walletOptions />
        </ErrorBoundary>
        <RenderIf
          condition={paymentOptions->Array.length > 0 &&
          walletOptions->Array.length > 0 &&
          checkRenderOrComp(~walletOptions, isShowOrPayUsing)}>
          <Or />
        </RenderIf>
        {switch layoutClass.\"type" {
        | Tabs =>
          <PaymentOptions
            setCardsContainerWidth
            cardOptions
            dropDownOptions
            checkoutEle
            cardShimmerCount
            cardProps
            expiryProps
          />
        | Accordion => <AccordionContainer paymentOptions checkoutEle cardProps expiryProps />
        }}
      </div>
    </RenderIf>
    <RenderIf condition={shouldShowUseExistingMethodsButton}>
      <SwitchViewButton
        icon={<Icon name="circle_dots" size=20 width=19 />}
        title={localeString.useExistingPaymentMethods}
        onClick={_ => setShowPaymentMethodsScreen(_ => false)}
        ariaLabel="Click to use existing payment methods"
        onKeyDown={event => {
          let key = JsxEvent.Keyboard.key(event)
          let keyCode = JsxEvent.Keyboard.keyCode(event)
          if key == "Enter" || keyCode == 13 {
            setShowPaymentMethodsScreen(_ => false)
          }
        }}
      />
    </RenderIf>
    {switch paymentMethodList {
    | LoadError(_) =>
      <RenderIf condition={paymentMethodListValue.payment_methods->Array.length === 0}>
        <ErrorBoundary.ErrorTextAndImage divRef level={Top} />
      </RenderIf>
    | _ =>
      <RenderIf
        condition={!displaySavedPaymentMethods &&
        paymentOptions->Array.length == 0 &&
        walletOptions->Array.length == 0}>
        <PaymentElementShimmer />
      </RenderIf>
    }}
    <RenderIf condition={sdkHandleConfirmPayment.handleConfirm}>
      <div className="mt-4">
        <PayNowButton />
      </div>
    </RenderIf>
    <PoweredBy />
  </>
}
