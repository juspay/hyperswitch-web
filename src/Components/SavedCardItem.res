module RenderSavedPaymentMethodItem = {
  @react.component
  let make = (
    ~paymentItem: PaymentType.customerMethods,
    ~paymentMethodType,
    ~themeObj: CardThemeType.themeClass,
    ~displayDefaultSavedPaymentIcon,
    ~defaultPaymentMethodSet,
    ~expiryText,
    ~expiryMonth,
    ~expiryYear,
  ) => {
    let expiryYearToTwoDigits = expiryYear->CardUtils.formatExpiryToTwoDigit

    switch paymentItem.paymentMethod {
    | "card" =>
      <div
        className="flex flex-col w-full gap-1 text-[15px] font-medium"
        role="group"
        ariaLabel={`Card ${paymentItem.card.nickname}, ending in ${paymentItem.card.last4Digits}`}>
        <div className="flex items-center">
          {React.string(paymentItem.card.nickname)}
          <RenderIf condition={displayDefaultSavedPaymentIcon && defaultPaymentMethodSet}>
            <Icon className="ml-2" size=16 name="checkmark" style={color: themeObj.colorPrimary} />
          </RenderIf>
        </div>
        <div className="PickerItemLabel flex flex-row items-center gap-2 text-sm font-normal">
          <div className="whitespace-nowrap" ariaHidden=true>
            {React.string(`**** ${paymentItem.card.last4Digits}`)}
          </div>
          <span className="w-1 h-1 rounded-full bg-black/60" />
          <div className="whitespace-nowrap">
            {React.string(`${expiryText} ${expiryMonth}/${expiryYearToTwoDigits}`)}
          </div>
        </div>
      </div>

    | "bank_debit" =>
      <div
        className="flex flex-col items-start"
        role="group"
        ariaLabel={`${paymentMethodType->String.toUpperCase} bank debit account ending in ${paymentItem.bank.mask}`}>
        <div>
          {React.string(
            `${paymentMethodType->String.toUpperCase} ${paymentItem.paymentMethod->Utils.snakeToTitleCase}`,
          )}
        </div>
        <div className={`PickerItemLabel flex flex-row gap-3 items-center`}>
          <div className="tracking-widest" ariaHidden=true> {React.string(`****`)} </div>
          <div ariaHidden=true> {React.string(paymentItem.bank.mask)} </div>
        </div>
      </div>

    | _ =>
      <div ariaLabel={paymentMethodType->Utils.snakeToTitleCase}>
        {React.string(paymentMethodType->Utils.snakeToTitleCase)}
      </div>
    }
  }
}

