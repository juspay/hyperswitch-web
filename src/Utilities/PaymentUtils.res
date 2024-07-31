let paymentMethodListValue = Recoil.atom("paymentMethodListValue", PaymentMethodsRecord.defaultList)

let paymentListLookupNew = (
  list: PaymentMethodsRecord.paymentMethodList,
  ~order,
  ~isShowPaypal,
  ~isShowKlarnaOneClick,
  ~isKlarnaSDKFlow,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
  ~areAllApplePayRequiredFieldsPrefilled,
  ~areAllGooglePayRequiredFieldsPrefilled,
  ~isApplePayReady,
  ~isGooglePayReady,
) => {
  let pmList = list->PaymentMethodsRecord.buildFromPaymentList
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
    "samsung_pay",
    "mifinity",
  ]
  let otherPaymentList = []

  if (
    !paymentMethodListValue.collect_billing_details_from_wallets &&
    !areAllApplePayRequiredFieldsPrefilled &&
    isApplePayReady
  ) {
    walletToBeDisplayedInTabs->Array.push("apple_pay")
  }

  if (
    !paymentMethodListValue.collect_billing_details_from_wallets &&
    !areAllGooglePayRequiredFieldsPrefilled &&
    isGooglePayReady
  ) {
    walletToBeDisplayedInTabs->Array.push("google_pay")
  }

  pmList->Array.forEach(item => {
    if walletToBeDisplayedInTabs->Array.includes(item.paymentMethodName) {
      otherPaymentList->Array.push(item.paymentMethodName)->ignore
    } else if item.methodType == "wallet" {
      if item.paymentMethodName !== "paypal" || isShowPaypal {
        walletsList->Array.push(item.paymentMethodName)->ignore
      }
    } else if item.methodType == "bank_debit" {
      otherPaymentList->Array.push(item.paymentMethodName ++ "_debit")->ignore
    } else if item.methodType == "bank_transfer" {
      otherPaymentList->Array.push(item.paymentMethodName ++ "_transfer")->ignore
    } else if item.methodType == "card" {
      otherPaymentList->Array.push("card")->ignore
    } else if item.methodType == "reward" {
      otherPaymentList->Array.push(item.paymentMethodName)->ignore
    } else if item.methodType == "pay_later" {
      if item.paymentMethodName === "klarna" {
        let klarnaPaymentMethodExperience = PaymentMethodsRecord.getPaymentExperienceTypeFromPML(
          ~paymentMethodList=paymentMethodListValue,
          ~paymentMethodName=item.methodType,
          ~paymentMethodType=item.paymentMethodName,
        )

        let isInvokeSDKExperience = klarnaPaymentMethodExperience->Array.includes(InvokeSDK)
        let isRedirectExperience = klarnaPaymentMethodExperience->Array.includes(RedirectToURL)

        if isKlarnaSDKFlow && isShowKlarnaOneClick && isInvokeSDKExperience {
          walletsList->Array.push(item.paymentMethodName)->ignore
        } else if isRedirectExperience {
          otherPaymentList->Array.push(item.paymentMethodName)->ignore
        }
      } else {
        otherPaymentList->Array.push(item.paymentMethodName)->ignore
      }
    } else {
      otherPaymentList->Array.push(item.paymentMethodName)->ignore
    }
  })
  (
    walletsList->Utils.removeDuplicate->Utils.sortBasedOnPriority(order),
    otherPaymentList->Utils.removeDuplicate->Utils.sortBasedOnPriority(order),
  )
}
type exp = Redirect | SDK
type paylater = Klarna(exp) | AfterPay(exp) | Affirm(exp)
type wallet = Gpay(exp) | ApplePay(exp) | Paypal(exp)
type card = Credit(exp) | Debit(exp)
type banks = Sofort | Eps | GiroPay | Ideal
type transfer = ACH | Sepa | Bacs
type connectorType =
  | PayLater(paylater)
  | Wallets(wallet)
  | Cards(card)
  | Banks(banks)
  | BankTransfer(transfer)
  | BankDebit(transfer)
  | Crypto

