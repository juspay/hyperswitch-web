@react.component
let make = (~brandIcon, ~paymentItem: PaymentType.customerMethods, ~handleDelete) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {hideExpiredPaymentMethods} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let isCard = paymentItem.paymentMethod === "card"
  let expiryMonth = paymentItem.card.expiryMonth
  let expiryYear = paymentItem.card.expiryYear
  let expiryDate = Date.fromString(`${expiryYear}-${expiryMonth}`)
  let currentDate = Date.make()
  let pickerItemClass = "PickerItem--selected"
  let isCardExpired = isCard && expiryDate < currentDate
  let paymentMethodType = paymentItem.paymentMethodType->Option.getOr("debit")

  <RenderIf condition={!hideExpiredPaymentMethods || !isCardExpired}>
    <div
      className={`PickerItem ${pickerItemClass} flex flex-row items-stretch`}
      style={
        minWidth: "150px",
        width: "100%",
        padding: "1rem 0 1rem 0",
        borderBottom: `1px solid ${themeObj.borderColor}`,
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
                      <div className="flex flex-col items-start">
                        <div> {React.string(paymentItem.card.nickname)} </div>
                        <div className={`PickerItemLabel flex flex-row gap-3 items-center`}>
                          <div className="tracking-widest"> {React.string(`****`)} </div>
                          <div> {React.string(paymentItem.card.last4Digits)} </div>
                        </div>
                      </div>
                    } else {
                      <div> {React.string(paymentMethodType->Utils.snakeToTitleCase)} </div>
                    }}
                  </div>
                </div>
              </div>
              <RenderIf condition={isCard}>
                <div
                  className={`flex flex-row items-center justify-end gap-3 -mt-1`}
                  style={fontSize: "14px", opacity: "0.5"}>
                  <div className="flex">
                    {React.string(
                      `${expiryMonth} / ${expiryYear->CardUtils.formatExpiryToTwoDigit}`,
                    )}
                  </div>
                </div>
              </RenderIf>
            </div>
            <Icon
              size=18
              name="delete"
              style={color: themeObj.colorDanger}
              className="cursor-pointer ml-4 mb-[6px]"
              onClick={_ => paymentItem->handleDelete}
            />
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
  </RenderIf>
}
