type showTerms = Auto | Always | Never
type showType = Auto | Never
type layout = Accordion | Tabs
open Utils
open ErrorUtils

type showAddress = {
  line1: showType,
  line2: showType,
  city: showType,
  state: showType,
  country: showType,
  postal_code: showType,
}
type alias = {
  paymentMethodName: string,
  aliasName: string,
}
type customMethodNames = array<alias>
type address = {
  line1: string,
  line2: string,
  city: string,
  state: string,
  country: string,
  postal_code: string,
}
type addressType =
  | JSONString(string)
  | JSONObject(showAddress)

type details = {
  name: showType,
  email: showType,
  phone: showType,
  address: addressType,
}
type billingDetails = {
  name: string,
  email: string,
  phone: string,
  address: address,
}

type billing =
  | JSONString(string)
  | JSONObject(details)

type defaultValues = {billingDetails: billingDetails}

type fields = {billingDetails: billing}

type terms = {
  auBecsDebit: showTerms,
  bancontact: showTerms,
  card: showTerms,
  ideal: showTerms,
  sepaDebit: showTerms,
  sofort: showTerms,
  usBankAccount: showTerms,
}
type buttonHeight = Default | Custom
type heightType = ApplePay(int) | GooglePay(int) | Paypal(int) | Klarna(int)
type googlePayStyleType = Default | Buy | Donate | Checkout | Subscribe | Book | Pay | Order
type paypalStyleType = Paypal | Checkout | Buynow | Pay | Installment
type applePayStyleType =
  | Default
  | Buy
  | Donate
  | Checkout
  | Subscribe
  | Reload
  | Addmoney
  | Topup
  | Rent
  | Order
  | Support
  | Tip
  | Contribute
type styleType =
  | ApplePay(applePayStyleType)
  | GooglePay(googlePayStyleType)
  | Paypal(paypalStyleType)
type styleTypeArray = (styleType, styleType, styleType)
type theme = Dark | Light | Outline
type style = {
  type_: styleTypeArray,
  theme: theme,
  height: (heightType, heightType, heightType, heightType),
  buttonRadius: int,
}
type wallets = {
  walletReturnUrl: string,
  applePay: showType,
  googlePay: showType,
  payPal: showType,
  klarna: showType,
  style: style,
}
type business = {name: string}
type layoutConfig = {
  defaultCollapsed: bool,
  radios: bool,
  spacedAccordionItems: bool,
  maxAccordionItems: int,
  \"type": layout,
}

type layoutType =
  | StringLayout(layout)
  | ObjectLayout(layoutConfig)

type customerCard = {
  scheme: option<string>,
  last4Digits: string,
  expiryMonth: string,
  expiryYear: string,
  cardToken: string,
  cardHolderName: option<string>,
  nickname: string,
}
type customerMethods = {
  paymentToken: string,
  customerId: string,
  paymentMethod: string,
  paymentMethodIssuer: option<string>,
  card: customerCard,
  paymentMethodType: option<string>,
  defaultPaymentMethodSet: bool,
  requiresCvv: bool,
}
type savedCardsLoadState =
  LoadingSavedCards | LoadedSavedCards(array<customerMethods>, bool) | NoResult(bool)

type billingAddress = {
  isUseBillingAddress: bool,
  usePrefilledValues: showType,
}

type sdkHandleConfirmPayment = {
  handleConfirm: bool,
  buttonText?: string,
  confirmParams: ConfirmType.confirmParams,
}

