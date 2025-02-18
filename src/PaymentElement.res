open PaymentType
open Utils

let cardsToRender = (width: int) => {
  let minWidth = 130
  let noOfCards = (width - 40) / minWidth
  noOfCards
}
@react.component
let make = (~cardProps, ~expiryProps, ~cvcProps, ~paymentType: CardThemeType.mode) => {
  let divRef = React.useRef(Nullable.null)

  let sessionsObj = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let {
    showCardFormByDefault,
    paymentMethodOrder,
    layout,
    customerPaymentMethods,
    displaySavedPaymentMethods,
    sdkHandleConfirmPayment,
  } = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let optionAtomValue = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)
  let isApplePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isApplePayReady)
  let isGPayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isGooglePayReady)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let isShowOrPayUsing = Recoil.useRecoilValueFromAtom(RecoilAtoms.isShowOrPayUsing)

  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(RecoilAtoms.selectedOptionAtom)
  let (showFields, setShowFields) = Recoil.useRecoilState(RecoilAtoms.showCardFieldsAtom)
  let (paymentToken, setPaymentToken) = Recoil.useRecoilState(RecoilAtoms.paymentTokenAtom)
  let (paymentMethodListValue, setPaymentMethodListValue) = Recoil.useRecoilState(
    PaymentUtils.paymentMethodListValue,
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

  let isShowPaymentMethodsDependingOnClickToPay = React.useMemo(() => {
    (clickToPayConfig.clickToPayCards->Option.getOr([])->Array.length > 0 ||
    clickToPayConfig.isReady->Option.getOr(false) &&
      clickToPayConfig.clickToPayCards->Option.isNone ||
    clickToPayConfig.email !== "") && !isClickToPayAuthenticateError
  }, (clickToPayConfig, isClickToPayAuthenticateError))

  let layoutClass = CardUtils.getLayoutClass(layout)

  React.useEffect(() => {
    switch (displaySavedPaymentMethods, customerPaymentMethods) {
    | (false, _) => {
        setShowFields(_ => isShowPaymentMethodsDependingOnClickToPay->not)
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
          finalSavedPaymentMethods->PaymentUtils.sortCustomerMethodsBasedOnPriority(
            paymentOrder,
            ~displayDefaultSavedPaymentIcon,
          )

        setSavedMethods(_ => sortSavedMethodsBasedOnPriority)
        setLoadSavedCards(_ =>
          finalSavedPaymentMethods->Array.length == 0
            ? NoResult(isGuestCustomer)
            : LoadedSavedCards(finalSavedPaymentMethods, isGuestCustomer)
        )
        setShowFields(_ =>
          finalSavedPaymentMethods->Array.length == 0 &&
            isShowPaymentMethodsDependingOnClickToPay->not
        )
      }
    | (_, NoResult(isGuestCustomer)) => {
        setLoadSavedCards(_ => NoResult(isGuestCustomer))
        setShowFields(_ => true && isShowPaymentMethodsDependingOnClickToPay->not)
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

  let (walletList, paymentOptionsList, actualList) = PaymentUtils.useGetPaymentMethodList(
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
  let {
    paypalToken,
    isPaypalSDKFlow,
    isPaypalRedirectFlow,
  } = PayPalHelpers.usePaymentMethodExperience(~paymentMethodListValue, ~sessionObj)

  React.useEffect(() => {
    switch paymentMethodList {
    | Loaded(paymentlist) =>
      let plist = paymentlist->getDictFromJson->PaymentMethodsRecord.itemToObjMapper

      setPaymentOptions(_ =>
        [
          ...showCardFormByDefault && checkPriorityList(paymentMethodOrder) ? ["card"] : [],
          ...paymentOptionsList,
        ]->removeDuplicate
      )
      setWalletOptions(_ => walletList)
      setPaymentMethodListValue(_ => plist)
      showCardFormByDefault
        ? if !(actualList->Array.includes(selectedOption)) && selectedOption !== "" {
            ErrorUtils.manageErrorWarning(
              SDK_CONNECTOR_WARNING,
              ~dynamicStr="Please enable Card Payment in the dashboard, or 'ShowCard.FormByDefault' to false.",
              ~logger=loggerState,
            )
          } else if !checkPriorityList(paymentMethodOrder) {
            ErrorUtils.manageErrorWarning(
              SDK_CONNECTOR_WARNING,
              ~dynamicStr=`'paymentMethodOrder' is ${Array.joinWith(
                  paymentMethodOrder->getOptionalArr,
                  ", ",
                )} . Please enable Card Payment as 1st priority to show it as default.`,
              ~logger=loggerState,
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
  }, (paymentMethodList, walletList, paymentOptionsList, actualList, showCardFormByDefault))

  let loadMastercardClickToPayScript = ssn => {
    open Promise
    let dict = ssn->getDictFromJson
    let clickToPaySessionObj = SessionsType.itemToObjMapper(dict, ClickToPayObject)
    let clickToPayToken = SessionsType.getPaymentSessionObj(
      clickToPaySessionObj.sessionsToken,
      ClickToPay,
    )

    switch clickToPayToken {
    | ClickToPayTokenOptional(optToken) =>
      switch optToken {
      | Some(token) =>
        let clickToPayToken = ClickToPayHelpers.clickToPayTokenItemToObjMapper(token)
        let isProd = publishableKey->String.startsWith("pk_prd_")
        ClickToPayHelpers.loadClickToPayScripts(loggerState)
        ClickToPayHelpers.loadMastercardScript(clickToPayToken, isProd, loggerState)
        ->then(resp => {
          let availableCardBrands =
            resp
            ->Utils.getDictFromJson
            ->Utils.getArray("availableCardBrands")
            ->Array.map(item => item->JSON.Decode.string->Option.getOr(""))
            ->Array.filter(item => item !== "")

          setClickToPayConfig(prev => {
            ...prev,
            isReady: Some(true),
            availableCardBrands,
            email: clickToPayToken.email,
            dpaName: clickToPayToken.dpaName,
          })
          resolve()
        })
        ->catch(_ => {
          setClickToPayConfig(prev => {
            ...prev,
            isReady: Some(false),
          })
          resolve()
        })
        ->ignore
      | None =>
        setClickToPayConfig(prev => {
          ...prev,
          isReady: Some(false),
        })
      }
    | _ =>
      setClickToPayConfig(prev => {
        ...prev,
        isReady: Some(false),
      })
    }
  }

  React.useEffect(() => {
    switch sessionsObj {
    | Loaded(ssn) => {
        setSessions(_ => ssn)
        loadMastercardClickToPayScript(ssn)
      }
    | _ => ()
    }
    None
  }, [sessionsObj])

  React.useEffect(() => {
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
    None
  }, (selectedOption, cardOptions, dropDownOptions))

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
            showCardFormByDefault && checkPriorityList(paymentMethodOrder) ? "card" : ""
          | Loaded(_) =>
            paymentOptions->Array.includes(selectedOption) && showCardFormByDefault
              ? selectedOption
              : paymentOptions->Array.get(0)->Option.getOr("")
          | _ => paymentOptions->Array.get(0)->Option.getOr("")
          }
    )
    None
  }, (
    layoutClass.defaultCollapsed,
    paymentOptions,
    paymentMethodList,
    selectedOption,
    showCardFormByDefault,
  ))
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
    <ErrorBoundary key={selectedOption} componentName="PaymentElement">
      {switch selectedOption->PaymentModeType.paymentMode {
      | Card => <CardPayment cardProps expiryProps cvcProps paymentType />
      | Klarna =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="KlarnaPaymentLazy">
          <KlarnaPaymentLazy paymentType />
        </ReusableReactSuspense>
      | ACHTransfer =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="ACHBankTransferLazy">
          <ACHBankTransferLazy paymentType />
        </ReusableReactSuspense>
      | SepaTransfer =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="SepaBankTransferLazy">
          <SepaBankTransferLazy paymentType />
        </ReusableReactSuspense>
      | BacsTransfer =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="BacsBankTransferLazy">
          <BacsBankTransferLazy paymentType />
        </ReusableReactSuspense>
      | ACHBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="ACHBankDebitLazy">
          <ACHBankDebitLazy paymentType />
        </ReusableReactSuspense>
      | SepaBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="SepaBankDebitLazy">
          <SepaBankDebitLazy paymentType />
        </ReusableReactSuspense>
      | BacsBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="BacsBankDebitLazy">
          <BacsBankDebitLazy paymentType />
        </ReusableReactSuspense>
      | BanContactCard =>
        <CardPayment cardProps expiryProps cvcProps paymentType isBancontact=true />
      | BecsBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="BecsBankDebitLazy">
          <BecsBankDebitLazy paymentType />
        </ReusableReactSuspense>
      | Boleto =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="BoletoLazy">
          <BoletoLazy paymentType />
        </ReusableReactSuspense>
      | ApplePay =>
        switch applePayToken {
        | ApplePayTokenOptional(optToken) =>
          <ReusableReactSuspense loaderComponent={loader()} componentName="ApplePayLazy">
            <ApplePayLazy sessionObj=optToken walletOptions paymentType />
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
                  sessionObj=optToken
                  thirdPartySessionObj=googlePayThirdPartyOptToken
                  walletOptions
                  paymentType
                />
              | _ =>
                <GPayLazy sessionObj=optToken thirdPartySessionObj=None walletOptions paymentType />
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
            | (_, _, true) => <PayPalLazy paymentType walletOptions />
            | _ => React.null
            }
          | _ =>
            <RenderIf condition={isPaypalRedirectFlow}>
              <PayPalLazy paymentType walletOptions />
            </RenderIf>
          }}
        </SessionPaymentWrapper>
      | _ =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="PaymentMethodsWrapperLazy">
          <PaymentMethodsWrapperLazy paymentType paymentMethodName=selectedOption />
        </ReusableReactSuspense>
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

  React.useEffect(() => {
    let fetchCards = async () => {
      switch clickToPayConfig.isReady {
      | Some(true) =>
        let cardsResult = await ClickToPayHelpers.getCards(loggerState)
        switch cardsResult {
        | Ok(cards) =>
          setClickToPayConfig(prev => {
            ...prev,
            clickToPayCards: Some(cards),
          })
        | Error(_) => ()
        }
      | _ => ()
      }
    }
    fetchCards()->ignore
    None
  }, [clickToPayConfig.isReady])

  <>
    <RenderIf condition={paymentLabel->Option.isSome}>
      <div className="text-2xl font-semibold text-[#151619] mb-6" role="heading" ariaLevel={1}>
        {paymentLabel->Option.getOr("")->React.string}
      </div>
    </RenderIf>
    {if clickToPayConfig.isReady->Option.isNone {
      <ClickToPayHelpers.SrcLoader />
    } else {
      <RenderIf
        condition={!showFields &&
        (displaySavedPaymentMethods || isShowPaymentMethodsDependingOnClickToPay)}>
        <SavedMethods
          paymentToken
          setPaymentToken
          savedMethods
          loadSavedCards
          cvcProps
          paymentType
          sessions
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
        />
      </RenderIf>
    }}
    <RenderIf
      condition={(paymentOptions->Array.length > 0 || walletOptions->Array.length > 0) &&
      showFields &&
      clickToPayConfig.isReady->Option.isSome}>
      <div
        className="flex flex-col place-items-center"
        role="region"
        ariaLabel="Payment Section"
        tabIndex={0}>
        <ErrorBoundary
          key="payment_request_buttons_all"
          level={ErrorBoundary.RequestButton}
          componentName="PaymentRequestButtonElement">
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
            setCardsContainerWidth
            cardOptions
            dropDownOptions
            checkoutEle
            cardShimmerCount
            cardProps
          />
        | Accordion => <AccordionContainer paymentOptions checkoutEle cardProps />
        }}
      </div>
    </RenderIf>
    <RenderIf
      condition={((displaySavedPaymentMethods && savedMethods->Array.length > 0) ||
        isShowPaymentMethodsDependingOnClickToPay) && showFields}>
      <div
        className="Label flex flex-row gap-3 items-end cursor-pointer mt-4"
        style={
          fontSize: "14px",
          float: "left",
          fontWeight: themeObj.fontWeightNormal,
          width: "fit-content",
          color: themeObj.colorPrimary,
        }
        tabIndex=0
        role="button"
        ariaLabel="Click to use existing payment methods"
        onKeyDown={event => {
          let key = JsxEvent.Keyboard.key(event)
          let keyCode = JsxEvent.Keyboard.keyCode(event)
          if key == "Enter" || keyCode == 13 {
            setShowFields(_ => false)
          }
        }}
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
