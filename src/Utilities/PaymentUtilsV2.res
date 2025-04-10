open PMMTypesV2

let paymentListLookupNew = (~paymentMethodListValue: PMMTypesV2.paymentMethodsManagement) => {
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

let useGetPaymentMethodListV2 = (~paymentOptions, ~paymentType) => {
  open Utils
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)

  React.useMemo(() => {
    switch methodslist {
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
  }, (methodslist, paymentType))
}

let getCreditFieldsRequired = (
  ~paymentManagementListValue: PMMTypesV2.paymentMethodsManagement,
) => {
  paymentManagementListValue.paymentMethodsEnabled->Array.filter(item => {
    item.paymentMethodType === "card" && item.paymentMethodSubType === "credit"
  })
}