type options = {
  defaultValues: defaultValues,
  layout: layoutType,
  business: business,
  customerPaymentMethods: savedCardsLoadState,
  paymentMethodOrder: option<array<string>>,
  displaySavedPaymentMethodsCheckbox: bool,
  displaySavedPaymentMethods: bool,
  fields: fields,
  readOnly: bool,
  terms: terms,
  wallets: wallets,
  customMethodNames: customMethodNames,
  branding: showType,
  payButtonStyle: style,
  showCardFormByDefault: bool,
  billingAddress: billingAddress,
  sdkHandleConfirmPayment: sdkHandleConfirmPayment,
  paymentMethodsHeaderText?: string,
  savedPaymentMethodsHeaderText?: string,
  hideExpiredPaymentMethods: bool,
}
let defaultCardDetails = {
  scheme: None,
  last4Digits: "",
  expiryMonth: "",
  expiryYear: "",
  cardToken: "",
  cardHolderName: None,
  nickname: "",
}
let defaultCustomerMethods = {
  paymentToken: "",
  customerId: "",
  paymentMethod: "",
  paymentMethodIssuer: None,
  card: defaultCardDetails,
  paymentMethodType: None,
  defaultPaymentMethodSet: false,
  requiresCvv: true,
}
let defaultLayout = {
  defaultCollapsed: false,
  radios: false,
  spacedAccordionItems: false,
  maxAccordionItems: 4,
  \"type": Tabs,
}
let defaultAddress: address = {
  line1: "",
  line2: "",
  city: "",
  state: "",
  country: "",
  postal_code: "",
}
let defaultBillingDetails: billingDetails = {
  name: "",
  email: "",
  phone: "",
  address: defaultAddress,
}
let defaultBusiness = {
  name: "",
}
let defaultDefaultValues: defaultValues = {
  billingDetails: defaultBillingDetails,
}
let defaultshowAddress: showAddress = {
  line1: Auto,
  line2: Auto,
  city: Auto,
  state: Auto,
  country: Auto,
  postal_code: Auto,
}
let defaultNeverShowAddress: showAddress = {
  line1: Never,
  line2: Never,
  city: Never,
  state: Never,
  country: Never,
  postal_code: Never,
}

let defaultBilling: details = {
  name: Auto,
  email: Auto,
  phone: Auto,
  address: JSONObject(defaultshowAddress),
}
let defaultNeverBilling: details = {
  name: Never,
  email: Never,
  phone: Never,
  address: JSONObject(defaultNeverShowAddress),
}
let defaultTerms = {
  auBecsDebit: Auto,
  bancontact: Auto,
  card: Auto,
  ideal: Auto,
  sepaDebit: Auto,
  sofort: Auto,
  usBankAccount: Auto,
}
let defaultFields = {
  billingDetails: JSONObject(defaultBilling),
}
let defaultStyle = {
  type_: (ApplePay(Default), GooglePay(Default), Paypal(Paypal)),
  theme: Light,
  height: (ApplePay(48), GooglePay(48), Paypal(48), Klarna(48)),
  buttonRadius: 2,
}
let defaultWallets = {
  walletReturnUrl: "",
  applePay: Auto,
  googlePay: Auto,
  payPal: Auto,
  klarna: Auto,
  style: defaultStyle,
}
let defaultBillingAddress = {
  isUseBillingAddress: false,
  usePrefilledValues: Auto,
}

let defaultSdkHandleConfirmPayment = {
  handleConfirm: false,
  confirmParams: ConfirmType.defaultConfirm,
}

