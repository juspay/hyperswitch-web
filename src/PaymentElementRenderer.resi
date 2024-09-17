@react.component
let make: (
  ~paymentType: CardThemeType.mode,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
) => React.element
let default: props<
  CardThemeType.mode,
  CardUtils.cardProps,
  CardUtils.expiryProps,
  CardUtils.cvcProps,
> => React.element
