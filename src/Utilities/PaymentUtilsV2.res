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
    if item.paymentMethodType == "card" {
      otherPaymentList->Array.push("card")->ignore
    }
  })

  {
    walletsList: walletsList->Utils.removeDuplicate,
    otherPaymentList: otherPaymentList->Utils.removeDuplicate,
  }
}

let useGetPaymentMethodListV2 = (~paymentOptions) => {
  open Utils
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)

  let resolvePaymentList = list => {
    switch list {
    | LoadedV2(paymentlist) =>
      let {otherPaymentList} = paymentListLookupNew(~paymentMethodListValue=paymentlist)
      let payments = [...paymentOptions, ...otherPaymentList]->removeDuplicate

      (payments, otherPaymentList)
    | _ => ([], [])
    }
  }

  React.useMemo(() => {
    resolvePaymentList(methodslist)
  }, [methodslist])
}

let getCreditFieldsRequired = (~paymentManagementListValue: paymentMethodsManagement) => {
  paymentManagementListValue.paymentMethodsEnabled->Array.filter(item => {
    item.paymentMethodType === "card" && item.paymentMethodSubtype === "credit"
  })
}

let getPaymentMethodTypeFromListV2 = (~paymentsListValueV2, ~paymentMethod, ~paymentMethodType) => {
  open UnifiedHelpersV2
  paymentsListValueV2.paymentMethodsEnabled
  ->Array.find(item => {
    item.paymentMethodSubtype === paymentMethodType && item.paymentMethodType === paymentMethod
  })
  ->Option.getOr(defaultPaymentMethods)
}

let usePaymentMethodTypeFromListV2 = (~paymentsListValueV2, ~paymentMethod, ~paymentMethodType) => {
  React.useMemo(() => {
    getPaymentMethodTypeFromListV2(
      ~paymentsListValueV2,
      ~paymentMethod,
      ~paymentMethodType=PaymentUtils.getPaymentMethodName(
        ~paymentMethodType=paymentMethod,
        ~paymentMethodName=paymentMethodType,
      ),
    )
  }, (paymentsListValueV2, paymentMethod, paymentMethodType))
}
