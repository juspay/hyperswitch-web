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
type heightType = ApplePay(int) | GooglePay(int) | Paypal(int)
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
  height: (heightType, heightType, heightType),
}
type wallets = {
  walletReturnUrl: string,
  applePay: showType,
  googlePay: showType,
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
}
type customerMethods = {
  paymentToken: string,
  customerId: string,
  paymentMethod: string,
  paymentMethodIssuer: option<string>,
  card: customerCard,
}
type savedCardsLoadState = LoadingSavedCards | LoadedSavedCards(array<customerMethods>) | NoResult
type options = {
  defaultValues: defaultValues,
  layout: layoutType,
  business: business,
  customerPaymentMethods: savedCardsLoadState,
  paymentMethodOrder: option<array<string>>,
  disableSaveCards: bool,
  fields: fields,
  readOnly: bool,
  terms: terms,
  wallets: wallets,
  customMethodNames: customMethodNames,
  branding: showType,
  payButtonStyle: style,
  showCardFormByDefault: bool,
}
let defaultCardDetails = {
  scheme: None,
  last4Digits: "",
  expiryMonth: "",
  expiryYear: "",
  cardToken: "",
  cardHolderName: None,
}
let defaultCustomerMethods = {
  paymentToken: "",
  customerId: "",
  paymentMethod: "",
  paymentMethodIssuer: None,
  card: defaultCardDetails,
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
  height: (ApplePay(48), GooglePay(48), Paypal(48)),
}
let defaultWallets = {
  walletReturnUrl: "",
  applePay: Auto,
  googlePay: Auto,
  style: defaultStyle,
}
let defaultOptions = {
  defaultValues: defaultDefaultValues,
  business: defaultBusiness,
  customerPaymentMethods: NoResult,
  layout: ObjectLayout(defaultLayout),
  paymentMethodOrder: None,
  fields: defaultFields,
  disableSaveCards: false,
  readOnly: false,
  terms: defaultTerms,
  branding: Auto,
  wallets: defaultWallets,
  payButtonStyle: defaultStyle,
  customMethodNames: [],
  showCardFormByDefault: true,
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
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    let countryNames = []
    Country.country->Js.Array2.map(item => countryNames->Js.Array2.push(item.countryName))->ignore
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
      country: country,
      postal_code: getWarningString(json, "postal_code", "", ~logger),
    }
  })
  ->Belt.Option.getWithDefault(defaultAddress)
}
let getBillingDetails = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
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
  ->Belt.Option.getWithDefault(defaultBillingDetails)
}

let getDefaultValues = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    unknownKeysWarning(["billingDetails"], json, "options.defaultValues", ~logger)
    let defaultValues: defaultValues = {
      billingDetails: getBillingDetails(json, "billingDetails", logger),
    }
    defaultValues
  })
  ->Belt.Option.getWithDefault(defaultDefaultValues)
}
let getBusiness = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    unknownKeysWarning(["name"], json, "options.business", ~logger)
    {
      name: getWarningString(json, "name", "", ~logger),
    }
  })
  ->Belt.Option.getWithDefault(defaultBusiness)
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
  if !Js.Array2.includes(goodVals, str) {
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
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
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
  ->Belt.Option.getWithDefault(defaultshowAddress)
}
let getDeatils = (val, logger) => {
  switch val->Js.Json.classify {
  | JSONString(str) => JSONString(str)
  | JSONObject(json) =>
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
  ->Js.Dict.get(str)
  ->Belt.Option.map(json => json->getDeatils(logger))
  ->Belt.Option.getWithDefault(defaultFields.billingDetails)
}
let getFields: (Js.Dict.t<Js.Json.t>, string, 'a) => fields = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    let defaultFields: fields = {
      billingDetails: getBilling(json, "billingDetails", logger),
    }
    defaultFields
  })
  ->Belt.Option.getWithDefault(defaultFields)
}
let getLayoutValues = (val, logger) => {
  switch val->Js.Json.classify {
  | JSONString(str) => StringLayout(str->getLayout(logger))
  | JSONObject(json) =>
    ObjectLayout({
      let layoutType = getWarningString(json, "type", "tabs", ~logger)
      unknownKeysWarning(
        ["defaultCollapsed", "radios", "spacedAccordionItems", "type"],
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
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
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
  ->Belt.Option.getWithDefault(defaultTerms)
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
  (val->getApplePayHeight(logger), val->getGooglePayHeight(logger), val->getPaypalHeight(logger))
}
let getStyle = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    unknownKeysWarning(["type", "theme", "height"], json, "options.wallets.style", ~logger)
    let style = {
      type_: getWarningString(json, "type", "", ~logger)->getTypeArray(logger),
      theme: getWarningString(json, "theme", "", ~logger)->getTheme(logger),
      height: getNumberWithWarning(json, "height", 48, ~logger)->getHeightArray(logger),
    }
    style
  })
  ->Belt.Option.getWithDefault(defaultStyle)
}
let getWallets = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    unknownKeysWarning(
      ["applePay", "googlePay", "style", "walletReturnUrl"],
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
      style: getStyle(json, "style", logger),
    }
  })
  ->Belt.Option.getWithDefault(defaultWallets)
}

