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
  let {hideExpiredPaymentMethods, displayDefaultSavedPaymentIcon} = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.optionAtom,
  )
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
  React.useEffect(() => {
    isActive ? focusCVC() : ()
    None
  }, [isActive])

  let isCard = paymentItem.paymentMethod === "card"
  let isRenderCvv = isCard && paymentItem.requiresCvv
  let expiryMonth = paymentItem.card.expiryMonth
  let expiryYear = paymentItem.card.expiryYear

  let expiryDate = Date.fromString(`${expiryYear}-${expiryMonth}`)
  expiryDate->Date.setMonth(expiryDate->Date.getMonth + 1)
  let currentDate = Date.make()
  let isCardExpired = isCard && expiryDate < currentDate

  let paymentMethodType = switch paymentItem.paymentMethodType {
  | Some(paymentMethodType) => paymentMethodType
  | None => "debit"
  }

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
              <div className={`PickerItemIcon mx-3 flex  items-center `}> brandIcon </div>
              <div className="flex flex-col">
                <div className="flex items-center gap-4">
                  {isCard
                    ? <div className="flex flex-col items-start">
                        <div> {React.string(paymentItem.card.nickname)} </div>
                        <div className={`PickerItemLabel flex flex-row gap-3 items-center`}>
                          <div className="tracking-widest"> {React.string(`****`)} </div>
                          <div> {React.string(paymentItem.card.last4Digits)} </div>
                        </div>
                      </div>
                    : <div> {React.string(paymentMethodType->Utils.snakeToTitleCase)} </div>}
                  <RenderIf
                    condition={displayDefaultSavedPaymentIcon &&
                    paymentItem.defaultPaymentMethodSet}>
                    <Icon size=18 name="checkmark" style={color: themeObj.colorPrimary} />
                  </RenderIf>
                </div>
              </div>
            </div>
            <RenderIf condition={isCard}>
              <div
                className={`flex flex-row items-center justify-end gap-3 -mt-1`}
                style={fontSize: "14px", opacity: "0.5"}>
                <div className="flex">
                  {React.string(`${expiryMonth} / ${expiryYear->CardUtils.formatExpiryToTwoDigit}`)}
                </div>
              </div>
            </RenderIf>
          </div>
          <div className="w-full">
            <div className="flex flex-col items-start mx-8">
              <RenderIf condition={isActive && isRenderCvv}>
                <div
                  className={`flex flex-row items-start justify-start gap-2`}
                  style={fontSize: "14px", opacity: "0.5"}>
                  <div className="w-12 mt-6"> {React.string("CVC: ")} </div>
                  <div
                    className={`flex h mx-4 justify-start w-16 ${isActive
                        ? "opacity-1 mt-4"
                        : "opacity-0"}`}>
                    <PaymentInputField
                      isValid=isCVCValid
                      setIsValid=setIsCVCValid
                      value=cvcNumber
                      onChange=changeCVCNumber
                      onBlur=handleCVCBlur
                      errorString=cvcError
                      inputFieldClassName="flex justify-start"
                      paymentType
                      appearance=config.appearance
                      type_="tel"
                      className={`tracking-widest justify-start w-full`}
                      maxLength=4
                      inputRef=cvcRef
                      placeholder="123"
                      height="2.2rem"
                    />
                  </div>
                </div>
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
