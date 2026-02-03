@react.component
let make = (
  ~brandIcon,
  ~paymentItem: UnifiedPaymentsTypesV2.customerMethods,
  ~handleDeleteV2,
  ~handleUpdate,
  ~setPaymentTokenAtom,
  ~isActive,
  ~cvcProps: CardUtils.cvcProps,
) => {
  open RecoilAtomTypes

  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {hideExpiredPaymentMethods} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {
    paymentToken,
    customerId,
    paymentMethodData,
    paymentMethodType,
    requiresCvv: shouldRenderCVV,
  } = paymentItem
  let {expiryMonth, expiryYear, last4Digits, network, nickname} = paymentMethodData.card

  let isCard = paymentMethodType === "card"
  let expiryDate = Date.fromString(`${expiryYear}-${expiryMonth}`)
  let currentDate = Date.make()
  let pickerItemClass = "PickerItem--selected"
  let isCardExpired = isCard && expiryDate < currentDate
  let paymentMethodType = paymentMethodType

  let (managePaymentMethod, setManagePaymentMethod) = Recoil.useRecoilState(
    RecoilAtomsV2.managePaymentMethod,
  )
  let setCardBrand = Recoil.useSetRecoilState(RecoilAtoms.cardBrand)
  let cvcRef = React.useRef(Nullable.null)

  let {isCVCValid, setIsCVCValid, cvcNumber, changeCVCNumber, handleCVCBlur, cvcError} = cvcProps
  let isCVCEmpty = cvcNumber->String.length === 0

  let handleManage = () => {
    setPaymentTokenAtom(_ => {
      paymentToken,
      customerId,
    })
    setManagePaymentMethod(_ => paymentToken)
  }

  let focusCVC = () => {
    setCardBrand(_ => network->Option.getOr(""))

    let optionalRef = cvcRef.current->Nullable.toOption
    switch optionalRef {
    | Some(_) => optionalRef->Option.forEach(input => input->CardUtils.focus)->ignore
    | None => ()
    }
  }

  React.useEffect(() => {
    if isActive && managePaymentMethod == "" {
      focusCVC()
    }
    None
  }, (isActive, managePaymentMethod))

  let isManageModeActive = managePaymentMethod === paymentToken

  let handleOnClick = _ => {
    setPaymentTokenAtom(_ => {
      paymentToken,
      customerId,
    })
    setManagePaymentMethod(_ => "")
  }

  let showCVCError = isActive && isCVCEmpty && cvcError != "" && !isManageModeActive
  let showCVCField = isActive && shouldRenderCVV && !isManageModeActive

  <RenderIf condition={!hideExpiredPaymentMethods || !isCardExpired}>
    <div className={`flex flex-col`}>
      <button
        className={`PickerItem ${pickerItemClass} flex flex-row items-stretch`}
        type_="button"
        style={
          minWidth: "150px",
          width: "100%",
          padding: "1rem 0 1rem 0",
          borderBottom: !isManageModeActive ? `1px solid ${themeObj.borderColor}` : "none",
          borderTop: "none",
          borderLeft: "none",
          borderRight: "none",
          borderRadius: "0px",
          background: "transparent",
          color: themeObj.colorTextSecondary,
          boxShadow: "none",
          opacity: {isCardExpired ? "0.7" : "1"},
        }
        onClick=handleOnClick>
        <div className="w-full">
          <div>
            <div className="flex flex-row justify-between items-center">
              <div className="flex grow justify-between">
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
                      {if isCard {
                        <div className="flex flex-col items-start gap-1">
                          <div className="flex flex-row items-start gap-3">
                            <div> {React.string(nickname->Option.getOr(""))} </div>
                            <RenderIf condition={!isManageModeActive}>
                              <div className={`PickerItemLabel flex flex-row gap-1 items-center`}>
                                <div className="tracking-widest"> {React.string(`****`)} </div>
                                <div> {React.string(last4Digits)} </div>
                              </div>
                            </RenderIf>
                          </div>
                          <RenderIf condition={!isManageModeActive}>
                            <div
                              className={`flex flex-row items-center justify-end gap-3 -mt-1`}
                              style={fontSize: "14px", opacity: "0.5"}>
                              <div> {React.string(`Expiry`)} </div>
                              <div className="flex">
                                {React.string(
                                  `${expiryMonth} / ${expiryYear->CardUtils.formatExpiryToTwoDigit}`,
                                )}
                              </div>
                            </div>
                          </RenderIf>
                        </div>
                      } else {
                        <div> {React.string(paymentMethodType->Utils.snakeToTitleCase)} </div>
                      }}
                    </div>
                  </div>
                </div>
              </div>
              <RenderIf condition={isManageModeActive && isActive}>
                <div
                  className="cursor-pointer ml-4 mb-[6px]"
                  style={color: themeObj.colorPrimary}
                  onClick={event => {
                    ReactEvent.Mouse.stopPropagation(event)
                    handleUpdate(paymentItem)->ignore
                  }}>
                  {React.string("Save")}
                </div>
                <Icon
                  size=18
                  name="delete-hollow"
                  style={color: themeObj.colorDanger}
                  className="cursor-pointer ml-4 mb-[6px]"
                  onClick={event => {
                    ReactEvent.Mouse.stopPropagation(event)
                    handleDeleteV2(paymentItem)->ignore
                  }}
                />
              </RenderIf>
              <RenderIf condition={!isManageModeActive}>
                <Icon
                  size=18
                  name="manage"
                  style={color: themeObj.colorPrimary}
                  className="cursor-pointer ml-4 mb-[6px]"
                  onClick={event => {
                    ReactEvent.Mouse.stopPropagation(event)
                    handleManage()
                  }}
                />
              </RenderIf>
            </div>
            <div className="w-full">
              <div className="flex flex-col items-start mx-8">
                <RenderIf condition=showCVCField>
                  <div
                    className={`flex flex-row items-start justify-start gap-2`}
                    style={fontSize: "14px", opacity: "0.5"}>
                    <div className="tracking-widest w-12 mt-6">
                      {React.string(`${localeString.cvcTextLabel}:`)}
                    </div>
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
                        errorString=""
                        inputFieldClassName="flex justify-start"
                        type_="tel"
                        className={`tracking-widest justify-start w-full`}
                        maxLength=4
                        inputRef=cvcRef
                        placeholder="123"
                        height="1.8rem"
                        name={TestUtils.cardCVVInputTestId}
                        autocomplete="cc-csc"
                      />
                    </div>
                  </div>
                </RenderIf>
                <RenderIf condition=showCVCError>
                  <div
                    className="Error pt-1 mt-1 ml-2"
                    style={
                      color: themeObj.colorDangerText,
                      fontSize: themeObj.fontSizeSm,
                    }>
                    {React.string(cvcError)}
                  </div>
                </RenderIf>
                <RenderIf condition={isCardExpired}>
                  <div className="italic mt-3 ml-1" style={fontSize: "14px", opacity: "0.7"}>
                    {`*${localeString.cardExpiredText}`->React.string}
                  </div>
                </RenderIf>
              </div>
            </div>
          </div>
        </div>
      </button>
      <RenderIf condition={isManageModeActive && isActive}>
        <ManageSavedItem paymentItem managePaymentMethod isCardExpired expiryMonth expiryYear />
      </RenderIf>
    </div>
  </RenderIf>
}