let defaultOptions = {
  defaultValues: defaultDefaultValues,
  business: defaultBusiness,
  customerPaymentMethods: LoadingSavedCards,
  layout: ObjectLayout(defaultLayout),
  paymentMethodOrder: None,
  fields: defaultFields,
  displaySavedPaymentMethodsCheckbox: true,
  displaySavedPaymentMethods: true,
  readOnly: false,
  terms: defaultTerms,
  branding: Auto,
  wallets: defaultWallets,
  payButtonStyle: defaultStyle,
  customMethodNames: [],
  showCardFormByDefault: true,
  billingAddress: defaultBillingAddress,
  sdkHandleConfirmPayment: defaultSdkHandleConfirmPayment,
  hideExpiredPaymentMethods: false,
}
let getLayout = (str, logger) => {
  switch str {
  | "tabs" => Tabs
  | "accordion" => Accordion
  | str => {
      str->unknownPropValueWarning(["tabs", "accordion"], "options.layout", ~logger)
      Tabs
    }
  }
}
let getAddress = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    let countryNames = []
    Country.country->Array.map(item => countryNames->Array.push(item.countryName))->ignore
    unknownKeysWarning(
      ["line1", "line2", "city", "state", "country", "postal_code"],
      json,
      "options.defaultValues.billingDetails.address",
      ~logger,
    )
    let country = getWarningString(json, "country", "", ~logger)
    if country != "" {
      unknownPropValueWarning(
        country,
        countryNames,
        "options.defaultValues.billingDetails.address.country",
        ~logger,
      )
    }
    {
      line1: getWarningString(json, "line1", "", ~logger),
      line2: getWarningString(json, "line2", "", ~logger),
      city: getWarningString(json, "city", "", ~logger),
      state: getWarningString(json, "state", "", ~logger),
      country,
      postal_code: getWarningString(json, "postal_code", "", ~logger),
    }
  })
  ->Option.getOr(defaultAddress)
}
let getBillingDetails = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(
      ["name", "email", "phone", "address"],
      json,
      "options.defaultValues.billingDetails",
      ~logger,
    )
    {
      name: getWarningString(json, "name", "", ~logger),
      email: getWarningString(json, "email", "", ~logger),
      phone: getWarningString(json, "phone", "", ~logger),
      address: getAddress(json, "address", logger),
    }
  })
  ->Option.getOr(defaultBillingDetails)
}

let getDefaultValues = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(["billingDetails"], json, "options.defaultValues", ~logger)
    let defaultValues: defaultValues = {
      billingDetails: getBillingDetails(json, "billingDetails", logger),
    }
    defaultValues
  })
  ->Option.getOr(defaultDefaultValues)
}
let getBusiness = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(["name"], json, "options.business", ~logger)
    {
      name: getWarningString(json, "name", "", ~logger),
    }
  })
  ->Option.getOr(defaultBusiness)
}
let getShowType = (str, key, logger) => {
  switch str {
  | "auto" => Auto
  | "never" => Never
  | str => {
      str->unknownPropValueWarning(["auto", "never"], key, ~logger)
      Auto
    }
  }
}
let getApplePayType = str => {
  switch str {
  | "buy"
  | "buynow" =>
    ApplePay(Buy)
  | "donate" => ApplePay(Donate)
  | "check-out"
  | "checkout" =>
    ApplePay(Checkout)
  | "subscribe" => ApplePay(Subscribe)
  | "reload" => ApplePay(Reload)
  | "add-money"
  | "addmoney" =>
    ApplePay(Addmoney)
  | "top-up"
  | "topup" =>
    ApplePay(Topup)
  | "rent" => ApplePay(Rent)
  | "order" => ApplePay(Order)
  | "support" => ApplePay(Support)
  | "tip" => ApplePay(Tip)
  | "contribute" => ApplePay(Contribute)
  | "default"
  | _ =>
    ApplePay(Default)
  }
}
let getGooglePayType = str => {
  switch str {
  | "buy"
  | "buynow" =>
    GooglePay(Buy)
  | "book" => GooglePay(Book)
  | "pay" => GooglePay(Pay)
  | "donate" => GooglePay(Donate)
  | "check-out"
  | "checkout" =>
    GooglePay(Checkout)
  | "order" => GooglePay(Order)
  | "subscribe" => GooglePay(Subscribe)
  | "default"
  | "plain"
  | _ =>
    GooglePay(Default)
  }
}
let getPayPalType = str => {
  switch str {
  | "check-out"
  | "checkout" =>
    Paypal(Checkout)
  | "installment" => Paypal(Installment)
  | "buy"
  | "buynow" =>
    Paypal(Buynow)
  | "pay" => Paypal(Pay)
  | "paypal"
  | _ =>
    Paypal(Paypal)
  }
}
let getTypeArray = (str, logger) => {
  let goodVals = [
    "checkout",
    "pay",
    "buy",
    "installment",
    "pay",
    "default",
    "book",
    "donate",
    "order",
    "addmoney",
    "topup",
    "rent",
    "subscribe",
    "reload",
    "support",
    "tip",
    "contribute",
  ]
  if !Array.includes(goodVals, str) {
    str->unknownPropValueWarning(goodVals, "options.wallets.style.type", ~logger)
  }
  (str->getApplePayType, str->getGooglePayType, str->getPayPalType)
}