let getMethod = method => {
  switch method {
  | PayLater(_) => "pay_later"
  | Wallets(_) => "wallet"
  | Cards(_) => "card"
  | Banks(_) => "bank_redirect"
  | BankTransfer(_) => "bank_transfer"
  | BankDebit(_) => "bank_debit"
  | Crypto => "crypto"
  }
}

let getMethodType = method => {
  switch method {
  | PayLater(val) =>
    switch val {
    | Klarna(_) => "klarna"
    | AfterPay(_) => "afterpay_clearpay"
    | Affirm(_) => "affirm"
    }
  | Wallets(val) =>
    switch val {
    | Gpay(_) => "google_pay"
    | ApplePay(_) => "apple_pay"
    | Paypal(_) => "paypal"
    }
  | Cards(_) => "card"
  | Banks(val) =>
    switch val {
    | Sofort => "sofort"
    | Eps => "eps"
    | GiroPay => "giropay"
    | Ideal => "ideal"
    }
  | BankDebit(val)
  | BankTransfer(val) =>
    switch val {
    | ACH => "ach"
    | Bacs => "bacs"
    | Sepa => "sepa"
    }
  | Crypto => "crypto_currency"
  }
}
let getExperience = (val: exp) => {
  switch val {
  | Redirect => "redirect_to_url"
  | SDK => "invoke_sdk_client"
  }
}
let getPaymentExperienceType = (val: PaymentMethodsRecord.paymentFlow) => {
  switch val {
  | RedirectToURL => "redirect_to_url"
  | InvokeSDK => "invoke_sdk_client"
  | QrFlow => "display_qr_code"
  }
}
let getExperienceType = method => {
  switch method {
  | PayLater(val) =>
    switch val {
    | Klarna(val) => val->getExperience
    | AfterPay(val) => val->getExperience
    | Affirm(val) => val->getExperience
    }
  | Wallets(val) =>
    switch val {
    | Gpay(val) => val->getExperience
    | ApplePay(val) => val->getExperience
    | Paypal(val) => val->getExperience
    }
  | Cards(_) => "card"
  | Crypto => "redirect_to_url"
  | _ => ""
  }
}

let getConnectors = (list: PaymentMethodsRecord.paymentMethodList, method: connectorType) => {
  let paymentMethod =
    list.payment_methods->Array.find(item => item.payment_method == method->getMethod)
  switch paymentMethod {
  | Some(val) =>
    let paymentMethodType =
      val.payment_method_types->Array.find(item =>
        item.payment_method_type == method->getMethodType
      )
    switch paymentMethodType {
    | Some(val) =>
      let experienceType = val.payment_experience->Array.find(item => {
        item.payment_experience_type->getPaymentExperienceType == method->getExperienceType
      })
      let eligibleConnectors = switch experienceType {
      | Some(val) => val.eligible_connectors
      | None => []
      }
      switch method {
      | Banks(_) => ([], val.bank_names)
      | BankTransfer(_) => (val.bank_transfers_connectors, [])
      | BankDebit(_) => (val.bank_debits_connectors, [])
      | _ => (eligibleConnectors, [])
      }
    | None => ([], [])
    }
  | None => ([], [])
  }
}
let getDisplayNameAndIcon = (
  customNames: PaymentType.customMethodNames,
  paymentMethodName,
  defaultName,
  defaultIcon,
) => {
  let customNameObj =
    customNames
    ->Array.filter((item: PaymentType.alias) => {
      item.paymentMethodName === paymentMethodName
    })
    ->Array.get(0)
  switch customNameObj {
  | Some(val) =>
    val.paymentMethodName === "classic" || val.paymentMethodName === "evoucher"
      ? {
          switch val.aliasName {
          | "" => (defaultName, defaultIcon)
          | aliasName =>
            let id = aliasName->String.split(" ")
            (
              aliasName,
              Some(PaymentMethodsRecord.icon(id->Array.get(0)->Option.getOr(""), ~size=19)),
            )
          }
        }
      : (defaultName, defaultIcon)
  | None => (defaultName, defaultIcon)
  }
}

