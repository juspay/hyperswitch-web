let getWalletBrandIcon = (customerMethod: PMMTypesV2.customerMethods) => {
  let iconName = switch customerMethod.paymentMethodType {
  | "apple_pay" => "apple_pay_saved"
  | "google_pay" => "google_pay_saved"
  | "paypal" => "paypal"
  | _ => "default-card"
  }

  <Icon size=Utils.brandIconSize name=iconName />
}

let getPaymentMethodBrand = (customerMethod: PMMTypesV2.customerMethods) => {
  switch customerMethod.paymentMethodType {
  | "wallet" => getWalletBrandIcon(customerMethod)
  | _ =>
    CardUtils.getCardBrandIcon(
      switch customerMethod.paymentMethodData.card.network {
      | Some(ele) => ele
      | None => ""
      }->CardUtils.getCardType,
      ""->CardThemeType.getPaymentMode,
    )
  }
}
