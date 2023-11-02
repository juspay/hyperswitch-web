open LazyUtils

@obj
external makeProps: (
  ~paymentType: CardThemeType.mode,
  ~cardProps: 'a,
  ~expiryProps: 'b,
  ~cvcProps: 'c,
  ~countryProps: (string, Js.Array2.t<string>),
  unit,
) => componentProps = ""

let make = reactLazy(.() => import_("./PaymentElementRenderer.bs.js"))
