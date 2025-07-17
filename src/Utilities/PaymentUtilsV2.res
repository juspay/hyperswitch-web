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
    } else if item.paymentMethodType == "wallet" {
      if item.paymentMethodSubtype !== "paypal" {
        walletsList->Array.push(item.paymentMethodSubtype)->ignore
      }
    } else if item.paymentMethodType == "bank_redirect" {
      otherPaymentList->Array.push(item.paymentMethodSubtype)->ignore
    } else if item.paymentMethodType == "bank_debit" {
      otherPaymentList->Array.push(item.paymentMethodSubtype ++ "_debit")->ignore
    } else if item.paymentMethodType == "pay_later" {
      if item.paymentMethodSubtype === "klarna" {
        let klarnaPaymentMethodExperience = V2Helpers.getPaymentExperienceTypeFromPML(
          ~paymentMethodList=paymentMethodListValue,
          ~paymentMethodName=item.paymentMethodType,
          ~paymentMethodType=item.paymentMethodSubtype,
        )

        let isRedirectExperience = klarnaPaymentMethodExperience->Array.includes(RedirectToURL)

        if isRedirectExperience {
          otherPaymentList->Array.push(item.paymentMethodSubtype)->ignore
        }
      }
    } else if item.paymentMethodType == "card" {
      otherPaymentList->Array.push("card")->ignore
    }
  })

  {
    walletsList: walletsList->Utils.removeDuplicate,
    otherPaymentList: otherPaymentList->Utils.removeDuplicate,
  }
}

let useGetPaymentMethodListV2 = (~paymentOptions, ~paymentType: CardThemeType.mode) => {
  open Utils
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let paymentsList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentMethodsListV2)

  let resolvePaymentList = list => {
    switch list {
    | LoadedV2(paymentlist) =>
      let {walletsList, otherPaymentList} = paymentListLookupNew(
        ~paymentMethodListValue=paymentlist,
      )
      let wallets = walletsList->removeDuplicate->Utils.getWalletPaymentMethod(paymentType)
      let payments = [...paymentOptions, ...otherPaymentList]->removeDuplicate

      (wallets, payments, otherPaymentList)
    | _ => ([], [], [])
    }
  }

  React.useMemo(() => {
    let listToUse = switch paymentType {
    | Payment => paymentsList
    | _ => methodslist
    }
    resolvePaymentList(listToUse)
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

let buildFromPaymentListV2 = (plist: UnifiedPaymentsTypesV2.paymentMethodsManagement) => {
  open PaymentMethodsRecord
  let paymentMethodArr = plist.paymentMethodsEnabled

  paymentMethodArr->Array.map(paymentMethodObject => {
    let methodType = paymentMethodObject.paymentMethodType
    let handleUserError = methodType === "wallet"
    let paymentMethodName = paymentMethodObject.paymentMethodSubtype
    let bankNamesList = paymentMethodObject.bankNames->Option.getOr([])
    // TODO - Handle Payment Experience
    {
      paymentMethodName,
      fields: getPaymentMethodFields(paymentMethodName, paymentMethodObject.requiredFields),
      paymentFlow: [],
      handleUserError,
      methodType,
      bankNames: bankNamesList,
    }
  })
}
