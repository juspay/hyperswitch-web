open LazyUtils

@obj
external makeProps: (
  ~paymentType: CardThemeType.mode,
  ~cardProps: 'a,
  ~expiryProps: 'b,
  ~cvcProps: 'c,
  ~zipProps: 'd,
  ~handleElementFocus: bool => unit,
  ~isFocus: bool,
  unit,
) => componentProps = ""

let make = reactLazy(.() => import_("./SingleLineCardPayment.bs.js"))
