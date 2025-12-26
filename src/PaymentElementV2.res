open PaymentType
open RecoilAtoms
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
  let {layout} = Recoil.useRecoilValueFromAtom(optionAtom)
  let optionAtomValue = Recoil.useRecoilValueFromAtom(optionAtom)
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let paymentMethodsListV2 = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentMethodsListV2)
  let (paymentManagementListValue, setPaymentManagementListValue) = Recoil.useRecoilState(
    paymentManagementListValue,
  )
  let sessionToken = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let (vaultMode, setVaultMode) = Recoil.useRecoilState(RecoilAtomsV2.vaultMode)
  let setPaymentMethodListValueV2 = Recoil.useSetRecoilState(RecoilAtomsV2.paymentMethodListValueV2)
  let isShowOrPayUsing = Recoil.useRecoilValueFromAtom(RecoilAtoms.isShowOrPayUsing)
  let (paymentOptions, setPaymentOptions) = React.useState(_ => [])
  let (walletOptions, setWalletOptions) = React.useState(_ => [])

  let (cardsContainerWidth, setCardsContainerWidth) = React.useState(_ => 0)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)
  let (dropDownOptions: array<string>, setDropDownOptions) = React.useState(_ => [])
  let (cardOptions: array<string>, setCardOptions) = React.useState(_ => [])
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let setShowPaymentMethodsScreen = Recoil.useSetRecoilState(RecoilAtoms.showPaymentMethodsScreen)

  let (walletsList, paymentOptionsList, actualList) = PaymentUtilsV2.useGetPaymentMethodListV2(
    ~paymentOptions,
    ~paymentType,
  )

  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let sessionsDict = sessions->getDictFromJson
  let sessionObj = SessionsType.itemToObjMapper(sessionsDict, Others)
  let gPayToken = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Gpay)
  let googlePayThirdPartySessionObj = SessionsType.itemToObjMapper(
    sessionsDict,
    GooglePayThirdPartyObject,
  )
  let googlePayThirdPartyToken = SessionsType.getPaymentSessionObj(
    googlePayThirdPartySessionObj.sessionsToken,
    Gpay,
  )

  React.useEffect0(() => {
    setShowPaymentMethodsScreen(_ => true)
    None
  })

  React.useEffect(() => {
    let vaultName = VaultHelpers.getVaultName(sessionToken)
    setVaultMode(_ => vaultName->VaultHelpers.getVaultModeFromName)
    switch sessionToken {
    | Loaded(val) => setSessions(_ => val)
    | _ => ()
    }
    None
  }, [sessionToken])

  React.useEffect(() => {
    let updatePaymentOptions = () => {
      setPaymentOptions(_ => [...paymentOptionsList]->removeDuplicate)
    }

    switch (paymentManagementList, paymentMethodsListV2) {
    | (LoadedV2(paymentlist), _) =>
      updatePaymentOptions()
      setPaymentManagementListValue(_ => paymentlist)
    | (_, LoadedV2(paymentlist)) =>
      setWalletOptions(_ => walletsList)
      updatePaymentOptions()
      setPaymentMethodListValueV2(_ => paymentlist)
    | (LoadErrorV2(_), _)
    | (_, LoadErrorV2(_))
    | (SemiLoadedV2, _)
    | (_, SemiLoadedV2) =>
      // TODO - For Payments CheckPriorityList
      // TODO - For PaymentMethodsManagement Cards
      setPaymentOptions(_ => [])
    | _ => ()
    }

    None
  }, (paymentManagementList, paymentOptionsList, actualList, paymentMethodsListV2))

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
        : switch paymentManagementList {
          | SemiLoadedV2
          | LoadErrorV2(_) => "card"
          | LoadedV2(_) =>
            paymentOptions->Array.includes(selectedOption)
              ? selectedOption
              : paymentOptions->Array.get(0)->Option.getOr("")
          | _ => paymentOptions->Array.get(0)->Option.getOr("")
          }
    )
    None
  }, (
    layoutClass.defaultCollapsed,
    paymentOptions,
    paymentManagementList,
    selectedOption,
    paymentMethodsListV2,
  ))

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
      | Card =>
        switch vaultMode {
        | VeryGoodSecurity => <VGSVault />
        | Hyperswitch => <CardIframeContainer />
        | None => <CardPayment cardProps expiryProps cvcProps />
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
      | SepaBankDebit =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="SepaBankDebitLazy">
          <SepaBankDebitLazy />
        </ReusableReactSuspense>
      | Givex
      | Klarna
      | Ideal
      | EPS =>
        <ReusableReactSuspense loaderComponent={loader()} componentName="PaymentMethodsWrapperLazy">
          <PaymentMethodsWrapperLazy paymentMethodName=selectedOption />
        </ReusableReactSuspense>
      | Sofort
      | AfterPay
      | Affirm
      | GiroPay
      | CryptoCurrency
      | ACHTransfer
      | SepaTransfer
      | InstantTransfer
      | InstantTransferFinland
      | InstantTransferPoland
      | BacsTransfer
      | ACHBankDebit
      | BacsBankDebit
      | BecsBankDebit
      | BanContactCard
      | ApplePay
      | RevolutPay
      | SamsungPay
      | Boleto
      | PayPal
      | EFT
      | Unknown => React.null
      }}
    </ErrorBoundary>
  }

  let paymentLabel = optionAtomValue.paymentMethodsHeaderText

  React.useEffect(() => {
    let evalMethodsList = () =>
      switch (paymentManagementList, paymentMethodsListV2) {
      | (SemiLoadedV2, _)
      | (LoadErrorV2(_), _)
      | (LoadedV2(_), _)
      | (_, LoadErrorV2(_))
      | (_, SemiLoadedV2)
      | (_, LoadedV2(_)) =>
        messageParentWindow([("ready", true->JSON.Encode.bool)])
      | _ => ()
      }
    evalMethodsList()

    None
  }, [paymentManagementList, paymentMethodsListV2])

  <>
    <RenderIf condition={paymentLabel->Option.isSome}>
      <div className="text-2xl font-semibold text-[#151619] mb-6">
        {paymentLabel->Option.getOr("")->React.string}
      </div>
    </RenderIf>
    <RenderIf condition={paymentOptions->Array.length > 0 || walletOptions->Array.length > 0}>
      <div className="flex flex-col place-items-center">
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
    {switch (paymentManagementList, paymentMethodsListV2) {
    | (LoadErrorV2(_), _) =>
      <RenderIf condition={paymentManagementListValue.paymentMethodsEnabled->Array.length === 0}>
        <ErrorBoundary.ErrorTextAndImage divRef level={Top} />
      </RenderIf>
    | (_, LoadErrorV2(_)) => <ErrorBoundary.ErrorTextAndImage divRef level={Top} />
    | _ =>
      <RenderIf condition={paymentOptions->Array.length == 0 && walletOptions->Array.length == 0}>
        <PaymentElementShimmer />
      </RenderIf>
    }}
    <RenderIf condition={paymentType !== PaymentMethodsManagement}>
      <PoweredBy />
    </RenderIf>
  </>
}
