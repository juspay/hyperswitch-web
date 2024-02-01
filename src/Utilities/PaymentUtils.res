let paymentListLookupNew = (
  list: PaymentMethodsRecord.list,
  ~order,
  ~showApplePay,
  ~showGooglePay,
) => {
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
  let applePayFields = pmList->Js.Array2.find(item => item.paymentMethodName === "apple_pay")
  switch googlePayFields {
  | Some(val) =>
    if val.fields->Js.Array2.length > 0 && showGooglePay {
      walletToBeDisplayedInTabs->Js.Array2.push("google_pay")->ignore
    }
  | None => ()
  }
  switch applePayFields {
  | Some(val) =>
    if val.fields->Js.Array2.length > 0 && showApplePay {
      walletToBeDisplayedInTabs->Js.Array2.push("apple_pay")->ignore
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

let getPaymentMethodName = (~paymentMethodType, ~paymentMethodName) => {
  if paymentMethodType == "bank_debit" {
    paymentMethodName->Js.String2.replace("_debit", "")
  } else if paymentMethodType == "bank_transfer" {
    paymentMethodName->Js.String2.replace("_transfer", "")
  } else {
    paymentMethodName
  }
}