let getPaymentMethodName = (~paymentMethodType, ~paymentMethodName) => {
  if paymentMethodType == "bank_debit" {
    paymentMethodName->String.replace("_debit", "")
  } else if paymentMethodType == "bank_transfer" {
    paymentMethodName->String.replace("_transfer", "")
  } else {
    paymentMethodName
  }
}

let isAppendingCustomerAcceptance = (
  ~isGuestCustomer,
  ~paymentType: PaymentMethodsRecord.payment_type,
) => {
  !isGuestCustomer && (paymentType === NEW_MANDATE || paymentType === SETUP_MANDATE)
}

let appendedCustomerAcceptance = (~isGuestCustomer, ~paymentType, ~body) => {
  isAppendingCustomerAcceptance(~isGuestCustomer, ~paymentType)
    ? body->Array.concat([("customer_acceptance", PaymentBody.customerAcceptanceBody)])
    : body
}

let usePaymentMethodTypeFromList = (
  ~paymentMethodListValue,
  ~paymentMethod,
  ~paymentMethodType,
) => {
  React.useMemo(() => {
    PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~paymentMethodListValue,
      ~paymentMethod,
      ~paymentMethodType=getPaymentMethodName(
        ~paymentMethodType=paymentMethod,
        ~paymentMethodName=paymentMethodType,
      ),
    )->Option.getOr(PaymentMethodsRecord.defaultPaymentMethodType)
  }, (paymentMethodListValue, paymentMethod, paymentMethodType))
}

let useAreAllRequiredFieldsPrefilled = (
  ~paymentMethodListValue,
  ~paymentMethod,
  ~paymentMethodType,
) => {
  let paymentMethodTypes = usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod,
    ~paymentMethodType,
  )

  paymentMethodTypes.required_fields->Array.reduce(true, (acc, requiredField) => {
    acc && requiredField.value != ""
  })
}

let getIsKlarnaSDKFlow = sessions => {
  let dict = sessions->Utils.getDictFromJson
  let sessionObj = SessionsType.itemToObjMapper(dict, Others)
  let klarnaTokenObj = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Klarna)
  switch klarnaTokenObj {
  | OtherTokenOptional(optToken) => optToken->Option.isSome
  | _ => false
  }
}

