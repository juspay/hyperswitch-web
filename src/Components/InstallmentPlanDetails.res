@react.component
let make = (~plan: PaymentMethodsRecord.installmentPlan, ~currency) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let interestLabel =
    plan.interest_rate == 0.0
      ? localeString.installmentInterestFree
      : localeString.installmentWithInterest

  let amountPerInstallment = Utils.formatAmountWithTwoDecimals(
    plan.amount_details.amount_per_installment,
  )
  let totalAmount = Utils.formatAmountWithTwoDecimals(plan.amount_details.total_amount)

  let mainLabel = `${plan.number_of_installments->Int.toString} X ${currency} ${amountPerInstallment}`

  let totalLabel = localeString.installmentTotal

  <div className="flex flex-col flex-1 min-w-0">
    <div className="flex items-center justify-between w-full">
      <span
        style={
          fontSize: themeObj.fontSizeLg,
          color: themeObj.colorText,
        }>
        {mainLabel->React.string}
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
}
