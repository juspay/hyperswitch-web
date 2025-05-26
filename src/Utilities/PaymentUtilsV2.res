open UnifiedPaymentsTypesV2

let paymentListLookupNew = (~paymentMethodListValue: paymentMethodsManagement) => {
  let walletsList = []
  let walletToBeDisplayedInTabs = [
    "mb_way",
    "ali_pay",
    "ali_pay_hk",
    "mobile_pay",
    "we_chat_pay",
    "vipps",
    "twint",
    "dana",
    "go_pay",
    "kakao_pay",
    "gcash",
    "momo",
    "touch_n_go",
    "mifinity",
  ]
  let otherPaymentList = []

  paymentMethodListValue.paymentMethodsEnabled->Array.forEach(item => {
    if walletToBeDisplayedInTabs->Array.includes(item.paymentMethodType) {
      otherPaymentList->Array.push(item.paymentMethodType)->ignore
    } else if item.paymentMethodType == "card" {
      otherPaymentList->Array.push("card")->ignore
    }
  })
  (walletsList->Utils.removeDuplicate, otherPaymentList->Utils.removeDuplicate)
}

let useGetPaymentMethodListV2 = (~paymentOptions, ~paymentType: CardThemeType.mode) => {
  open Utils
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let paymentsList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentMethodsListV2)

  React.useMemo(() => {
    let resolvePaymentList = list =>
      switch list {
      | LoadedV2(paymentlist) =>
        let (_wallets, otherOptions) = paymentListLookupNew(~paymentMethodListValue=paymentlist)
        (
          paymentOptions
          ->Array.concat(otherOptions)
          ->removeDuplicate,
          otherOptions,
        )
      | _ => (["card"], [])
      }

    switch paymentType {
    | Payment => resolvePaymentList(paymentsList)
    | _ => resolvePaymentList(methodslist)
    }
  }, (methodslist, paymentType))
}

let getCreditFieldsRequired = (~paymentManagementListValue: paymentMethodsManagement) => {
  paymentManagementListValue.paymentMethodsEnabled->Array.filter(item => {
    item.paymentMethodType === "card" && item.paymentMethodSubtype === "credit"
  })
}

let getSupportedCardBrandsV2 = (paymentsListValue: paymentMethodsManagement) => {
  let cardPaymentMethod =
    paymentsListValue.paymentMethodsEnabled->Array.find(ele => ele.paymentMethodType === "card")

  switch cardPaymentMethod {
  | Some(cardPaymentMethod) =>
    let cardNetworks = cardPaymentMethod.cardNetworks->Option.getOr([])
    let cardNetworkNames =
      cardNetworks->Array.map(ele =>
        ele.cardNetwork->CardUtils.getCardStringFromType->String.toLowerCase
      )

    cardNetworkNames->Array.length > 0 ? Some(cardNetworkNames) : None

  | None => None
  }
}
