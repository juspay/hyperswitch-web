@react.component
let default: (
  ~paymentType: CardThemeType.mode,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~zipProps: CardUtils.zipProps,
  ~handleElementFocus: bool => unit,
  ~isFocus: bool,
) => React.element
