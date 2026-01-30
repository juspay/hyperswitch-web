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

  let {themeObj, config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {hideExpiredPaymentMethods} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let isCard = paymentItem.paymentMethodType === "card"
  let expiryMonth = paymentItem.paymentMethodData.card.expiryMonth
  let expiryYear = paymentItem.paymentMethodData.card.expiryYear
  let expiryDate = Date.fromString(`${expiryYear}-${expiryMonth}`)
  let currentDate = Date.make()
  let pickerItemClass = "PickerItem--selected"
  let isCardExpired = isCard && expiryDate < currentDate
  let paymentMethodType = paymentItem.paymentMethodType
  let nickname = switch paymentItem.paymentMethodData.card.nickname {
  | Some(val) => val
  | _ => ""
  }
  let (managePaymentMethod, setManagePaymentMethod) = Recoil.useRecoilState(
    RecoilAtomsV2.managePaymentMethod,
  )
  let setCardBrand = Recoil.useSetRecoilState(RecoilAtoms.cardBrand)
  let cvcRef = React.useRef(Nullable.null)

  let {innerLayout} = config.appearance
  let {isCVCValid, setIsCVCValid, cvcNumber, changeCVCNumber, handleCVCBlur, cvcError} = cvcProps
  let shouldRenderCVV = paymentItem.requiresCvv
  let isCVCEmpty = cvcNumber->String.length === 0

  let handleManage = () => setManagePaymentMethod(_ => paymentItem.paymentToken)

  let focusCVC = () => {
    setCardBrand(_ => paymentItem.paymentMethodData.card.network->Option.getOr(""))

    let optionalRef = cvcRef.current->Nullable.toOption
    switch optionalRef {
    | Some(_) => optionalRef->Option.forEach(input => input->CardUtils.focus)->ignore
    | None => ()
    }
  }

  React.useEffect(() => {
    if isActive {
      focusCVC()
    }
    None
  }, (isActive, paymentItem))

  let isManageModeInactive = managePaymentMethod != paymentItem.paymentToken

  let handleOnClick = _ => {
    setPaymentTokenAtom(_ => {
      paymentToken: paymentItem.paymentToken,
      customerId: paymentItem.customerId,
    })
    if managePaymentMethod != "" {
      setManagePaymentMethod(_ => "")
    }
  }

  <RenderIf condition={!hideExpiredPaymentMethods || !isCardExpired}>
    <div className={`flex flex-col`}>
      <button
        className={`PickerItem ${pickerItemClass} flex flex-row items-stretch`}
        type_="button"
        style={
          minWidth: "150px",
          width: "100%",
          padding: "1rem 0 1rem 0",
          borderBottom: isManageModeInactive ? `1px solid ${themeObj.borderColor}` : "none",
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
                            <div> {React.string(nickname)} </div>
                            <RenderIf condition=isManageModeInactive>
                              <div className={`PickerItemLabel flex flex-row gap-1 items-center`}>
                                <div className="tracking-widest"> {React.string(`****`)} </div>
                                <div>
                                  {React.string(paymentItem.paymentMethodData.card.last4Digits)}
                                </div>
                              </div>
                            </RenderIf>
                          </div>
                          <RenderIf condition=isManageModeInactive>
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
              <RenderIf condition={!isManageModeInactive && isActive}>
                <div
                  className="cursor-pointer ml-4 mb-[6px]"
                  style={color: themeObj.colorPrimary}
                  onClick={_ => {
                    handleUpdate(paymentItem)->ignore
                  }}>
                  {React.string("Save")}
                </div>
                <Icon
                  size=18
                  name="delete-hollow"
                  style={color: themeObj.colorDanger}
                  className="cursor-pointer ml-4 mb-[6px]"
                  onClick={_ => {
                    handleDeleteV2(paymentItem)->ignore
                  }}
                />
              </RenderIf>
              <RenderIf condition={isManageModeInactive}>
                <Icon
                  size=18
                  name="manage"
                  style={color: themeObj.colorPrimary}
                  className="cursor-pointer ml-4 mb-[6px]"
                  onClick={_ => {
                    handleManage()
                  }}
                />
              </RenderIf>
            </div>
            <div className="w-full">
              <div className="flex flex-col items-start mx-8">
                <RenderIf condition={isActive && shouldRenderCVV && isManageModeInactive}>
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
                <RenderIf
                  condition={isActive && isCVCEmpty && innerLayout === Spaced && cvcError != ""}>
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
      <RenderIf condition={!isManageModeInactive && isActive}>
        <ManageSavedItem paymentItem managePaymentMethod isCardExpired expiryMonth expiryYear />
      </RenderIf>
    </div>
  </RenderIf>
}
