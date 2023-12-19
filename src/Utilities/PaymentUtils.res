let paymentListLookupNew = (list: PaymentMethodsRecord.list, ~order) => {
  let pmList = list->PaymentMethodsRecord.buildFromPaymentList
  let walletsList = []
  let walletToBeDisplayedInTabs = [
    "mb_way",
    "ali_pay",
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
  ]
  let otherPaymentList = []
  let googlePayFields = pmList->Js.Array2.find(item => item.paymentMethodName === "google_pay")
  switch googlePayFields {
  | Some(val) =>
    if val.fields->Js.Array2.length > 0 {
      walletToBeDisplayedInTabs->Js.Array2.push("google_pay")->ignore
    }
  | None => ()
  }

  pmList->Js.Array2.forEach(item => {
    if walletToBeDisplayedInTabs->Js.Array2.includes(item.paymentMethodName) {
      otherPaymentList->Js.Array2.push(item.paymentMethodName)->ignore
    } else if item.methodType == "wallet" {
      walletsList->Js.Array2.push(item.paymentMethodName)->ignore
    } else if item.methodType == "bank_debit" {
      otherPaymentList->Js.Array2.push(item.paymentMethodName ++ "_debit")->ignore
    } else if item.methodType == "bank_transfer" {
      otherPaymentList->Js.Array2.push(item.paymentMethodName ++ "_transfer")->ignore
    } else if item.methodType == "card" {
      otherPaymentList->Js.Array2.push("card")->ignore
    } else if item.methodType == "reward" {
      otherPaymentList->Js.Array2.push(item.paymentMethodName)->ignore
    } else {
      otherPaymentList->Js.Array2.push(item.paymentMethodName)->ignore
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

let getConnectors = (list: PaymentMethodsRecord.list, method: connectorType) => {
  let paymentMethod =
    list.payment_methods->Js.Array2.find(item => item.payment_method == method->getMethod)
  switch paymentMethod {
  | Some(val) =>
    let paymentMethodType =
      val.payment_method_types->Js.Array2.find(item =>
        item.payment_method_type == method->getMethodType
      )
    switch paymentMethodType {
    | Some(val) =>
      let experienceType = val.payment_experience->Js.Array2.find(item => {
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
let getPaymentDetails = (arr: array<string>) => {
  let finalArr = []
  arr
  ->Js.Array2.map(item => {
    let optionalVal = PaymentDetails.details->Js.Array2.find(i => i.type_ == item)
    switch optionalVal {
    | Some(val) => finalArr->Js.Array2.push(val)->ignore
    | None => ()
    }
  })
  ->ignore
  finalArr
}
let getDisplayNameAndIcon = (
  customNames: PaymentType.customMethodNames,
  paymentMethodName,
  defaultName,
  defaultIcon,
) => {
  let customNameObj =
    customNames
    ->Js.Array2.filter((item: PaymentType.alias) => {
      item.paymentMethodName === paymentMethodName
    })
    ->Belt.Array.get(0)
  switch customNameObj {
  | Some(val) =>
    val.paymentMethodName === "classic" || val.paymentMethodName === "evoucher"
      ? {
          switch val.aliasName {
          | "" => (defaultName, defaultIcon)
          | aliasName =>
            let id = aliasName->Js.String2.split(" ")
            (
              aliasName,
              Some(
                PaymentMethodsRecord.icon(
                  id->Belt.Array.get(0)->Belt.Option.getWithDefault(""),
                  ~size=19,
                ),
              ),
            )
          }
        }
      : (defaultName, defaultIcon)
  | None => (defaultName, defaultIcon)
  }
}

let updateDynamicFields = (arr: Js.Array2.t<PaymentMethodsRecord.paymentMethodsFields>, ()) => {
  open PaymentMethodsRecord
  let hasStateAndCity =
    arr->Js.Array2.includes(AddressState) && arr->Js.Array2.includes(AddressCity)
  let hasCountryAndPostal =
    arr
    ->Js.Array2.filter(item =>
      switch item {
      | AddressCountry(_) => true
      | AddressPincode => true
      | _ => false
      }
    )
    ->Js.Array2.length == 2

  let options = arr->Js.Array2.reduce((acc, item) => {
    acc->Js.Array2.concat(
      switch item {
      | AddressCountry(val) => val
      | _ => [""]
      },
    )
  }, [""])

  let newArr = {
    switch (hasStateAndCity, hasCountryAndPostal) {
    | (true, true) => {
        arr->Js.Array2.push(StateAndCity)->ignore
        arr->Js.Array2.push(CountryAndPincode(options))->ignore
        arr->Js.Array2.filter(item =>
          switch item {
          | AddressCity
          | AddressPincode
          | AddressState
          | AddressCountry(_) => false
          | _ => true
          }
        )
      }
    | (true, false) => {
        arr->Js.Array2.push(StateAndCity)->ignore
        arr->Js.Array2.filter(item =>
          switch item {
          | AddressCity
          | AddressState => false
          | _ => true
          }
        )
      }
    | (false, true) => {
        arr->Js.Array2.push(CountryAndPincode(options))->ignore
        arr->Js.Array2.filter(item =>
          switch item {
          | AddressPincode
          | AddressCountry(_) => false
          | _ => true
          }
        )
      }
    | (_, _) => arr
    }
  }
  newArr
}