let useGetPaymentMethodList = (~paymentOptions, ~paymentType, ~sessions) => {
  open Utils
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)

  let {showCardFormByDefault, paymentMethodOrder} = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.optionAtom,
  )
  let optionAtomValue = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  let paymentOrder = paymentMethodOrder->getOptionalArr->removeDuplicate

  let isKlarnaSDKFlow = getIsKlarnaSDKFlow(sessions)

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(paymentMethodListValue)

  let areAllApplePayRequiredFieldsPrefilled = useAreAllRequiredFieldsPrefilled(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="apple_pay",
  )

  let areAllGooglePayRequiredFieldsPrefilled = useAreAllRequiredFieldsPrefilled(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="google_pay",
  )

  let isApplePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isApplePayReady)
  let isGooglePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isGooglePayReady)

  React.useMemo(() => {
    switch methodslist {
    | Loaded(paymentlist) =>
      let paymentOrder =
        paymentOrder->Array.length > 0 ? paymentOrder : PaymentModeType.defaultOrder
      let plist = paymentlist->getDictFromJson->PaymentMethodsRecord.itemToObjMapper
      let (wallets, otherOptions) =
        plist->paymentListLookupNew(
          ~order=paymentOrder,
          ~isShowPaypal=optionAtomValue.wallets.payPal === Auto,
          ~isShowKlarnaOneClick=optionAtomValue.wallets.klarna === Auto,
          ~isKlarnaSDKFlow,
          ~paymentMethodListValue=plist,
          ~areAllApplePayRequiredFieldsPrefilled,
          ~areAllGooglePayRequiredFieldsPrefilled,
          ~isApplePayReady,
          ~isGooglePayReady,
        )

      let klarnaPaymentMethodExperience = PaymentMethodsRecord.getPaymentExperienceTypeFromPML(
        ~paymentMethodList=plist,
        ~paymentMethodName="pay_later",
        ~paymentMethodType="klarna",
      )

      let isKlarnaInvokeSDKExperience = klarnaPaymentMethodExperience->Array.includes(InvokeSDK)

      let filterPaymentMethods = (paymentOptionsList: array<string>) => {
        paymentOptionsList->Array.filter(paymentOptionsName =>
          !(paymentOptionsName === "klarna" && isKlarnaSDKFlow && isKlarnaInvokeSDKExperience)
        )
      }

      (
        wallets->removeDuplicate->Utils.getWalletPaymentMethod(paymentType),
        paymentOptions
        ->Array.concat(otherOptions)
        ->removeDuplicate
        ->filterPaymentMethods,
        otherOptions,
      )
    | SemiLoaded =>
      showCardFormByDefault && checkPriorityList(paymentMethodOrder)
        ? ([], ["card"], [])
        : ([], [], [])
    | _ => ([], [], [])
    }
  }, (
    methodslist,
    paymentMethodOrder,
    optionAtomValue.wallets.payPal,
    optionAtomValue.wallets.klarna,
    paymentType,
    isKlarnaSDKFlow,
    areAllApplePayRequiredFieldsPrefilled,
    areAllGooglePayRequiredFieldsPrefilled,
    isApplePayReady,
    isGooglePayReady,
  ))
}

let useStatesJson = setStatesJson => {
  open Promise
  React.useEffect0(() => {
    AddressPaymentInput.importStates("./../States.json")
    ->then(res => {
      setStatesJson(_ => res.states)
      resolve()
    })
    ->ignore

    None
  })
}

let getStateJson = () => {
  open Promise
  AddressPaymentInput.importStates("./../States.json")->then(res => {
    res.states->resolve
  })
}

let sortCustomerMethodsBasedOnPriority = (
  sortArr: array<PaymentType.customerMethods>,
  priorityArr: array<string>,
  ~displayDefaultSavedPaymentIcon=true,
) => {
  if priorityArr->Array.length === 0 {
    sortArr
  } else {
    // * Need to discuss why this is used.
    // let priorityArr = priorityArr->Array.length > 0 ? priorityArr : PaymentModeType.defaultOrder
    let getPaymentMethod = (customerMethod: PaymentType.customerMethods) => {
      if customerMethod.paymentMethod === "card" {
        customerMethod.paymentMethod
      } else {
        switch customerMethod.paymentMethodType {
        | Some(paymentMethodType) => paymentMethodType
        | _ => customerMethod.paymentMethod
        }
      }
    }

    let getCustomerMethodPriority = (paymentMethod: string) => {
      let priorityArrLength = priorityArr->Array.length
      let index = priorityArr->Array.indexOf(paymentMethod)

      index === -1 ? priorityArrLength : index
    }

    let handleCustomerMethodsSort = (
      firstCustomerMethod: PaymentType.customerMethods,
      secondCustomerMethod: PaymentType.customerMethods,
    ) => {
      let firstPaymentMethod = firstCustomerMethod->getPaymentMethod
      let secondPaymentMethod = secondCustomerMethod->getPaymentMethod

      if (
        displayDefaultSavedPaymentIcon &&
        (firstCustomerMethod.defaultPaymentMethodSet ||
        secondCustomerMethod.defaultPaymentMethodSet)
      ) {
        firstCustomerMethod.defaultPaymentMethodSet ? -1 : 1
      } else {
        firstPaymentMethod->getCustomerMethodPriority -
          secondPaymentMethod->getCustomerMethodPriority
      }
    }

    sortArr->Belt.SortArray.stableSortBy(handleCustomerMethodsSort)
  }
}
