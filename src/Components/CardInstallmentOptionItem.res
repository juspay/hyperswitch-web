@react.component
let make = (
  ~plan: InstallmentTypes.installmentPlan,
  ~currency,
  ~isSelected: bool,
  ~onSelect: unit => unit,
  ~themeObj: CardThemeType.themeClass,
  ~isLastItem,
) => {
  let formatAmount = (amount: int) => {
    let amountFloat = amount->Int.toFloat
    let amountStr = amountFloat->Float.toString
    let parts = amountStr->String.split(".")
    let wholePart = parts->Array.get(0)->Option.getOr("0")
    let decimalPart = parts->Array.get(1)->Option.getOr("00")
    let paddedDecimal = if decimalPart->String.length < 2 {
      decimalPart ++ "0"
    } else if decimalPart->String.length > 2 {
      decimalPart->String.slice(~start=0, ~end=2)
    } else {
      decimalPart
    }
    `${wholePart}.${paddedDecimal}`
  }

  let getInterestLabel = interestRate =>
    interestRate == 0.0 ? "Interest free" : `${interestRate->Float.toString}% interest`

  let amountPerInstallment = formatAmount(plan.amount_details.amount_per_installment)
  let totalAmount = formatAmount(plan.amount_details.total_amount)
  let numberOfInstallments = plan.number_of_installments
  let interestLabel = getInterestLabel(plan.interest_rate)

  let mainInstallmentLabel = `${numberOfInstallments->Int.toString} ${numberOfInstallments > 1
      ? "payments"
      : "payment"} of ${currency} ${amountPerInstallment}`

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
          {"Total payable"->React.string}
        </div>
      </div>
      <div className="flex flex-row w-full justify-between">
        <span
          className="opacity-60"
          style={
            fontSize: themeObj.fontSizeSm,
          }>
          {interestLabel->React.string}
        </span>
        <span
          style={
            color: themeObj.colorText,
          }>
          {totalAmount->React.string}
        </span>
      </div>
    </div>
  </div>
}
