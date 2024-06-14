open PaymentType
open RecoilAtoms
open Utils

let cardsToRender = (width: int) => {
  let minWidth = 130
  let noOfCards = (width - 40) / minWidth
  noOfCards
}
@react.component
let make = (~cardProps, ~expiryProps, ~cvcProps, ~paymentType: CardThemeType.mode) => {
  let divRef = React.useRef(Nullable.null)
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
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (paymentOptions, setPaymentOptions) = React.useState(_ => [])
  let (walletOptions, setWalletOptions) = React.useState(_ => [])
  let {sdkHandleConfirmPayment} = Recoil.useRecoilValueFromAtom(optionAtom)

  let (paymentMethodListValue, setPaymentMethodListValue) = Recoil.useRecoilState(
    PaymentUtils.paymentMethodListValue,
  )
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
    loadSavedCards: savedCardsLoadState,
    setLoadSavedCards: (savedCardsLoadState => savedCardsLoadState) => unit,
  ) = React.useState(_ => LoadingSavedCards)

  React.useEffect(() => {
    switch (displaySavedPaymentMethods, customerPaymentMethods) {
    | (false, _) => {
        setShowFields(_ => true)
        setLoadSavedCards(_ => LoadedSavedCards([], true))
      }
    | (_, LoadingSavedCards) => ()
    | (_, LoadedSavedCards(savedPaymentMethods, isGuestCustomer)) => {
        let sortSavedPaymentMethods = (a, b) => {
          let defaultCompareVal = compareLogic(
            Date.fromString(a.lastUsedAt),
            Date.fromString(b.lastUsedAt),
          )
          if optionAtomValue.displayDefaultSavedPaymentIcon {
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

        let finalSavedPaymentMethods = savedPaymentMethods->Array.copy
        finalSavedPaymentMethods->Array.sort(sortSavedPaymentMethods)

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

  let (walletList, paymentOptionsList, actualList) = PaymentUtils.useGetPaymentMethodList(
    ~paymentOptions,
    ~paymentType,
    ~sessions,
  )

  React.useEffect(() => {
    switch paymentMethodList {
    | Loaded(paymentlist) =>
      let plist = paymentlist->getDictFromJson->PaymentMethodsRecord.itemToObjMapper

      setPaymentOptions(_ => {
        paymentOptionsList
      })
      setWalletOptions(_ => walletList)
      setPaymentMethodListValue(_ => plist)
      showCardFormByDefault
        ? if !(actualList->Array.includes(selectedOption)) && selectedOption !== "" {
            ErrorUtils.manageErrorWarning(
              SDK_CONNECTOR_WARNING,
              ~dynamicStr="Please enable Card Payment in the dashboard, or 'ShowCard.FormByDefault' to false.",
              ~logger=loggerState,
              (),
            )
          } else if !checkPriorityList(paymentMethodOrder) {
            ErrorUtils.manageErrorWarning(
              SDK_CONNECTOR_WARNING,
              ~dynamicStr=`'paymentMethodOrder' is ${Array.joinWith(
                  paymentMethodOrder->getOptionalArr,
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
        showCardFormByDefault && checkPriorityList(paymentMethodOrder) ? ["card"] : []
      )
    | _ => ()
    }
    None
  }, (paymentMethodList, walletList, paymentOptionsList, actualList))
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
  let cardShimmerCount = React.useMemo(() => {
    cardsToRender(cardsContainerWidth)
  }, [cardsContainerWidth])
  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
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
            showCardFormByDefault && checkPriorityList(paymentMethodOrder) ? "card" : ""
          | Loaded(_) =>
            paymentOptions->Array.includes(selectedOption) && showCardFormByDefault
              ? selectedOption
              : paymentOptions->Array.get(0)->Option.getOr("")
          | _ => paymentOptions->Array.get(0)->Option.getOr("")
          }
    )
    None
  }, (layoutClass.defaultCollapsed, paymentOptions, paymentMethodList, selectedOption))
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

  let loader = () => {
    handlePostMessageEvents(
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
      | Card => <CardPayment cardProps expiryProps cvcProps paymentType />
      | Klarna =>
        <React.Suspense fallback={loader()}>
          <KlarnaPaymentLazy paymentType />
        </React.Suspense>
      | ACHTransfer =>
        <React.Suspense fallback={loader()}>
          <ACHBankTransferLazy paymentType />
        </React.Suspense>
      | SepaTransfer =>
        <React.Suspense fallback={loader()}>
          <SepaBankTransferLazy paymentType />
        </React.Suspense>
      | BacsTransfer =>
        <React.Suspense fallback={loader()}>
          <BacsBankTransferLazy paymentType />
        </React.Suspense>
      | ACHBankDebit =>
        <React.Suspense fallback={loader()}>
          <ACHBankDebitLazy paymentType />
        </React.Suspense>
      | SepaBankDebit =>
        <React.Suspense fallback={loader()}>
          <SepaBankDebitLazy paymentType />
        </React.Suspense>
      | BacsBankDebit =>
        <React.Suspense fallback={loader()}>
          <BacsBankDebitLazy paymentType />
        </React.Suspense>
      | BanContactCard =>
        <CardPayment cardProps expiryProps cvcProps paymentType isBancontact=true />
      | BecsBankDebit =>
        <React.Suspense fallback={loader()}>
          <BecsBankDebitLazy paymentType />
        </React.Suspense>
      | Boleto =>
        <React.Suspense fallback={loader()}>
          <BoletoLazy paymentType />
        </React.Suspense>
      | _ =>
        <React.Suspense fallback={loader()}>
          <PaymentMethodsWrapperLazy paymentType paymentMethodName=selectedOption />
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

  React.useEffect(() => {
    let evalMethodsList = () =>
      switch paymentMethodList {
      | SemiLoaded | LoadError(_) | Loaded(_) =>
        handlePostMessage([("ready", true->JSON.Encode.bool)])
      | _ => ()
      }
    if !displaySavedPaymentMethods {
      evalMethodsList()
    } else {
      switch customerPaymentMethods {
      | LoadingSavedCards => ()
      | LoadedSavedCards(list, _) =>
        list->Array.length > 0
          ? handlePostMessage([("ready", true->JSON.Encode.bool)])
          : evalMethodsList()
      | NoResult(_) => evalMethodsList()
      }
    }
    None
  }, (paymentMethodList, customerPaymentMethods))

  <>
    <RenderIf condition={paymentLabel->Option.isSome}>
      <div className="text-2xl font-semibold text-[#151619] mb-6">
        {paymentLabel->Option.getOr("")->React.string}
      </div>
    </RenderIf>
    <RenderIf condition={!showFields && displaySavedPaymentMethods}>
      <SavedMethods paymentToken setPaymentToken savedMethods loadSavedCards cvcProps paymentType />
    </RenderIf>
    <RenderIf
      condition={(paymentOptions->Array.length > 0 || walletOptions->Array.length > 0) &&
        showFields}>
      <div className="flex flex-col place-items-center">
        <ErrorBoundary key="payment_request_buttons_all" level={ErrorBoundary.RequestButton}>
          <PaymentRequestButtonElement sessions walletOptions paymentType />
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
        style={
          fontSize: "14px",
          float: "left",
          fontWeight: themeObj.fontWeightNormal,
          width: "fit-content",
          color: themeObj.colorPrimary,
        }
        onClick={_ => setShowFields(_ => false)}>
        <Icon name="circle_dots" size=20 width=19 />
        {React.string(localeString.useExistingPaymentMethods)}
      </div>
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
