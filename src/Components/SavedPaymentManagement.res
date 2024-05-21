@react.component
let make = (~savedMethods: array<PaymentType.customerMethods>) => {
  open CardUtils
  open Utils

  let getWalletBrandIcon = (obj: PaymentType.customerMethods) => {
    switch obj.paymentMethodType {
    | Some("apple_pay") => <Icon size=brandIconSize name="apple_pay_saved" />
    | Some("google_pay") => <Icon size=brandIconSize name="google_pay_saved" />
    | Some("paypal") => <Icon size=brandIconSize name="paypal" />
    | _ => <Icon size=brandIconSize name="default-card" />
    }
  }

  savedMethods
  ->Array.mapWithIndex((obj, i) => {
    let brandIcon = switch obj.paymentMethod {
    | "wallet" => getWalletBrandIcon(obj)
    | _ =>
      getCardBrandIcon(
        switch obj.card.scheme {
        | Some(ele) => ele
        | None => ""
        }->getCardType,
        ""->CardThemeType.getPaymentMode,
      )
    }
    <SavedMethodItem key={i->Int.toString} paymentItem=obj brandIcon />
  })
  ->React.array
}