let getShowDetails = (~billingDetails, ~logger) => {
  switch billingDetails {
  | JSONObject(obj) => obj
  | JSONString(str) =>
    str->getShowType("fields.billingDetails", logger) == Never
      ? defaultNeverBilling
      : defaultBilling
  }
}
let getShowAddressDetails = (~billingDetails, ~logger) => {
  switch billingDetails {
  | JSONObject(obj) =>
    switch obj.address {
    | JSONString(str) =>
      str->getShowType("fields.billingDetails.address", logger) == Never
        ? defaultNeverShowAddress
        : defaultshowAddress
    | JSONObject(obj) => obj
    }
  | JSONString(str) =>
    str->getShowType("fields.billingDetails", logger) == Never
      ? defaultNeverShowAddress
      : defaultshowAddress
  }
}

let getShowTerms: (string, string, 'a) => showTerms = (str, key, logger) => {
  switch str {
  | "auto" => Auto
  | "always" => Always
  | "never" => Never
  | str => {
      str->unknownPropValueWarning(["auto", "always", "never"], key, ~logger)
      Auto
    }
  }
}

let getShowAddress = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    let x: showAddress = {
      line1: getWarningString(json, "line1", "auto", ~logger)->getShowType(
        "options.fields.address.line1",
        logger,
      ),
      line2: getWarningString(json, "line2", "auto", ~logger)->getShowType(
        "options.fields.address.line2",
        logger,
      ),
      city: getWarningString(json, "city", "auto", ~logger)->getShowType(
        "options.fields.address.city",
        logger,
      ),
      state: getWarningString(json, "state", "auto", ~logger)->getShowType(
        "options.fields.address.state",
        logger,
      ),
      country: getWarningString(json, "country", "auto", ~logger)->getShowType(
        "options.fields.address.country",
        logger,
      ),
      postal_code: getWarningString(json, "postal_code", "auto", ~logger)->getShowType(
        "options.fields.name.postal_code",
        logger,
      ),
    }
    x
  })
  ->Option.getOr(defaultshowAddress)
}
let getDeatils = (val, logger) => {
  switch val->JSON.Classify.classify {
  | String(str) => JSONString(str)
  | Object(json) =>
    JSONObject({
      name: getWarningString(json, "name", "auto", ~logger)->getShowType(
        "options.fields.name",
        logger,
      ),
      email: getWarningString(json, "email", "auto", ~logger)->getShowType(
        "options.fields.email",
        logger,
      ),
      phone: getWarningString(json, "phone", "auto", ~logger)->getShowType(
        "options.fields.phone",
        logger,
      ),
      address: JSONObject(getShowAddress(json, "address", logger)),
    })
  | _ => JSONString("")
  }
}
let getBilling = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.map(json => json->getDeatils(logger))
  ->Option.getOr(defaultFields.billingDetails)
}
let getFields: (Dict.t<JSON.t>, string, 'a) => fields = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    let defaultFields: fields = {
      billingDetails: getBilling(json, "billingDetails", logger),
    }
    defaultFields
  })
  ->Option.getOr(defaultFields)
}
let getLayoutValues = (val, logger) => {
  switch val->JSON.Classify.classify {
  | String(str) => StringLayout(str->getLayout(logger))
  | Object(json) =>
    ObjectLayout({
      let layoutType = getWarningString(json, "type", "tabs", ~logger)
      unknownKeysWarning(
        ["defaultCollapsed", "radios", "spacedAccordionItems", "type", "maxAccordionItems"],
        json,
        "options.layout",
        ~logger,
      )
      {
        defaultCollapsed: getBoolWithWarning(json, "defaultCollapsed", false, ~logger),
        radios: getBoolWithWarning(json, "radios", false, ~logger),
        spacedAccordionItems: getBoolWithWarning(json, "spacedAccordionItems", false, ~logger),
        maxAccordionItems: getNumberWithWarning(json, "maxAccordionItems", 4, ~logger),
        \"type": layoutType->getLayout(logger),
      }
    })
  | _ => StringLayout(Tabs)
  }
}
let getTerms = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(
      ["auBecsDebit", "bancontact", "card", "ideal", "sepaDebit", "sofort", "usBankAccount"],
      json,
      "options.terms",
      ~logger,
    )
    {
      auBecsDebit: getWarningString(json, "auBecsDebit", "auto", ~logger)->getShowTerms(
        "options.terms.auBecsDebit",
        logger,
      ),
      bancontact: getWarningString(json, "bancontact", "auto", ~logger)->getShowTerms(
        "options.terms.bancontact",
        logger,
      ),
      card: getWarningString(json, "card", "auto", ~logger)->getShowTerms(
        "options.terms.card",
        logger,
      ),
      ideal: getWarningString(json, "ideal", "auto", ~logger)->getShowTerms(
        "options.terms.ideal",
        logger,
      ),
      sepaDebit: getWarningString(json, "sepaDebit", "auto", ~logger)->getShowTerms(
        "options.terms.sepaDebit",
        logger,
      ),
      sofort: getWarningString(json, "sofort", "auto", ~logger)->getShowTerms(
        "options.terms.sofort",
        logger,
      ),
      usBankAccount: getWarningString(json, "usBankAccount", "auto", ~logger)->getShowTerms(
        "options.terms.usBankAccount",
        logger,
      ),
    }
  })
  ->Option.getOr(defaultTerms)
}
let getApplePayHeight = (val, logger) => {
  let val: heightType =
    val >= 45
      ? ApplePay(val)
      : {
          valueOutRangeWarning(
            val,
            "options.style.height",
            "[h>=45] - ApplePay. Value set to min",
            ~logger,
          )
          ApplePay(48)
        }
  val
}
let getGooglePayHeight = (val, logger) => {
  let val: heightType =
    val >= 48
      ? GooglePay(val)
      : {
          valueOutRangeWarning(
            val,
            "options.style.height",
            "[h>=48] - GooglePay. Value set to min",
            ~logger,
          )
          GooglePay(48)
        }
  val
}
let getPaypalHeight = (val, logger) => {
  let val: heightType =
    val < 25
      ? {
          valueOutRangeWarning(
            val,
            "options.style.height",
            "[25-55] - Paypal. Value set to min",
            ~logger,
          )
          Paypal(25)
        }
      : val > 55
      ? {
        valueOutRangeWarning(
          val,
          "options.style.height",
          "[25-55] - Paypal. Value set to max",
          ~logger,
        )
        Paypal(55)
      }
      : Paypal(val)
  val
}
let getKlarnaHeight = (val, logger) => {
  let val: heightType =
    val < 40
      ? {
          valueOutRangeWarning(
            val,
            "options.style.height",
            "[40-60] - Klarna. Value set to min",
            ~logger,
          )
          Klarna(40)
        }
      : val > 60
      ? {
        valueOutRangeWarning(
          val,
          "options.style.height",
          "[40-60] - Paypal. Value set to max",
          ~logger,
        )
        Klarna(60)
      }
      : Klarna(val)
  val
}
let getTheme = (str, logger) => {
  switch str {
  | "outline" => Outline
  | "light" => Light
  | "dark" => Dark
  | _ =>
    str->unknownPropValueWarning(["outline", "light", "dark"], "options.styles.theme", ~logger)
    Dark
  }
}
let getHeightArray = (val, logger) => {
  (
    val->getApplePayHeight(logger),
    val->getGooglePayHeight(logger),
    val->getPaypalHeight(logger),
    val->getKlarnaHeight(logger),
  )
}
let getStyle = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(["type", "theme", "height"], json, "options.wallets.style", ~logger)
    let style = {
      type_: getWarningString(json, "type", "", ~logger)->getTypeArray(logger),
      theme: getWarningString(json, "theme", "", ~logger)->getTheme(logger),
      height: getNumberWithWarning(json, "height", 48, ~logger)->getHeightArray(logger),
      buttonRadius: getNumberWithWarning(json, "buttonRadius", 2, ~logger),
    }
    style
  })
  ->Option.getOr(defaultStyle)
}
let getWallets = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(
      ["applePay", "googlePay", "style", "walletReturnUrl", "payPal", "klarna"],
      json,
      "options.wallets",
      ~logger,
    )

    {
      walletReturnUrl: getRequiredString(json, "walletReturnUrl", "", ~logger),
      applePay: getWarningString(json, "applePay", "auto", ~logger)->getShowType(
        "options.wallets.applePay",
        logger,
      ),
      googlePay: getWarningString(json, "googlePay", "auto", ~logger)->getShowType(
        "options.wallets.googlePay",
        logger,
      ),
      payPal: getWarningString(json, "payPal", "auto", ~logger)->getShowType(
        "options.wallets.payPal",
        logger,
      ),
      klarna: getWarningString(json, "klarna", "auto", ~logger)->getShowType(
        "options.wallets.klarna",
        logger,
      ),
      style: getStyle(json, "style", logger),
    }
  })
  ->Option.getOr(defaultWallets)
}

