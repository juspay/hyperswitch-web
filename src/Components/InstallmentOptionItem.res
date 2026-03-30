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

  <div
    onClick={_ => onSelect()}
    style={
      padding: `calc(${themeObj.spacingUnit} + 0.2rem)`,
      borderColor: themeObj.borderColor,
    }
    className={`flex items-center gap-3 w-full ${isLastItem
        ? ""
        : "border-b"} cursor-pointer text-left`}>
    <div className="flex-shrink-0" style={color: isSelected ? themeObj.colorPrimary : ""}>
      <Radio checked=isSelected />
    </div>
    <div className="flex items-center justify-between w-full gap-2 flex-wrap">
      <div className="flex items-center gap-1">
        <span
          style={
            fontWeight: themeObj.fontWeightMedium,
          }>
          {mainInstallmentLabel->React.string}
        </span>
        <span className="opacity-40"> {`\u2022`->React.string} </span>
        <span className="opacity-50"> {interestLabel->React.string} </span>
      </div>
      <div className="flex items-center gap-1 text-nowrap">
        <span className="opacity-50"> {localeString.installmentTotal->React.string} </span>
        <span
          style={
            fontWeight: themeObj.fontWeightMedium,
          }>
          {`${currency} ${totalAmount}`->React.string}
        </span>
      </div>
    </div>
  </div>
}
