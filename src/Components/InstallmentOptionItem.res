@react.component
let make = (
  ~plan: PaymentMethodsRecord.installmentPlan,
  ~currency,
  ~isSelected,
  ~onSelect,
  ~isLastItem,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let interestLabel =
    plan.interest_rate == 0.0
      ? localeString.installmentInterestFree
      : localeString.installmentWithInterest

  let amountPerInstallment = Utils.formatAmountWithTwoDecimals(
    plan.amount_details.amount_per_installment,
  )
  let totalAmount = Utils.formatAmountWithTwoDecimals(plan.amount_details.total_amount)
  let numberOfInstallments = plan.number_of_installments

  let mainInstallmentLabel = localeString.installmentPaymentLabel(
    numberOfInstallments,
    currency,
    amountPerInstallment,
  )

  let totalLabel = localeString.installmentTotal

  let radioBorderColor = if isSelected {
    themeObj.colorPrimary
  } else {
    themeObj.borderColor
  }

  <div
    onClick={_ => onSelect()}
    style={
      padding: `calc(${themeObj.spacingUnit} * 0.8) ${themeObj.spacingUnit}`,
      borderColor: themeObj.borderColor,
      backgroundColor: if isSelected {
        `color-mix(in srgb, ${themeObj.colorPrimary} 6%, ${themeObj.colorBackground})`
      } else {
        themeObj.colorBackground
      },
    }
    className={`flex items-center gap-2 w-full ${isLastItem ? "" : "border-b"} cursor-pointer`}>
    <div
      style={
        width: "16px",
        height: "16px",
        border: `1.5px solid ${radioBorderColor}`,
      }
      className="rounded-full shrink-0 flex items-center justify-center">
      <RenderIf condition=isSelected>
        <div
          style={
            width: "8px",
            height: "8px",
            backgroundColor: themeObj.colorPrimary,
          }
          className="rounded-full"
        />
      </RenderIf>
    </div>
    <div className="flex flex-col flex-1 min-w-0">
      <div className="flex items-center justify-between w-full">
        <span
          style={
            fontSize: themeObj.fontSizeLg,
            color: themeObj.colorText,
          }>
          {mainInstallmentLabel->React.string}
        </span>
        <span
          style={
            fontSize: themeObj.fontSizeSm,
            color: themeObj.colorTextSecondary,
          }>
          {totalLabel->React.string}
        </span>
      </div>
      <div className="flex items-center justify-between w-full mt-px">
        <span
          style={
            fontSize: themeObj.fontSizeSm,
            color: themeObj.colorTextSecondary,
          }>
          {interestLabel->React.string}
        </span>
        <span
          style={
            fontSize: themeObj.fontSizeLg,
            color: themeObj.colorText,
          }>
          {`${currency} ${totalAmount}`->React.string}
        </span>
      </div>
    </div>
  </div>
}
