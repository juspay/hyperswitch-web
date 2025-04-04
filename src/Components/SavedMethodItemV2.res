@react.component
let make = (
  ~brandIcon,
  ~paymentItem: PMMTypesV2.customerMethods,
  ~handleDeleteV2,
  ~handleUpdate,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
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

  let handlemanage = () => {
    setManagePaymentMethod(_ => paymentItem.id)
  }

  <RenderIf condition={!hideExpiredPaymentMethods || !isCardExpired}>
    <div className={`flex flex-col`}>
      <div
        className={`PickerItem ${pickerItemClass} flex flex-row items-stretch`}
        style={
          minWidth: "150px",
          width: "100%",
          padding: "1rem 0 1rem 0",
          borderBottom: managePaymentMethod != paymentItem.id
            ? `1px solid ${themeObj.borderColor}`
            : "none",
          borderTop: "none",
          borderLeft: "none",
          borderRight: "none",
          borderRadius: "0px",
          background: "transparent",
          color: themeObj.colorTextSecondary,
          boxShadow: "none",
          opacity: {isCardExpired ? "0.7" : "1"},
        }>
        <div className="w-full">
          <div>
            <div className="flex flex-row justify-between items-center">
              <div className="flex grow justify-between">
                <div
                  className={`flex flex-row justify-center items-center`}
                  style={columnGap: themeObj.spacingUnit}>
                  <div className={`PickerItemIcon mx-3 flex  items-center `}> brandIcon </div>
                  <div className="flex flex-col">
                    <div className="flex items-center gap-4">
                      {if isCard {
                        <div className="flex flex-col items-start gap-1">
                          <div className="flex flex-row items-start gap-3">
                            <div> {React.string(nickname)} </div>
                            <RenderIf condition={managePaymentMethod != paymentItem.id}>
                              <div className={`PickerItemLabel flex flex-row gap-1 items-center`}>
                                <div className="tracking-widest"> {React.string(`****`)} </div>
                                <div>
                                  {React.string(paymentItem.paymentMethodData.card.last4Digits)}
                                </div>
                              </div>
                            </RenderIf>
                          </div>
                          <RenderIf condition={managePaymentMethod != paymentItem.id}>
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
              <RenderIf condition={managePaymentMethod == paymentItem.id}>
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
              <RenderIf condition={!(managePaymentMethod === paymentItem.id)}>
                <Icon
                  size=18
                  name="manage"
                  style={color: themeObj.colorPrimary}
                  className="cursor-pointer ml-4 mb-[6px]"
                  onClick={_ => {
                    handlemanage()
                  }}
                />
              </RenderIf>
            </div>
            <div className="w-full">
              <div className="flex flex-col items-start mx-8">
                <RenderIf condition={isCardExpired}>
                  <div className="italic mt-3 ml-1" style={fontSize: "14px", opacity: "0.7"}>
                    {`*${localeString.cardExpiredText}`->React.string}
                  </div>
                </RenderIf>
              </div>
            </div>
          </div>
        </div>
      </div>
      <RenderIf condition={managePaymentMethod == paymentItem.id}>
        <ManageSavedItem paymentItem managePaymentMethod isCardExpired expiryMonth expiryYear />
      </RenderIf>
    </div>
  </RenderIf>
}