let getLayout = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.map(json => {
    json->getLayoutValues(logger)
  })
  ->Belt.Option.getWithDefault(ObjectLayout(defaultLayout))
}

let getCardDetails = (dict, str) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      scheme: Some(getString(json, "scheme", "")),
      last4Digits: getString(json, "last4_digits", ""),
      expiryMonth: getString(json, "expiry_month", ""),
      expiryYear: getString(json, "expiry_year", ""),
      cardToken: getString(json, "card_token", ""),
      cardHolderName: Some(getString(json, "card_holder_name", "")),
    }
  })
  ->Belt.Option.getWithDefault(defaultCardDetails)
}

let createCustomerObjArr = dict => {
  let customerDict =
    dict
    ->Js.Dict.get("customerPaymentMethods")
    ->Belt.Option.flatMap(Js.Json.decodeObject)
    ->Belt.Option.getWithDefault(Js.Dict.empty())

  let customerArr =
    customerDict
    ->Js.Dict.get("customer_payment_methods")
    ->Belt.Option.flatMap(Js.Json.decodeArray)
    ->Belt.Option.getWithDefault([])

  let customerPaymentMethods =
    customerArr
    ->Belt.Array.keepMap(Js.Json.decodeObject)
    ->Js.Array2.map(json => {
      {
        paymentToken: getString(json, "payment_token", ""),
        customerId: getString(json, "customer_id", ""),
        paymentMethod: getString(json, "payment_method", ""),
        paymentMethodIssuer: Some(getString(json, "payment_method_issuer", "")),
        card: getCardDetails(json, "card"),
      }
    })
  LoadedSavedCards(customerPaymentMethods)
}

let getCustomerMethods = (dict, str) => {
  let customerArr =
    dict->Js.Dict.get(str)->Belt.Option.flatMap(Js.Json.decodeArray)->Belt.Option.getWithDefault([])

  if customerArr->Js.Array2.length !== 0 {
    let customerPaymentMethods =
      customerArr
      ->Belt.Array.keepMap(Js.Json.decodeObject)
      ->Js.Array2.map(json => {
        {
          paymentToken: getString(json, "payment_token", ""),
          customerId: getString(json, "customer_id", ""),
          paymentMethod: getString(json, "payment_method", ""),
          paymentMethodIssuer: Some(getString(json, "payment_method_issuer", "")),
          card: getCardDetails(json, "card"),
        }
      })
    LoadedSavedCards(customerPaymentMethods)
  } else {
    LoadingSavedCards
  }
}

let getCustomMethodNames = (dict, str) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeArray)
  ->Belt.Option.getWithDefault([])
  ->Belt.Array.keepMap(Js.Json.decodeObject)
  ->Js.Array2.map(json => {
    paymentMethodName: getString(json, "paymentMethodName", ""),
    aliasName: getString(json, "aliasName", ""),
  })
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
      "disableSaveCards",
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
    disableSaveCards: getBoolWithWarning(dict, "disableSaveCards", false, ~logger),
    readOnly: getBoolWithWarning(dict, "readOnly", false, ~logger),
    terms: getTerms(dict, "terms", logger),
    wallets: getWallets(dict, "wallets", logger),
    customMethodNames: getCustomMethodNames(dict, "customMethodNames"),
    payButtonStyle: getStyle(dict, "payButtonStyle", logger),
    showCardFormByDefault: getBool(dict, "showCardFormByDefault", true),
  }
}

type loadType = Loading | Loaded(Js.Json.t) | SemiLoaded | LoadError(Js.Json.t)

let getIsAllStoredCardsHaveName = (savedCards: array<customerMethods>) => {
  savedCards
  ->Js.Array2.filter(savedCard => {
    switch savedCard.card.cardHolderName {
    | None
    | Some("") => false
    | _ => true
    }
  })
  ->Belt.Array.length === savedCards->Belt.Array.length
}