let getLayout = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.map(json => {
    json->getLayoutValues(logger)
  })
  ->Option.getOr(ObjectLayout(defaultLayout))
}

let getCardDetails = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      scheme: Some(getString(json, "scheme", "")),
      last4Digits: getString(json, "last4_digits", ""),
      expiryMonth: getString(json, "expiry_month", ""),
      expiryYear: getString(json, "expiry_year", ""),
      cardToken: getString(json, "card_token", ""),
      cardHolderName: Some(getString(json, "card_holder_name", "")),
      nickname: getString(json, "nick_name", ""),
    }
  })
  ->Option.getOr(defaultCardDetails)
}

let getPaymentMethodType = dict => {
  dict->Dict.get("payment_method_type")->Option.flatMap(JSON.Decode.string)
}

let createCustomerObjArr = dict => {
  let customerDict =
    dict
    ->Dict.get("customerPaymentMethods")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.getOr(Dict.make())

  let customerArr =
    customerDict
    ->Dict.get("customer_payment_methods")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.getOr([])

  let isGuestCustomer =
    customerDict
    ->Dict.get("is_guest_customer")
    ->Option.flatMap(JSON.Decode.bool)
    ->Option.getOr(false)

  let customerPaymentMethods =
    customerArr
    ->Belt.Array.keepMap(JSON.Decode.object)
    ->Array.map(dict => {
      {
        paymentToken: getString(dict, "payment_token", ""),
        customerId: getString(dict, "customer_id", ""),
        paymentMethod: getString(dict, "payment_method", ""),
        paymentMethodIssuer: Some(getString(dict, "payment_method_issuer", "")),
        card: getCardDetails(dict, "card"),
        paymentMethodType: getPaymentMethodType(dict),
        defaultPaymentMethodSet: getBool(dict, "default_payment_method_set", false),
        requiresCvv: getBool(dict, "requires_cvv", true),
      }
    })
  LoadedSavedCards(customerPaymentMethods, isGuestCustomer)
}

