@react.component
let make = (
  ~eligibilitySurchargeDetails: option<EligibilityHelpers.eligibilitySurchargeDetails>,
  ~isEligibilityPending=false,
  ~className="",
) => {
  let {themeObj, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let surchargeAmount =
    eligibilitySurchargeDetails
    ->Option.map(s => s.displayTotalSurchargeAmount->Float.toString)
    ->Option.getOr("")

  <RenderIf condition={isEligibilityPending || eligibilitySurchargeDetails->Option.isSome}>
    <div className={`w-full ${className}`}>
      {if isEligibilityPending {
        <div className="w-full" role="status" ariaLive=#polite ariaAtomic=true>
          <span className="sr-only">
            {localeString.paymentDetailsBeingCheckedText->React.string}
          </span>
          <div
            className="relative h-2.5 w-[72%] overflow-hidden rounded"
            style={backgroundColor: themeObj.borderColor, opacity: "0.75"}
            ariaHidden=true>
            <div
              className="absolute inset-0 -translate-x-full animate-[shimmer_1.4s_ease_infinite] bg-gradient-to-r from-transparent via-white/70 to-transparent"
            />
          </div>
        </div>
      } else {
        <div className="flex items-start text-xs" role="status" ariaLive=#polite ariaAtomic=true>
          <span ariaHidden=true>
            <Icon name="asterisk" size=8 className="text-red-600 mr-1 mt-[3px] shrink-0" />
          </span>
          <div
            className="text-left"
            style={
              color: themeObj.colorTextSecondary,
              lineHeight: "1.45",
            }>
            {localeString.surchargeMsgAmountForCard(
              paymentMethodListValue.currency,
              surchargeAmount,
            )}
          </div>
        </div>
      }}
    </div>
  </RenderIf>
}
