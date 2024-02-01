@react.component
let make = (
  ~list,
  ~paymentMethod,
  ~paymentMethodType,
  ~cardBrand=CardUtils.NOTFOUND,
  ~isForWallets=false,
) => {
  let getPaymentMethodTypes = paymentMethodType => {
    PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~list,
      ~paymentMethod,
      ~paymentMethodType=PaymentUtils.getPaymentMethodName(
        ~paymentMethodType=paymentMethod,
        ~paymentMethodName=paymentMethodType,
      ),
    )->Belt.Option.getWithDefault(PaymentMethodsRecord.defaultPaymentMethodType)
  }

  let paymentMethodTypes = paymentMethodType->getPaymentMethodTypes

  let getSurchargeMessage = () => {
    if isForWallets {
      SurchargeUtils.getOneClickWalletsMessage(~list)
    } else {
      switch paymentMethodTypes.surcharge_details {
      | Some(surchargeDetails) => SurchargeUtils.getMessage(~paymentMethod, ~surchargeDetails)
      | None =>
        if paymentMethod === "card" {
          let creditPaymentMethodTypes = getPaymentMethodTypes("credit")

          let debitCardNetwork = PaymentMethodsRecord.getCardNetwork(
            ~paymentMethodType=paymentMethodTypes,
            ~cardBrand,
          )
          let creditCardNetwork = PaymentMethodsRecord.getCardNetwork(
            ~paymentMethodType=creditPaymentMethodTypes,
            ~cardBrand,
          )

          switch (debitCardNetwork.surcharge_details, creditCardNetwork.surcharge_details) {
          | (Some(debitSurchargeDetails), Some(creditSurchargeDetails)) =>
            let creditCardSurcharge = creditSurchargeDetails.displayTotalSurchargeAmount
            let debitCardSurcharge = debitSurchargeDetails.displayTotalSurchargeAmount

            if creditCardSurcharge >= debitCardSurcharge {
              SurchargeUtils.getMessage(~paymentMethod, ~surchargeDetails={creditSurchargeDetails})
            } else {
              SurchargeUtils.getMessage(~paymentMethod, ~surchargeDetails={debitSurchargeDetails})
            }
          | (None, Some(surchargeDetails))
          | (Some(surchargeDetails), None) =>
            SurchargeUtils.getMessage(~paymentMethod, ~surchargeDetails)
          | (None, None) => None
          }
        } else {
          None
        }
      }
    }
  }

  switch getSurchargeMessage() {
  | Some(surchargeMessage) =>
    <div className="flex items-baseline text-xs mt-2">
      <Icon name="asterisk" size=8 className="text-red-600 mr-1" />
      <em className="text-left text-gray-400"> {surchargeMessage} </em>
    </div>
  | None => React.null
  }
}
