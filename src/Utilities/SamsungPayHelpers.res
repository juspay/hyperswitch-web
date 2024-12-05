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
