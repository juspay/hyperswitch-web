@react.component
let make = (
  ~plan: PaymentMethodsRecord.installmentPlan,
  ~currency,
  ~isSelected,
  ~onSelect,
  ~isLastItem,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let installmentConfig = CustomPaymentMethodsConfig.useInstallmentConfig(~paymentMethod="card")

  let formatInterestRate = interestRate => Utils.formatAmountWithTwoDecimals(interestRate)

  let getInterestLabel = interestRate =>
    interestRate == 0.0
      ? localeString.installmentInterestFree
      : localeString.installmentInterestRate(formatInterestRate(interestRate))

  let amountPerInstallment = Utils.formatAmountWithTwoDecimals(
    plan.amount_details.amount_per_installment,
  )
  let totalAmount = Utils.formatAmountWithTwoDecimals(plan.amount_details.total_amount)
  let numberOfInstallments = plan.number_of_installments
  let interestLabel = getInterestLabel(plan.interest_rate)
  let showInterestRates = installmentConfig
    ->Option.map(c => c.showInterestRates == Auto)
    ->Option.getOr(true)

  let mainInstallmentLabel = localeString.installmentPaymentLabel(
    numberOfInstallments,
    currency,
    amountPerInstallment,
  )

  <div
    onClick={_ => onSelect()}
    style={
      padding: themeObj.spacingUnit,
      borderColor: themeObj.borderColor,
    }
    className={`flex gap-3 w-full ${isLastItem ? "" : "border-b"} !px-0 cursor-pointer text-left`}>
    <div className="pt-1" style={color: isSelected ? themeObj.colorPrimary : ""}>
      <Radio checked=isSelected />
    </div>
    <div className="flex flex-col w-full">
      <div className="flex w-full justify-between gap-1">
        <div className="flex">
          <span className="mr-0.5"> {mainInstallmentLabel->React.string} </span>
        </div>
        <div
          className="opacity-60 text-nowrap"
          style={
            fontSize: themeObj.fontSizeSm,
          }>
          {localeString.installmentTotalPayable->React.string}
        </div>
      </div>
      <div className="flex flex-row w-full justify-between">
        <RenderIf condition={showInterestRates}>
          <span
            className="opacity-60"
            style={
              fontSize: themeObj.fontSizeSm,
            }>
            {interestLabel->React.string}
          </span>
        </RenderIf>
        <span
          style={
            color: themeObj.colorText,
          }>
          {`${currency} ${totalAmount}`->React.string}
        </span>
      </div>
    </div>
  </div>
}