@react.component
let make = (
  ~setPaymentToken,
  ~isActive,
  ~paymentItem: PaymentType.customerMethods,
  ~brandIcon,
  ~index,
  ~savedCardlength,
  ~cvcProps,
  ~paymentType,
  ~setRequiredFieldsBody,
) => {
  let {themeObj, config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {
    hideExpiredPaymentMethods,
    displayDefaultSavedPaymentIcon,
    displayBillingDetails,
  } = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (cardBrand, setCardBrand) = Recoil.useRecoilState(RecoilAtoms.cardBrand)
  let (
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    _,
    changeCVCNumber,
    handleCVCBlur,
    _,
    _,
    cvcError,
    _,
  ) = cvcProps
  let cvcRef = React.useRef(Nullable.null)
  let pickerItemClass = isActive ? "PickerItem--selected" : ""

  let focusCVC = () => {
    setCardBrand(_ =>
      switch paymentItem.card.scheme {
      | Some(val) => val
      | None => ""
      }
    )
    let optionalRef = cvcRef.current->Nullable.toOption
    switch optionalRef {
    | Some(_) => optionalRef->Option.forEach(input => input->CardUtils.focus)->ignore
    | None => ()
    }
  }

  let isCard = paymentItem.paymentMethod === "card"
  let isRenderCvv = isCard && paymentItem.requiresCvv
  let expiryMonth = paymentItem.card.expiryMonth
  let expiryYear = paymentItem.card.expiryYear

  let paymentMethodType = switch paymentItem.paymentMethodType {
  | Some(paymentMethodType) => paymentMethodType
  | None => "debit"
  }

  React.useEffect(() => {
    open CardUtils

    if isActive {
      // * Focus CVC
      focusCVC()

      // * Sending card expiry to handle cases where the card expires before the use date.
      `${expiryMonth}${String.substring(~start=2, ~end=4, expiryYear)}`
      ->formatCardExpiryNumber
      ->emitExpiryDate

      PaymentUtils.emitPaymentMethodInfo(
        ~paymentMethod=paymentItem.paymentMethod,
        ~paymentMethodType,
        ~cardBrand=cardBrand->CardUtils.getCardType,
      )
    }
    None
  }, (isActive, cardBrand, paymentItem.paymentMethod, paymentMethodType))

  let expiryDate = Date.fromString(`${expiryYear}-${expiryMonth}`)
  expiryDate->Date.setMonth(expiryDate->Date.getMonth + 1)
  let currentDate = Date.make()
  let isCardExpired = isCard && expiryDate < currentDate

  let paymentMethodType = switch paymentItem.paymentMethodType {
  | Some(paymentMethodType) => paymentMethodType
  | None => "debit"
  }

  let defaultPaymentMethodSet = paymentItem.defaultPaymentMethodSet

  let billingDetailsText = "Billing Details:"

  let billingDetailsArray =
    [
      paymentItem.billing.address.line1,
      paymentItem.billing.address.line2,
      paymentItem.billing.address.line3,
      paymentItem.billing.address.city,
      paymentItem.billing.address.state,
      paymentItem.billing.address.country,
      paymentItem.billing.address.zip,
    ]
    ->Array.map(item => Option.getOr(item, ""))
    ->Array.filter(item => String.trim(item) !== "")

  let isCVCEmpty = cvcNumber->String.length == 0

  let {innerLayout} = config.appearance

  let expiryText = localeString.expiry

  <RenderIf condition={!hideExpiredPaymentMethods || !isCardExpired}>
    <button
      className={`PickerItem ${pickerItemClass} flex flex-row items-stretch`}
      type_="button"
      style={
        minWidth: "150px",
        width: "100%",
        padding: "1rem 0 1rem 0",
        cursor: "pointer",
        borderBottom: index == savedCardlength - 1 ? "0px" : `1px solid ${themeObj.borderColor}`,
        borderTop: "none",
        borderLeft: "none",
        borderRight: "none",
        borderRadius: "0px",
        background: "transparent",
        color: themeObj.colorTextSecondary,
        boxShadow: "none",
        opacity: {isCardExpired ? "0.7" : "1"},
      }
      onClick={_ => {
        open RecoilAtomTypes
        setPaymentToken(_ => {
          paymentToken: paymentItem.paymentToken,
          customerId: paymentItem.customerId,
        })
      }}>
      <div className="w-full">
        <div>
          <div className="flex flex-row justify-between items-center">
            <div
              className={`flex flex-row justify-center items-center`}
              style={columnGap: themeObj.spacingUnit}>
              <div style={color: isActive ? themeObj.colorPrimary : ""}>
                <Radio
                  checked=isActive
                  height="18px"
                  className="savedcard"
                  marginTop="-2px"
                  opacity="20%"
                  padding="46%"
                  border="1px solid currentColor"
                />
              </div>
              <div className={`PickerItemIcon mx-1 flex items-center`}> brandIcon </div>
              <div className="flex flex-col">
                <div className="flex items-center gap-2">
                  <RenderSavedPaymentMethodItem
                    paymentItem={paymentItem}
                    paymentMethodType
                    themeObj
                    displayDefaultSavedPaymentIcon
                    defaultPaymentMethodSet
                    expiryText
                    expiryMonth
                    expiryYear
                  />
                </div>
              </div>
            </div>
            <RenderIf condition={isCard && isActive && isRenderCvv}>
              <div className={`flex flex-row items-start gap-2 opacity-70 text-sm`}>
                <div className={`flex h mx-4 w-16 ${isActive ? "opacity-1" : "opacity-0"}`}>
                  <PaymentInputField
                    isValid=isCVCValid
                    setIsValid=setIsCVCValid
                    value=cvcNumber
                    onChange=changeCVCNumber
                    onBlur=handleCVCBlur
                    errorString=""
                    inputFieldClassName="flex justify-start"
                    paymentType
                    appearance=config.appearance
                    type_="tel"
                    className={`tracking-widest justify-start w-full`}
                    maxLength=4
                    inputRef=cvcRef
                    height="2.2rem"
                    name={TestUtils.cardCVVInputTestId}
                    placeholder=localeString.cvcTextLabel
                  />
                </div>
              </div>
            </RenderIf>
          </div>
          <div className="w-full">
            <div className="flex flex-col items-start mx-3">
              <RenderIf condition={isActive && displayBillingDetails}>
                <div className="text-sm text-left gap-2 mt-5" style={marginLeft: "16%"}>
                  <div className="font-semibold"> {React.string(billingDetailsText)} </div>
                  <div className="font-normal">
                    {React.string(Array.joinWith(billingDetailsArray, ", "))}
                  </div>
                </div>
              </RenderIf>
              <RenderIf condition={isActive && innerLayout === Spaced}>
                <RenderIf condition=isCVCEmpty>
                  <div
                    className="Error pt-1 mt-1"
                    style={
                      color: themeObj.colorDangerText,
                      fontSize: themeObj.fontSizeSm,
                      marginLeft: "16%",
                    }>
                    {React.string(cvcError)}
                  </div>
                </RenderIf>
              </RenderIf>
              <RenderIf condition={isCardExpired}>
                <div className="italic mt-3 ml-1" style={fontSize: "14px", opacity: "0.7"}>
                  {`*${localeString.cardExpiredText}`->React.string}
                </div>
              </RenderIf>
              <RenderIf condition={isActive}>
                <DynamicFields
                  paymentType
                  paymentMethod=paymentItem.paymentMethod
                  paymentMethodType
                  setRequiredFieldsBody
                  isSavedCardFlow=true
                  savedMethod=paymentItem
                />
                <Surcharge
                  paymentMethod=paymentItem.paymentMethod
                  paymentMethodType
                  cardBrand={cardBrand->CardUtils.getCardType}
                />
              </RenderIf>
            </div>
          </div>
        </div>
      </div>
    </button>
  </RenderIf>
}
