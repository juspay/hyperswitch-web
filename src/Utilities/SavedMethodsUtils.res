let handleSavedMethodChanged = (
  ~setPaymentToken,
  ~paymentItem: PaymentType.customerMethods,
  ~clickToPayConfig: RecoilAtoms.clickToPayConfig,
  ~isClickToPayRememberMe,
  ~isSavedMethodChangedCallbackEnabled,
) => {
  open RecoilAtomTypes
  setPaymentToken(_ => {
    paymentToken: paymentItem.paymentToken,
    customerId: paymentItem.customerId,
  })

  let clickToPayToken = clickToPayConfig.clickToPayToken

  switch clickToPayToken {
  | Some(token) =>
    Utils.messageParentWindow([
      ("handleClickToPayPayment", true->JSON.Encode.bool),
      ("paymentToken", paymentItem.paymentToken->JSON.Encode.string),
      ("clickToPayToken", token->ClickToPayHelpers.clickToPayToJsonItemToObjMapper),
    ])
  | None => ()
  }

  switch clickToPayToken {
  | Some(token) =>
    Utils.messageParentWindow([
      ("onSavedMethodChanged", true->JSON.Encode.bool),
      ("paymentToken", paymentItem.paymentToken->JSON.Encode.string),
      ("clickToPayToken", token->ClickToPayHelpers.clickToPayToJsonItemToObjMapper),
      (
        "clickToPayProvider",
        clickToPayConfig.clickToPayProvider
        ->ClickToPayHelpers.getStrFromCtpProvider
        ->JSON.Encode.string,
      ),
      ("isClickToPayRememberMe", isClickToPayRememberMe->JSON.Encode.bool),
    ])

    Console.log2("===> isSavedMethodChangedCallbackEnabled", isSavedMethodChangedCallbackEnabled)

    if isSavedMethodChangedCallbackEnabled {
      Utils.handleOnSavedMethodChangedPostMessage()
    }
  | None => ()
  }
}
