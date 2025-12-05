open SamsungPayType
open Utils

let getTransactionDetail = dict => {
  let amountDict = dict->getDictFromDict("amount")
  let merchantDict = dict->getDictFromDict("merchant")
  {
    orderNumber: dict->getString("order_number", ""),
    amount: {
      option: amountDict->getString("option", ""),
      currency: amountDict->getString("currency_code", ""),
      total: amountDict->getString("total", ""),
    },
    merchant: {
      name: merchantDict->getString("name", ""),
      countryCode: merchantDict->getString("country_code", ""),
      url: merchantDict->getString("url", ""),
    },
  }
}

let handleSamsungPayClicked = (~sessionObj, ~componentName, ~iframeId, ~readOnly) => {
  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", "paymentloader"->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
    ("componentName", componentName->JSON.Encode.string),
  ])

  if !readOnly {
    messageParentWindow([
      ("SamsungPayClicked", true->JSON.Encode.bool),
      ("SPayPaymentDataRequest", getTransactionDetail(sessionObj)->Identity.anyTypeToJson),
    ])
  }
}

let getPaymentMethodData = dict => {
  let threeDSDict = dict->getDictFromDict("3DS")

  {
    method: dict->getString("method", ""),
    recurring_payment: dict->getBool("recurring_payment", false),
    card_brand: dict->getString("card_brand", ""),
    card_last4digits: dict->getString("card_last4digits", ""),
    threeDS: {
      \"type": threeDSDict->getString("type", ""),
      version: threeDSDict->getString("version", ""),
      data: threeDSDict->getString("data", ""),
    },
  }
}

let itemToObjMapper = dict => {
  paymentMethodData: getPaymentMethodData(dict),
}

let getSamsungPayBodyFromResponse = (~sPayResponse) => {
  sPayResponse->getDictFromJson->itemToObjMapper
}

let useHandleSamsungPayResponse = (
  ~intent: PaymentHelpersTypes.paymentIntent,
  ~isSavedMethodsFlow=false,
  ~isWallet=true,
) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  React.useEffect0(() => {
    let handleSamsung = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson
      if dict->Dict.get("samsungPayResponse")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("samsungPayResponse")
        let getBody = getSamsungPayBodyFromResponse(~sPayResponse=metadata)
        let body = PaymentBody.samsungPayBody(
          ~metadata=getBody.paymentMethodData->Identity.anyTypeToJson,
        )

        let finalBody = PaymentUtils.appendedCustomerAcceptance(
          ~paymentType=paymentMethodListValue.payment_type,
          ~body,
        )

        intent(
          ~bodyArr=finalBody,
          ~confirmParam={
            return_url: options.wallets.walletReturnUrl,
            publishableKey,
          },
          ~handleUserError=false,
          ~manualRetry=isManualRetryEnabled,
        )
      }
      if dict->Dict.get("samsungPayError")->Option.isSome {
        messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
        if isSavedMethodsFlow || !isWallet {
          postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
        }
      }
    }
    Window.addEventListener("message", handleSamsung)
    Some(() => {Window.removeEventListener("message", handleSamsung)})
  })
}
