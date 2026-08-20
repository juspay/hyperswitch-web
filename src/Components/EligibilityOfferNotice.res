@react.component
let make = (
  ~eligibilityOfferDetails: option<EligibilityHelpers.eligibilityOfferDetails>,
  ~isEligibilityPending=false,
  ~className="",
) => {
  let {themeObj} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let successColor = themeObj.colorSuccess

  let appliedOffer =
    eligibilityOfferDetails
    ->Option.map(details => details.eligibleOffers)
    ->Option.getOr([])
    ->Array.get(0)

  <RenderIf condition={isEligibilityPending || appliedOffer->Option.isSome}>
    <div
      className={`box-border flex w-full min-w-0 max-w-full flex-col overflow-hidden ${className}`}
      style={
        color: themeObj.colorText,
        fontWeight: themeObj.fontWeightNormal,
        fontSize: themeObj.fontSizeLg,
      }
      ariaLabel="Eligible offers"
    >
      {if isEligibilityPending {
        <div
          className="w-full rounded-md px-3 py-3 text-left"
          style={border: `1px solid ${themeObj.borderColor}`}
          role="status"
          ariaLive=#polite
        >
          <span className="sr-only"> {"Checking eligible offers"->React.string} </span>
          <div className="flex flex-col gap-2" ariaHidden=true>
            <div
              className="relative h-2.5 w-[120px] overflow-hidden rounded"
              style={backgroundColor: themeObj.borderColor, opacity: "0.75"}
            >
              <div
                className="absolute inset-0 -translate-x-full animate-[shimmer_1.4s_ease_infinite] bg-gradient-to-r from-transparent via-white/70 to-transparent"
              />
            </div>
            <div
              className="relative h-2.5 w-3/4 overflow-hidden rounded"
              style={backgroundColor: themeObj.borderColor, opacity: "0.75"}
            >
              <div
                className="absolute inset-0 -translate-x-full animate-[shimmer_1.4s_ease_infinite] bg-gradient-to-r from-transparent via-white/70 to-transparent"
              />
            </div>
          </div>
        </div>
      } else {
        switch appliedOffer {
        | Some(offer) =>
          let offerTitle = offer.title === "" ? "Card offer" : offer.title
          <div
            className="relative overflow-hidden"
            style={
              border: "1px solid transparent",
              borderRadius: themeObj.borderRadius,
              backgroundColor: themeObj.colorBackground,
            }
            role="status"
            ariaLive=#polite
          >
            <div
              className="pointer-events-none absolute inset-0"
              style={
                border: `1px solid ${successColor}`,
                borderRadius: themeObj.borderRadius,
                opacity: "0.35",
              }
              ariaHidden=true
            />
            <div
              className="flex w-full items-center gap-2 text-left"
              style={
                padding: `calc(${themeObj.spacingUnit} * 0.8) ${themeObj.spacingUnit}`,
                backgroundColor: themeObj.colorBackground,
              }
            >
              <div
                className="relative flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-sm font-semibold"
                style={color: successColor}
                ariaHidden=true
              >
                <div
                  className="pointer-events-none absolute inset-0 rounded-full"
                  style={backgroundColor: successColor, opacity: "0.16"}
                />
                <span className="relative"> {"%"->React.string} </span>
              </div>
              <div className="flex min-w-0 flex-1 flex-col">
                <div
                  className="min-w-0 whitespace-normal break-words"
                  style={minHeight: `calc(${themeObj.fontSizeLg} * 1.5)`}
                >
                  <span
                    className="min-w-0" style={fontSize: themeObj.fontSizeLg, color: successColor}
                  >
                    {offerTitle->React.string}
                  </span>
                  <RenderIf condition={offer.code !== ""}>
                    <span
                      className="ml-2 inline-block whitespace-nowrap rounded border border-dashed px-1 py-0 font-medium"
                      style={
                        color: successColor,
                        borderColor: successColor,
                        fontSize: themeObj.fontSizeXs,
                        verticalAlign: "text-top",
                      }
                    >
                      {offer.code->React.string}
                    </span>
                  </RenderIf>
                </div>
                <RenderIf condition={offer.description !== ""}>
                  <div
                    className="mt-px flex min-w-0 items-center whitespace-normal break-words"
                    style={
                      color: themeObj.colorTextSecondary,
                      minHeight: `calc(${themeObj.fontSizeLg} * 1.5)`,
                    }
                  >
                    <span className="min-w-0" style={fontSize: themeObj.fontSizeSm}>
                      {offer.description->React.string}
                    </span>
                  </div>
                </RenderIf>
              </div>
              <div
                className="ml-0.5 flex shrink-0 items-center gap-1 whitespace-nowrap"
                style={
                  color: successColor,
                  fontSize: themeObj.fontSizeSm,
                  fontWeight: themeObj.fontWeightMedium,
                }
              >
                <Icon name="checkmark" size=14 />
                <span> {"Applied"->React.string} </span>
              </div>
            </div>
          </div>
        | None => React.null
        }
      }}
    </div>
  </RenderIf>
}
