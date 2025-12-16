open RecoilAtoms
module TabLoader = {
  @react.component
  let make = (~cardShimmerCount) => {
    open PaymentType
    open PaymentElementShimmer

    let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
    let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)

    switch (GlobalVars.sdkVersion, paymentMethodList, paymentManagementList) {
    | (V1, SemiLoaded, _)
    | (V2, _, SemiLoadedV2) =>
      Array.make(~length=cardShimmerCount - 1, "")
      ->Array.mapWithIndex((_, i) => {
        <div
          className={`Tab flex flex-col gap-3 animate-pulse cursor-default`}
          key={i->Int.toString}
          style={
            minWidth: "5rem",
            overflowWrap: "hidden",
            width: "100%",
            padding: themeObj.spacingUnit,
            cursor: "pointer",
          }>
          <Shimmer classname="opacity-50 w-1/3">
            <div
              className="w-full h-3 animate-pulse"
              style={backgroundColor: themeObj.colorPrimary, opacity: "10%"}
            />
          </Shimmer>
          <Shimmer classname="opacity-50">
            <div
              className="w-full h-2 animate-pulse"
              style={backgroundColor: themeObj.colorPrimary, opacity: "10%"}
            />
          </Shimmer>
        </div>
      })
      ->React.array
    | _ => React.null
    }
  }
}

@react.component
let make = (
  ~setCardsContainerWidth,
  ~cardOptions: array<string>,
  ~dropDownOptions: array<string>,
  ~checkoutEle: React.element,
  ~cardShimmerCount: int,
  ~cardProps: CardUtils.cardProps,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {readOnly, customMethodNames} = Recoil.useRecoilValueFromAtom(optionAtom)
  let payOptionsRef = React.useRef(Nullable.null)
  let selectRef = React.useRef(Nullable.null)
  let (winW, winH) = Utils.useWindowSize()
  let (selectedOption, setSelectedOption) = Recoil.useRecoilState(selectedOptionAtom)
  let (moreIconIndex, setMoreIconIndex) = React.useState(_ => 0)
  let (toggleIconElement, setToggleIconElement) = React.useState(_ => false)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()
  React.useEffect(() => {
    let width = switch payOptionsRef.current->Nullable.toOption {
    | Some(ref) => ref->Window.Element.clientWidth
    | None => 0
    }
    setCardsContainerWidth(_ => width)
    None
  }, (winH, winW))

  let handleChange = ev => {
    let target = ev->ReactEvent.Form.target
    let value = target["value"]
    setSelectedOption(_ => value)
    CardUtils.blurRef(selectRef)
  }

  let cardOptionDetails = cardOptions->PaymentMethodsRecord.getPaymentDetails(~localeString)

  let dropDownOptionsDetails =
    dropDownOptions->PaymentMethodsRecord.getPaymentDetails(~localeString)

  let allOptions = cardOptionDetails->Array.concat(dropDownOptionsDetails)

  let selectedPaymentOption =
    allOptions
    ->Array.find(item => item.paymentMethodName == selectedOption)
    ->Option.getOr(PaymentMethodsRecord.defaultPaymentFieldsInfo)

  let {cardBrand} = cardProps
  React.useEffect(() => {
    let intervalId = setInterval(() => {
      if dropDownOptionsDetails->Array.length > 1 {
        setMoreIconIndex(prev => mod(prev + 1, dropDownOptionsDetails->Array.length))
        setToggleIconElement(_ => true)
        setTimeout(
          () => {
            setToggleIconElement(_ => false)
          },
          10,
        )->ignore
      }
    }, 5000)

    Some(
      () => {
        clearInterval(intervalId)
      },
    )
  }, [dropDownOptionsDetails])

  PaymentUtils.useEmitPaymentMethodInfo(
    ~paymentMethodName=selectedPaymentOption.paymentMethodName,
    ~paymentMethods=paymentMethodListValue.payment_methods,
    ~cardBrand,
  )

  let displayIcon = ele => {
    <span className={`scale-90 animate-slowShow ${toggleIconElement ? "hidden" : ""}`}> ele </span>
  }

  <div className="w-full">
    <div
      ref={payOptionsRef->ReactDOM.Ref.domRef}
      className="TabHeader flex flex-row overflow-auto no-scrollbar"
      dataTestId={TestUtils.paymentMethodListTestId}
      style={
        columnGap: themeObj.spacingTab,
        marginBottom: themeObj.spacingGridColumn,
        paddingBottom: "7px",
        padding: "4px",
        height: "auto",
      }>
      {cardOptionDetails
      ->Array.mapWithIndex((payOption, i) => {
        let isActive = payOption.paymentMethodName == selectedOption

        let isDisabled = isGiftCardOnlyPayment
        <TabCard key={i->Int.toString} paymentOption=payOption isActive disabled=isDisabled />
      })
      ->React.array}
      <TabLoader cardShimmerCount />
      <RenderIf condition={dropDownOptionsDetails->Array.length > 0}>
        <div className="flex relative h-auto justify-center">
          <div className="flex flex-col items-center absolute mt-3 pointer-events-none gap-y-1.5">
            {switch dropDownOptionsDetails->Array.get(moreIconIndex) {
            | Some(paymentFieldsInfo) =>
              switch paymentFieldsInfo.miniIcon {
              | Some(ele) => displayIcon(ele)
              | None =>
                switch paymentFieldsInfo.icon {
                | Some(ele) => displayIcon(ele)
                | None => React.null
                }
              }
            | None => React.null
            }}
            <Icon size=10 name="arrow-down" />
          </div>
          <select
            value=selectedPaymentOption.paymentMethodName
            ref={selectRef->ReactDOM.Ref.domRef}
            className={`TabMore place-items-start outline-none`}
            onChange=handleChange
            disabled={readOnly || isGiftCardOnlyPayment}
            dataTestId=TestUtils.paymentMethodDropDownTestId
            style={
              width: "40px",
              paddingLeft: themeObj.spacingUnit,
              background: themeObj.colorBackground,
              cursor: "pointer",
              height: "inherit",
              borderRadius: themeObj.borderRadius,
              appearance: "none",
              color: "transparent",
            }>
            <option value=selectedPaymentOption.paymentMethodName disabled={true}>
              {
                let (name, _) = PaymentUtils.getDisplayNameAndIcon(
                  customMethodNames,
                  selectedPaymentOption.paymentMethodName,
                  selectedPaymentOption.displayName,
                  selectedPaymentOption.icon,
                )
                React.string(name)
              }
            </option>
            {dropDownOptionsDetails
            ->Array.mapWithIndex((item, i) => {
              <option
                key={Int.toString(i)}
                value=item.paymentMethodName
                style={color: themeObj.colorPrimary}>
                {
                  let (name, _) = PaymentUtils.getDisplayNameAndIcon(
                    customMethodNames,
                    item.paymentMethodName,
                    item.displayName,
                    item.icon,
                  )
                  React.string(name)
                }
              </option>
            })
            ->React.array}
          </select>
        </div>
      </RenderIf>
    </div>
    {checkoutEle}
  </div>
}
