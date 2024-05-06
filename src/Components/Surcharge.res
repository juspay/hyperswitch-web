@react.component
let make = (
  ~paymentMethod,
  ~paymentMethodType,
  ~cardBrand=CardUtils.NOTFOUND,
  ~isForWallets=false,
) => {
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let getPaymentMethodTypes = paymentMethodType => {
    PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~paymentMethodListValue,
      ~paymentMethod,
      ~paymentMethodType=PaymentUtils.getPaymentMethodName(
        ~paymentMethodType=paymentMethod,
        ~paymentMethodName=paymentMethodType,
      ),
    )->Option.getOr(PaymentMethodsRecord.defaultPaymentMethodType)
  }

  let paymentMethodTypes = paymentMethodType->getPaymentMethodTypes

  let getOneClickWalletsMessage = SurchargeUtils.useOneClickWalletsMessageGetter(
    ~paymentMethodListValue,
  )
  let getSurchargeUtilsMessage = SurchargeUtils.useMessageGetter()

  let getSurchargeMessage = () => {
    if isForWallets {
      getOneClickWalletsMessage()
    } else {
      switch paymentMethodTypes.surcharge_details {
      | Some(surchargeDetails) =>
        getSurchargeUtilsMessage(~paymentMethod, ~surchargeDetails, ~paymentMethodListValue)
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
              getSurchargeUtilsMessage(
                ~paymentMethod,
                ~surchargeDetails={creditSurchargeDetails},
                ~paymentMethodListValue,
              )
            } else {
              getSurchargeUtilsMessage(
                ~paymentMethod,
                ~surchargeDetails={debitSurchargeDetails},
                ~paymentMethodListValue,
              )
            }
          | (None, Some(surchargeDetails))
          | (Some(surchargeDetails), None) =>
            getSurchargeUtilsMessage(~paymentMethod, ~surchargeDetails, ~paymentMethodListValue)
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
