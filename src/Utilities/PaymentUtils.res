let paymentMethodListValue = Recoil.atom("paymentMethodListValue", PaymentMethodsRecord.defaultList)
let paymentManagementListValue = Recoil.atom(
  "paymentManagementListValue",
  UnifiedHelpersV2.defaultPaymentsList,
)

let paymentListLookupNew = (
  list: PaymentMethodsRecord.paymentMethodList,
  ~order,
  ~isShowPaypal,
  ~isShowKlarnaOneClick,
  ~isKlarnaSDKFlow,
  ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
  ~areAllGooglePayRequiredFieldsPrefilled,
  ~isGooglePayReady,
  ~shouldDisplayApplePayInTabs,
  ~shouldDisplayPayPalInTabs,
  ~localeString,
) => {
  let pmList = list->PaymentMethodsRecord.buildFromPaymentList(~localeString)
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
    "bluecode",
    "revolut_pay",
    "skrill",
  ]
  let otherPaymentList = []

  if shouldDisplayApplePayInTabs {
    walletToBeDisplayedInTabs->Array.push("apple_pay")
  }

  if shouldDisplayPayPalInTabs {
    walletToBeDisplayedInTabs->Array.push("paypal")
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
    } else if (
      item.methodType === "bank_transfer" &&
        !(Constants.bankTransferList->Array.includes(item.paymentMethodName))
    ) {
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

        // To be fixed for Klarna Checkout - PR - https://github.com/juspay/hyperswitch-web/pull/851
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
type banks = Sofort | Eps | GiroPay | Ideal | EFT
type transfer = ACH | Sepa | Bacs | Instant
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
    | EFT => "eft"
    }
  | BankDebit(val)
  | BankTransfer(val) =>
    switch val {
    | ACH => "ach"
    | Bacs => "bacs"
    | Sepa => "sepa"
    | Instant => "instant"
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
  } else if (
    paymentMethodType === "bank_transfer" &&
      !(Constants.bankTransferList->Array.includes(paymentMethodName))
  ) {
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

let usePaypalFlowStatus = (~sessions, ~paymentMethodListValue) => {
  open Utils

  let sessionObj =
    sessions
    ->getDictFromJson
    ->SessionsType.itemToObjMapper(Others)

  let {paypalToken, isPaypalSDKFlow, isPaypalRedirectFlow} = PayPalHelpers.usePaymentMethodData(
    ~paymentMethodListValue,
    ~sessionObj,
  )

  let isPaypalTokenExist = switch paypalToken {
  | OtherTokenOptional(optToken) =>
    switch optToken {
    | Some(_) => true
    | _ => false
    }
  | _ => false
  }

  (isPaypalSDKFlow, isPaypalRedirectFlow, isPaypalTokenExist)
}

let useGetPaymentMethodList = (~paymentOptions, ~paymentType, ~sessions) => {
  open Utils
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let {paymentMethodOrder} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
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

  let areAllPaypalRequiredFieldsPreFilled = useAreAllRequiredFieldsPrefilled(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="paypal",
  )

  let isApplePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isApplePayReady)
  let isGooglePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isGooglePayReady)

  let (isPaypalSDKFlow, isPaypalRedirectFlow, isPaypalTokenExist) = usePaypalFlowStatus(
    ~sessions,
    ~paymentMethodListValue,
  )

  React.useMemo(() => {
    switch methodslist {
    | Loaded(paymentlist) =>
      let paymentOrder =
        paymentOrder->Array.length > 0 ? paymentOrder : PaymentModeType.defaultOrder
      let pList = paymentlist->getDictFromJson->PaymentMethodsRecord.itemToObjMapper

      let shouldDisplayApplePayInTabs =
        !paymentMethodListValue.collect_billing_details_from_wallets &&
        !areAllApplePayRequiredFieldsPrefilled &&
        isApplePayReady

      let isShowPaypal = optionAtomValue.wallets.payPal === Auto

      let shouldDisplayPayPalInTabs =
        isShowPaypal &&
        !paymentMethodListValue.collect_billing_details_from_wallets &&
        !areAllPaypalRequiredFieldsPreFilled &&
        isPaypalRedirectFlow &&
        (!isPaypalSDKFlow || !isPaypalTokenExist)

      let (wallets, otherOptions) =
        pList->paymentListLookupNew(
          ~order=paymentOrder,
          ~isShowPaypal,
          ~isShowKlarnaOneClick=optionAtomValue.wallets.klarna === Auto,
          ~isKlarnaSDKFlow,
          ~paymentMethodListValue=pList,
          ~areAllGooglePayRequiredFieldsPrefilled,
          ~isGooglePayReady,
          ~shouldDisplayApplePayInTabs,
          ~shouldDisplayPayPalInTabs,
          ~localeString,
        )

      let klarnaPaymentMethodExperience = PaymentMethodsRecord.getPaymentExperienceTypeFromPML(
        ~paymentMethodList=pList,
        ~paymentMethodName="pay_later",
        ~paymentMethodType="klarna",
      )

      let isKlarnaInvokeSDKExperience = klarnaPaymentMethodExperience->Array.includes(InvokeSDK)

      let filterPaymentMethods = (paymentOptionsList: array<string>) => {
        paymentOptionsList->Array.filter(paymentOptionsName => {
          switch paymentOptionsName {
          | "klarna" => !(isKlarnaSDKFlow && isKlarnaInvokeSDKExperience)
          | "apple_pay" => shouldDisplayApplePayInTabs
          | _ => true
          }
        })
      }

      (
        wallets->removeDuplicate->Utils.getWalletPaymentMethod(paymentType),
        paymentOptions
        ->Array.concat(otherOptions)
        ->removeDuplicate
        ->filterPaymentMethods,
        otherOptions,
      )
    | SemiLoaded => checkPriorityList(paymentMethodOrder) ? ([], ["card"], []) : ([], [], [])
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
  let stateList = CountryStateDataRefs.stateDataRef.contents

  React.useEffect0(_ => {
    setStatesJson(_ => stateList)
    None
  })
}

let getStateJson = async _ => {
  try {
    let res = await S3Utils.getCountryStateData()
    res.states
  } catch {
  | err =>
    Console.error2("Error importing states:", err)
    JSON.Encode.null
  }
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

let getSupportedCardBrands = (paymentMethodListValue: PaymentMethodsRecord.paymentMethodList) => {
  let cardPaymentMethod =
    paymentMethodListValue.payment_methods->Array.find(ele => ele.payment_method === "card")

  switch cardPaymentMethod {
  | Some(cardPaymentMethod) =>
    let cardNetworks = cardPaymentMethod.payment_method_types->Array.map(ele => ele.card_networks)
    let cardNetworkNames =
      cardNetworks->Array.map(ele =>
        ele->Array.map(val => val.card_network->CardUtils.getCardStringFromType->String.toLowerCase)
      )
    Some(
      cardNetworkNames
      ->Array.reduce([], (acc, ele) => acc->Array.concat(ele))
      ->Utils.getUniqueArray,
    )
  | None => None
  }
}

let checkIsCardSupported = (cardNumber, cardBrand, supportedCardBrands) => {
  let clearValue = cardNumber->CardValidations.clearSpaces
  if cardBrand == "" {
    Some(CardUtils.cardValid(clearValue, cardBrand))
  } else if CardUtils.cardValid(clearValue, cardBrand) {
    switch supportedCardBrands {
    | Some(brands) => Some(brands->Array.includes(cardBrand->String.toLowerCase))
    | None => Some(true)
    }
  } else {
    None
  }
}

let emitMessage = paymentMethodInfo =>
  Utils.messageParentWindow([("paymentMethodInfo", paymentMethodInfo->JSON.Encode.object)])

let emitPaymentMethodInfo = (
  ~paymentMethod,
  ~paymentMethodType,
  ~cardBrand=CardUtils.NOTFOUND,
  ~cardLast4="",
  ~cardBin="",
  ~cardExpiryMonth="",
  ~cardExpiryYear="",
  ~country="",
  ~state="",
  ~pinCode="",
  ~isSavedPaymentMethod=false,
) => {
  let baseCardsFields = [
    ("cardBrand", cardBrand->CardUtils.getCardStringFromType->JSON.Encode.string),
    ("cardLast4", cardLast4->JSON.Encode.string),
    ("cardBin", cardBin->JSON.Encode.string),
    ("cardExpiryMonth", cardExpiryMonth->JSON.Encode.string),
    ("cardExpiryYear", cardExpiryYear->JSON.Encode.string),
  ]

  let baseAddressFields = [
    ("country", country->JSON.Encode.string),
    ("state", state->JSON.Encode.string),
    ("pincode", pinCode->JSON.Encode.string),
  ]

  let baseSavedPaymentField = [("isSavedPaymentMethod", isSavedPaymentMethod->JSON.Encode.bool)]

  let basePaymentInfoFields = switch paymentMethod {
  | "card" => [("paymentMethod", paymentMethod->JSON.Encode.string)]
  | _ => [
      ("paymentMethod", paymentMethod->JSON.Encode.string),
      ("paymentMethodType", paymentMethodType->JSON.Encode.string),
    ]
  }

  let msg = if cardBrand === CardUtils.NOTFOUND || paymentMethod !== "card" {
    [...basePaymentInfoFields, ...baseAddressFields]
  } else {
    [...basePaymentInfoFields, ...baseAddressFields, ...baseCardsFields]
  }

  let finalMsg =
    msg->Array.filter(((_, value)) => value->JSON.Decode.string->Option.getOr("") != "")

  emitMessage(finalMsg->Array.concat(baseSavedPaymentField)->Dict.fromArray)
}

type nonPiiAdderessData = {
  country: string,
  state: string,
  pinCode: string,
}

let useNonPiiAddressData = () => {
  let country = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCountry)
  let state = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressState).value
  let pinCode = Recoil.useRecoilValueFromAtom(RecoilAtoms.userAddressPincode).value

  {
    country,
    state,
    pinCode,
  }
}

let useEmitPaymentMethodInfo = (
  ~paymentMethodName,
  ~paymentMethods: array<PaymentMethodsRecord.methods>,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let {country, state, pinCode} = useNonPiiAddressData()

  let {cardNumber, cardBrand} = cardProps
  let cardBin = cardNumber->CardUtils.getCardBin
  let cardLast4 = cardNumber->CardUtils.getCardLast4
  let {cardExpiry} = expiryProps
  let isCardValid = cardProps.isCardValid->Option.getOr(false)
  let isExpiryValid = expiryProps.isExpiryValid->Option.getOr(false)
  let (cardExpiryMonth, cardExpiryYear) = cardExpiry->CardUtils.getExpiryDates
  let shouldEmitCardInfo = isCardValid && isExpiryValid && paymentMethodName == "card"

  let emitPaymentMethodInfoWrapper = (~paymentMethod, ~paymentMethodType) => {
    if shouldEmitCardInfo {
      emitPaymentMethodInfo(
        ~paymentMethod=paymentMethodName,
        ~paymentMethodType,
        ~cardBrand=cardBrand->CardUtils.getCardType,
        ~cardLast4,
        ~cardBin,
        ~cardExpiryMonth,
        ~cardExpiryYear,
        ~country,
        ~state,
        ~pinCode,
      )
    } else {
      emitPaymentMethodInfo(~paymentMethod, ~paymentMethodType, ~country, ~state, ~pinCode)
    }
  }

  React.useEffect(() => {
    if paymentMethodName->String.includes("_debit") {
      emitPaymentMethodInfoWrapper(
        ~paymentMethod="bank_debit",
        ~paymentMethodType=paymentMethodName,
      )
    } else if paymentMethodName->String.includes("_transfer") {
      emitPaymentMethodInfoWrapper(
        ~paymentMethod="bank_transfer",
        ~paymentMethodType=paymentMethodName,
      )
    } else if paymentMethodName === "card" {
      emitPaymentMethodInfoWrapper(~paymentMethod="card", ~paymentMethodType="debit")
    } else {
      let finalOptionalPaymentMethodTypeValue =
        paymentMethods
        ->Array.filter(paymentMethodData =>
          paymentMethodData.payment_method_types
          ->Array.filter(
            paymentMethodType => paymentMethodType.payment_method_type === paymentMethodName,
          )
          ->Array.length > 0
        )
        ->Array.get(0)

      switch finalOptionalPaymentMethodTypeValue {
      | Some(finalPaymentMethodType) =>
        emitPaymentMethodInfoWrapper(
          ~paymentMethod=finalPaymentMethodType.payment_method,
          ~paymentMethodType=paymentMethodName,
        )
      | None =>
        loggerState.setLogError(
          ~value="Payment method type not found",
          ~eventName=PAYMENT_METHOD_TYPE_DETECTION_FAILED,
        )
      }
    }

    None
  }, (
    paymentMethodName,
    cardBrand,
    paymentMethods,
    isCardValid,
    isExpiryValid,
    country,
    state,
    pinCode,
  ))
}

let checkRenderOrComp = (~walletOptions, isShowOrPayUsing) => {
  walletOptions->Array.includes("paypal") || isShowOrPayUsing
}

let getGiftCardDataFromRequiredFieldsBody = requiredFieldsBody => {
  open Utils
  let giftCardTuples = []->mergeAndFlattenToTuples(requiredFieldsBody)
  let data =
    giftCardTuples
    ->getJsonFromArrayOfJson
    ->getDictFromJson
    ->getDictFromDict("payment_method_data")
  data
}

let selectAtom = (useSplit, splitAtom, normalAtom) => useSplit ? splitAtom : normalAtom