let getCustomerMethods = (dict, str) => {
  let customerArr = dict->Dict.get(str)->Option.flatMap(JSON.Decode.array)->Option.getOr([])

  if customerArr->Array.length !== 0 {
    let customerPaymentMethods =
      customerArr
      ->Belt.Array.keepMap(JSON.Decode.object)
      ->Array.map(json => {
        {
          paymentToken: getString(json, "payment_token", ""),
          customerId: getString(json, "customer_id", ""),
          paymentMethod: getString(json, "payment_method", ""),
          paymentMethodIssuer: Some(getString(json, "payment_method_issuer", "")),
          card: getCardDetails(json, "card"),
          paymentMethodType: getPaymentMethodType(dict),
          defaultPaymentMethodSet: getBool(dict, "default_payment_method_set", false),
          requiresCvv: getBool(dict, "requires_cvv", true),
        }
      })
    LoadedSavedCards(customerPaymentMethods, false)
  } else {
    LoadingSavedCards
  }
}

let getCustomMethodNames = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.map(json => {
    paymentMethodName: getString(json, "paymentMethodName", ""),
    aliasName: getString(json, "aliasName", ""),
  })
}

let getBillingAddress = (dict, str, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(
      ["isUseBillingAddress", "usePrefilledValues"],
      json,
      "options.billingAddress",
      ~logger,
    )

    {
      isUseBillingAddress: getBoolWithWarning(json, "isUseBillingAddress", false, ~logger),
      usePrefilledValues: getWarningString(
        json,
        "usePrefilledValues",
        "auto",
        ~logger,
      )->getShowType("options.billingAddress.usePrefilledValues", logger),
    }
  })
  ->Option.getOr(defaultBillingAddress)
}

let getConfirmParams = dict => {
  open ConfirmType
  {
    return_url: dict->getString("return_url", ""),
    publishableKey: dict->getString("publishableKey", ""),
    redirect: dict->getString("redirect", "if_required"),
  }
}

let getSdkHandleConfirmPaymentProps = dict => {
  handleConfirm: dict->getBool("handleConfirm", false),
  buttonText: ?dict->getOptionString("buttonText"),
  confirmParams: dict->getDictFromDict("confirmParams")->getConfirmParams,
}

let itemToObjMapper = (dict, logger) => {
  unknownKeysWarning(
    [
      "defaultValues",
      "business",
      "layout",
      "paymentMethodOrder",
      "customerPaymentMethods",
      "fields",
      "readOnly",
      "terms",
      "wallets",
      "showCardFormByDefault",
      "displaySavedPaymentMethodsCheckbox",
      "displaySavedPaymentMethods",
      "sdkHandleOneClickConfirmPayment",
      "showCardFormByDefault",
      "sdkHandleConfirmPayment",
      "paymentMethodsHeaderText",
      "savedPaymentMethodsHeaderText",
      "hideExpiredPaymentMethods",
    ],
    dict,
    "options",
    ~logger,
  )
  {
    defaultValues: getDefaultValues(dict, "defaultValues", logger),
    business: getBusiness(dict, "business", logger),
    layout: getLayout(dict, "layout", logger),
    customerPaymentMethods: getCustomerMethods(dict, "customerPaymentMethods"),
    paymentMethodOrder: getOptionalStrArray(dict, "paymentMethodOrder"),
    fields: getFields(dict, "fields", logger),
    branding: getWarningString(dict, "branding", "auto", ~logger)->getShowType(
      "options.branding",
      logger,
    ),
    displaySavedPaymentMethodsCheckbox: getBoolWithWarning(
      dict,
      "displaySavedPaymentMethodsCheckbox",
      true,
      ~logger,
    ),
    displaySavedPaymentMethods: getBoolWithWarning(
      dict,
      "displaySavedPaymentMethods",
      true,
      ~logger,
    ),
    readOnly: getBoolWithWarning(dict, "readOnly", false, ~logger),
    terms: getTerms(dict, "terms", logger),
    wallets: getWallets(dict, "wallets", logger),
    customMethodNames: getCustomMethodNames(dict, "customMethodNames"),
    payButtonStyle: getStyle(dict, "payButtonStyle", logger),
    showCardFormByDefault: getBool(dict, "showCardFormByDefault", true),
    billingAddress: getBillingAddress(dict, "billingAddress", logger),
    sdkHandleConfirmPayment: dict
    ->getDictFromDict("sdkHandleConfirmPayment")
    ->getSdkHandleConfirmPaymentProps,
    paymentMethodsHeaderText: ?getOptionString(dict, "paymentMethodsHeaderText"),
    savedPaymentMethodsHeaderText: ?getOptionString(dict, "savedPaymentMethodsHeaderText"),
    hideExpiredPaymentMethods: getBool(dict, "hideExpiredPaymentMethods", false),
  }
}

type loadType = Loading | Loaded(JSON.t) | SemiLoaded | LoadError(JSON.t)

let getIsStoredPaymentMethodHasName = (savedMethod: customerMethods) => {
  savedMethod.card.cardHolderName->Option.getOr("")->String.length > 0
}
