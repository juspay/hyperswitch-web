type cardIssuer =
  | VISA
  | MASTERCARD
  | AMEX
  | MAESTRO
  | DINERSCLUB
  | DISCOVER
  | BAJAJ
  | SODEXO
  | RUPAY
  | JCB
  | CARTESBANCAIRES
  | UNIONPAY
  | INTERAC
  | NOTFOUND

type cardProps = {
  isCardValid: option<bool>,
  setIsCardValid: (option<bool> => option<bool>) => unit,
  isCardSupported: option<bool>,
  cardNumber: string,
  changeCardNumber: JsxEvent.Form.t => unit,
  handleCardBlur: JsxEvent.Focus.t => unit,
  cardRef: React.ref<Nullable.t<Dom.element>>,
  icon: React.element,
  cardError: string,
  setCardError: (string => string) => unit,
  maxCardLength: int,
  cardBrand: string,
}

let useDefaultCardProps = () => {
  let cardRef = React.useRef(Nullable.null)
  {
    isCardValid: None,
    setIsCardValid: _ => (),
    isCardSupported: None,
    cardNumber: "",
    changeCardNumber: _ => (),
    handleCardBlur: _ => (),
    cardRef,
    icon: React.null,
    cardError: "",
    setCardError: _ => (),
    maxCardLength: 0,
    cardBrand: "",
  }
}

type expiryProps = {
  isExpiryValid: option<bool>,
  setIsExpiryValid: (option<bool> => option<bool>) => unit,
  cardExpiry: string,
  changeCardExpiry: JsxEvent.Form.t => unit,
  handleExpiryBlur: JsxEvent.Focus.t => unit,
  expiryRef: React.ref<Nullable.t<Dom.element>>,
  onExpiryKeyDown: ReactEvent.Keyboard.t => unit,
  expiryError: string,
  setExpiryError: (string => string) => unit,
}

let useDefaultExpiryProps = () => {
  let expiryRef = React.useRef(Nullable.null)
  {
    isExpiryValid: None,
    setIsExpiryValid: _ => (),
    cardExpiry: "",
    changeCardExpiry: _ => (),
    handleExpiryBlur: _ => (),
    expiryRef,
    onExpiryKeyDown: _ => (),
    expiryError: "",
    setExpiryError: _ => (),
  }
}

type cvcProps = {
  isCVCValid: option<bool>,
  setIsCVCValid: (option<bool> => option<bool>) => unit,
  cvcNumber: string,
  setCvcNumber: (string => string) => unit,
  changeCVCNumber: JsxEvent.Form.t => unit,
  handleCVCBlur: JsxEvent.Focus.t => unit,
  cvcRef: React.ref<Nullable.t<Dom.element>>,
  onCvcKeyDown: ReactEvent.Keyboard.t => unit,
  cvcError: string,
  setCvcError: (string => string) => unit,
}

let useDefaultCvcProps = () => {
  let cvcRef = React.useRef(Nullable.null)
  {
    isCVCValid: None,
    setIsCVCValid: _ => (),
    cvcNumber: "",
    setCvcNumber: _ => (),
    changeCVCNumber: _ => (),
    handleCVCBlur: _ => (),
    cvcRef,
    onCvcKeyDown: _ => (),
    cvcError: "",
    setCvcError: _ => (),
  }
}

type zipProps = {
  isZipValid: option<bool>,
  setIsZipValid: (option<bool> => option<bool>) => unit,
  zipCode: string,
  changeZipCode: ReactEvent.Form.t => unit,
  handleZipBlur: ReactEvent.Focus.t => unit,
  zipRef: React.ref<Nullable.t<Dom.element>>,
  onZipCodeKeyDown: ReactEvent.Keyboard.t => unit,
  displayPincode: bool,
}

let useDefaultZipProps = () => {
  let zipRef = React.useRef(Nullable.null)
  {
    isZipValid: None,
    setIsZipValid: _ => (),
    zipCode: "",
    changeZipCode: _ => (),
    handleZipBlur: _ => (),
    zipRef,
    onZipCodeKeyDown: _ => (),
    displayPincode: false,
  }
}

@val external document: 'a = "document"

@send external focus: Dom.element => unit = "focus"
@send external blur: Dom.element => unit = "blur"

type options = {timeZone: string}
type dateTimeFormat = {resolvedOptions: unit => options}
@val @scope("Intl") external dateTimeFormat: unit => dateTimeFormat = "DateTimeFormat"

let toInt = val => val->Int.fromString->Option.getOr(0)
let toString = val => val->Int.toString

let getQueryParamsDictforKey = (searchParams, keyName) => {
  let dict = Dict.make()

  searchParams
  ->String.split("&")
  ->Array.forEach(paramStr => {
    let keyValArr = String.split(paramStr, "=")
    let key = keyValArr->Array.get(0)->Option.getOr("")
    let value = if keyValArr->Array.length > 0 {
      keyValArr->Array.get(1)->Option.getOr("")
    } else {
      ""
    }
    Dict.set(dict, key, value)
  })

  dict->Dict.get(keyName)->Option.getOr("")
}
let getCardType = val => {
  switch val {
  | "Visa" => VISA
  | "Mastercard" => MASTERCARD
  | "AmericanExpress" => AMEX
  | "Maestro" => MAESTRO
  | "DinersClub" => DINERSCLUB
  | "Discover" => DISCOVER
  | "BAJAJ" => BAJAJ
  | "SODEXO" => SODEXO
  | "RuPay" => RUPAY
  | "JCB" => JCB
  | "CartesBancaires" => CARTESBANCAIRES
  | "UnionPay" => UNIONPAY
  | "Interac" => INTERAC
  | _ => NOTFOUND
  }
}

let getCardStringFromType = val => {
  switch val {
  | VISA => "Visa"
  | MASTERCARD => "Mastercard"
  | AMEX => "AmericanExpress"
  | MAESTRO => "Maestro"
  | DINERSCLUB => "DinersClub"
  | DISCOVER => "Discover"
  | BAJAJ => "BAJAJ"
  | SODEXO => "SODEXO"
  | RUPAY => "RuPay"
  | JCB => "JCB"
  | CARTESBANCAIRES => "CartesBancaires"
  | UNIONPAY => "UnionPay"
  | INTERAC => "Interac"
  | NOTFOUND => "NOTFOUND"
  }
}

let getobjFromCardPattern = cardBrand => {
  let patternsDict = CardPattern.cardPatterns
  patternsDict
  ->Array.filter(item => {
    cardBrand === item.issuer
  })
  ->Array.get(0)
  ->Option.getOr(CardPattern.defaultCardPattern)
}

let clearSpaces = value => {
  value->String.replaceRegExp(%re("/\D+/g"), "")
}

let slice = (val, start: int, end: int) => {
  val->String.slice(~start, ~end)
}

let getStrFromIndex = (arr: array<string>, index) => {
  arr->Array.get(index)->Option.getOr("")
}

let formatCVCNumber = (val, cardType) => {
  let clearValue = val->clearSpaces
  let obj = getobjFromCardPattern(cardType)
  clearValue->slice(0, obj.maxCVCLength)
}

let getCurrentMonthAndYear = (dateTimeIsoString: string) => {
  let tempTimeDateString = dateTimeIsoString->String.replace("Z", "")
  let tempTimeDate = tempTimeDateString->String.split("T")

  let date = tempTimeDate[0]->Option.getOr("")
  let dateComponents = date->String.split("-")

  let currentMonth = dateComponents->Array.get(1)->Option.getOr("")
  let currentYear = dateComponents->Array.get(0)->Option.getOr("")

  (currentMonth->toInt, currentYear->toInt)
}

let formatCardNumber = (val, cardType) => {
  let clearValue = val->clearSpaces
  let formatedCard = switch cardType {
  | AMEX => `${clearValue->slice(0, 4)} ${clearValue->slice(4, 10)} ${clearValue->slice(10, 15)}`
  | DINERSCLUB
  | MASTERCARD
  | DISCOVER
  | SODEXO
  | RUPAY
  | UNIONPAY
  | VISA =>
    `${clearValue->slice(0, 4)} ${clearValue->slice(4, 8)} ${clearValue->slice(
        8,
        12,
      )} ${clearValue->slice(12, 16)} ${clearValue->slice(16, 19)}`
  | _ =>
    `${clearValue->slice(0, 4)} ${clearValue->slice(4, 8)} ${clearValue->slice(
        8,
        12,
      )} ${clearValue->slice(12, 19)}`
  }

  formatedCard->String.trim
}
let splitExpiryDates = val => {
  let split = val->String.split("/")
  let value = split->Array.map(item => item->String.trim)
  let month = value->Array.get(0)->Option.getOr("")
  let year = value->Array.get(1)->Option.getOr("")
  (month, year)
}
let getExpiryDates = val => {
  let date = Date.make()->Date.toISOString
  let (month, year) = splitExpiryDates(val)
  let (_, currentYear) = getCurrentMonthAndYear(date)
  let prefix = currentYear->Int.toString->String.slice(~start=0, ~end=2)
  (month, `${prefix}${year}`)
}
let formatExpiryToTwoDigit = expiry => {
  if expiry->String.length == 2 {
    expiry
  } else {
    expiry->String.slice(~start=2, ~end=4)
  }
}

let isExpiryComplete = val => {
  let (month, year) = splitExpiryDates(val)
  month->String.length == 2 && year->String.length == 2
}

let formatCardExpiryNumber = val => {
  let clearValue = val->clearSpaces
  let expiryVal = clearValue->toInt
  let formatted = if expiryVal >= 2 && expiryVal <= 9 && clearValue->String.length == 1 {
    `0${clearValue} / `
  } else if clearValue->String.length == 2 && expiryVal > 12 {
    let val = clearValue->String.split("")
    `0${val->getStrFromIndex(0)} / ${val->getStrFromIndex(1)}`
  } else {
    clearValue
  }

  if clearValue->String.length >= 3 {
    `${formatted->slice(0, 2)} / ${formatted->slice(2, 4)}`
  } else {
    formatted
  }
}

let getCardBrand = cardNumber => {
  try {
    let card = cardNumber->String.replaceRegExp(%re("/[^\d]/g"), "")
    let rupayRanges = [
      (508227, 508227),
      (508500, 508999),
      (603741, 603741),
      (606985, 607384),
      (607385, 607484),
      (607485, 607984),
      (608001, 608100),
      (608101, 608200),
      (608201, 608300),
      (608301, 608350),
      (608351, 608500),
      (652150, 652849),
      (652850, 653049),
      (653050, 653149),
      (817290, 817290),
    ]

    let masterCardRanges = [(222100, 272099), (510000, 559999)]

    let doesFallInRange = (cardRanges, isin) => {
      let intIsin =
        isin
        ->String.replaceRegExp(%re("/[^\d]/g"), "")
        ->String.substring(~start=0, ~end=6)
        ->Int.fromString
        ->Option.getOr(0)

      let range = cardRanges->Array.map(cardRange => {
        let (min, max) = cardRange

        intIsin >= min && intIsin <= max
      })
      range->Array.includes(true)
    }
    let patternsDict = CardPattern.cardPatterns
    if doesFallInRange(rupayRanges, card) {
      "RuPay"
    } else if doesFallInRange(masterCardRanges, card) {
      "Mastercard"
    } else {
      patternsDict
      ->Array.map(item => {
        if String.match(card, item.pattern)->Option.isSome {
          item.issuer
        } else {
          ""
        }
      })
      ->Array.filter(item => item !== "")
      ->Array.get(0)
      ->Option.getOr("")
    }
  } catch {
  | _error => ""
  }
}

let calculateLuhn = value => {
  let card = value->clearSpaces
  let splitArr = card->String.split("")
  splitArr->Array.reverse
  let unCheckArr = splitArr->Array.filterWithIndex((_, i) => {
    mod(i, 2) == 0
  })
  let checkArr =
    splitArr
    ->Array.filterWithIndex((_, i) => {
      mod(i + 1, 2) == 0
    })
    ->Array.map(item => {
      let val = item->toInt
      let double = val * 2
      let str = double->Int.toString
      let arr = str->String.split("")

      switch (arr[0], arr[1]) {
      | (Some(first), Some(second)) if double > 9 => (first->toInt + second->toInt)->Int.toString
      | _ => str
      }
    })

  let sumofCheckArr = Array.reduce(checkArr, 0, (acc, val) => acc + val->toInt)
  let sumofUnCheckedArr = Array.reduce(unCheckArr, 0, (acc, val) => acc + val->toInt)
  let totalSum = sumofCheckArr + sumofUnCheckedArr

  mod(totalSum, 10) == 0 || ["3000100811111072", "4000100511112003"]->Array.includes(card) // test cards
}

let getCardBrandIcon = (cardType, paymentType) => {
  open CardThemeType
  open Utils
  switch cardType {
  | VISA => <Icon size=brandIconSize name="visa-light" />
  | MASTERCARD => <Icon size=brandIconSize name="mastercard" />
  | AMEX => <Icon size=brandIconSize name="amex-light" />
  | MAESTRO => <Icon size=brandIconSize name="maestro" />
  | DINERSCLUB => <Icon size=brandIconSize name="diners" />
  | DISCOVER => <Icon size=brandIconSize name="discover" />
  | BAJAJ => <Icon size=brandIconSize name="card" />
  | SODEXO => <Icon size=brandIconSize name="card" />
  | RUPAY => <Icon size=brandIconSize name="rupay-card" />
  | JCB => <Icon size=brandIconSize name="jcb-card" />
  | CARTESBANCAIRES => <Icon size=brandIconSize name="cartesbancaires-card" />
  | UNIONPAY => <Icon size=brandIconSize name="union-pay" />
  | INTERAC => <Icon size=brandIconSize name="interac" />
  | NOTFOUND =>
    switch paymentType {
    | Payment => <Icon size=brandIconSize name="base-card" />
    | Card
    | CardNumberElement
    | CardExpiryElement
    | CardCVCElement
    | PaymentMethodCollectElement
    | GooglePayElement
    | PayPalElement
    | ApplePayElement
    | SamsungPayElement
    | KlarnaElement
    | ExpressCheckoutElement
    | PaymentMethodsManagement
    | PazeElement
    | NONE =>
      <Icon size=brandIconSize name="default-card" />
    }
  }
}

let getExpiryValidity = cardExpiry => {
  let date = Date.make()->Date.toISOString
  let (month, year) = getExpiryDates(cardExpiry)
  let (currentMonth, currentYear) = getCurrentMonthAndYear(date)
  let valid = if currentYear == year->toInt && month->toInt >= currentMonth && month->toInt <= 12 {
    true
  } else if (
    year->toInt > currentYear &&
    year->toInt < Date.getFullYear(Js.Date.fromFloat(Date.now())) + 100 &&
    month->toInt >= 1 &&
    month->toInt <= 12
  ) {
    true
  } else {
    false
  }
  valid
}
let isExipryValid = val => {
  val->String.length > 0 && getExpiryValidity(val) && isExpiryComplete(val)
}

let cardNumberInRange = (val, cardBrand) => {
  let clearValue = val->clearSpaces
  let obj = getobjFromCardPattern(cardBrand)
  let cardLengthInRange = obj.length->Array.map(item => {
    clearValue->String.length == item
  })
  cardLengthInRange
}
let max = (a, b) => {
  Math.Int.max(a, b)
}

let getMaxLength = val => {
  let obj = getobjFromCardPattern(val)
  let maxValue = obj.length->Array.reduce(0, max)
  if maxValue <= 12 {
    maxValue + 2
  } else if maxValue <= 16 {
    maxValue + 3
  } else if maxValue <= 19 {
    maxValue + 4
  } else {
    maxValue + 2
  }
}

let cvcNumberInRange = (val, cardBrand) => {
  let clearValue = val->clearSpaces
  let obj = getobjFromCardPattern(cardBrand)
  let cvcLengthInRange = obj.cvcLength->Array.map(item => {
    clearValue->String.length == item
  })
  cvcLengthInRange
}
let generateFontsLink = (fonts: array<CardThemeType.fonts>) => {
  if fonts->Array.length > 0 {
    fonts
    ->Array.map(item =>
      if item.cssSrc != "" {
        let link = document["createElement"]("link")
        link["href"] = item.cssSrc
        link["rel"] = "stylesheet"
        document["body"]["appendChild"](link)
      } else if item.family != "" && item.src != "" {
        let newStyle = document["createElement"]("style")
        newStyle["appendChild"](
          document["createTextNode"](
            `\
@font-face {\
    font-family: "${item.family}";\
    src: url(${item.src});\
    font-weight: "${item.weight}";\
}\
`,
          ),
        )->ignore
        document["body"]["appendChild"](newStyle)
      }
    )
    ->ignore
  }
}

let maxCardLength = cardBrand => {
  let obj = getobjFromCardPattern(cardBrand)
  Array.reduce(obj.length, 0, (acc, val) => max(acc, val))
}

let isCardLengthValid = (cardBrand, cardNumberLength) => {
  let obj = getobjFromCardPattern(cardBrand)
  Array.includes(obj.length, cardNumberLength)
}

let cardValid = (cardNumber, cardBrand) => {
  let clearValueLength = cardNumber->clearSpaces->String.length
  isCardLengthValid(cardBrand, clearValueLength) && calculateLuhn(cardNumber)
}

let focusCardValid = (cardNumber, cardBrand) => {
  let clearValueLength = cardNumber->clearSpaces->String.length
  if cardBrand == "" {
    clearValueLength == maxCardLength(cardBrand) && calculateLuhn(cardNumber)
  } else {
    (clearValueLength == maxCardLength(cardBrand) ||
      (cardBrand === "Visa" && clearValueLength == 16)) && calculateLuhn(cardNumber)
  }
}

let blurRef = (ref: React.ref<Nullable.t<Dom.element>>) => {
  ref.current->Nullable.toOption->Option.forEach(input => input->blur)->ignore
}

let focusRef = (ref: React.ref<Nullable.t<Dom.element>>) => {
  ref.current->Nullable.toOption->Option.forEach(input => input->focus)->ignore
}

let handleInputFocus = (
  ~currentRef: React.ref<Nullable.t<Dom.element>>,
  ~destinationRef: React.ref<Nullable.t<Dom.element>>,
) => {
  let optionalRef = destinationRef.current->Nullable.toOption
  switch optionalRef {
  | Some(_) => optionalRef->Option.forEach(input => input->focus)->ignore
  | None => blurRef(currentRef)
  }
}

let getCardElementValue = (iframeId, key) => {
  let firstIframeVal = if (Window.parent->Window.frames)["0"]->Window.name !== iframeId {
    switch (Window.parent->Window.frames)["0"]
    ->Window.document
    ->Window.getElementById(key)
    ->Nullable.toOption {
    | Some(dom) => dom->Window.value
    | None => ""
    }
  } else {
    ""
  }
  let secondIframeVal = if (Window.parent->Window.frames)["1"]->Window.name !== iframeId {
    switch (Window.parent->Window.frames)["1"]
    ->Window.document
    ->Window.getElementById(key)
    ->Nullable.toOption {
    | Some(dom) => dom->Window.value
    | None => ""
    }
  } else {
    ""
  }

  let thirdIframeVal = if (Window.parent->Window.frames)["2"]->Window.name !== iframeId {
    switch (Window.parent->Window.frames)["2"]
    ->Window.document
    ->Window.getElementById(key)
    ->Nullable.toOption {
    | Some(dom) => dom->Window.value
    | None => ""
    }
  } else {
    ""
  }
  thirdIframeVal === "" ? secondIframeVal === "" ? firstIframeVal : secondIframeVal : thirdIframeVal
}

let checkCardCVC = (cvcNumber, cardBrand) => {
  cvcNumber->String.length > 0 && cvcNumberInRange(cvcNumber, cardBrand)->Array.includes(true)
}
let checkCardExpiry = expiry => {
  expiry->String.length > 0 && getExpiryValidity(expiry)
}

let getBoolOptionVal = boolOptionVal => {
  switch boolOptionVal {
  | Some(bool) => bool ? "valid" : "invalid"
  | None => ""
  }
}

let commonKeyDownEvent = (ev, srcRef, destRef, srcEle, destEle, setEle) => {
  let key = ReactEvent.Keyboard.keyCode(ev)
  if key == 8 && srcEle == "" {
    handleInputFocus(~currentRef=srcRef, ~destinationRef=destRef)
    setEle(_ => slice(destEle, 0, -1))
    ev->ReactEvent.Keyboard.preventDefault
  }
}

let pincodeVisibility = brand => {
  let brandPattern =
    CardPattern.cardPatterns
    ->Array.filter(obj => obj.issuer == brand)
    ->Array.get(0)
    ->Option.getOr(CardPattern.defaultCardPattern)
  brandPattern.pincodeRequired
}

let swapCardOption = (cardOpts: array<string>, dropOpts: array<string>, selectedOption: string) => {
  let popEle = Array.pop(cardOpts)
  dropOpts->Array.push(popEle->Option.getOr(""))->ignore
  cardOpts->Array.push(selectedOption)->ignore
  let temp: array<string> = dropOpts->Array.filter(item => item != selectedOption)
  (cardOpts, temp)
}

let setCardValid = (cardnumber, cardBrand, setIsCardValid) => {
  let isCardMaxLength = cardnumber->String.length == maxCardLength(cardBrand)
  if cardValid(cardnumber, cardBrand) {
    setIsCardValid(_ => Some(true))
  } else if !cardValid(cardnumber, cardBrand) && isCardMaxLength {
    setIsCardValid(_ => Some(false))
  } else if !isCardMaxLength {
    setIsCardValid(_ => None)
  }
}

let setExpiryValid = (expiry, setIsExpiryValid) => {
  if isExipryValid(expiry) {
    setIsExpiryValid(_ => Some(true))
  } else if !getExpiryValidity(expiry) && isExpiryComplete(expiry) {
    setIsExpiryValid(_ => Some(false))
  } else if !isExpiryComplete(expiry) {
    setIsExpiryValid(_ => None)
  }
}
let getLayoutClass = layout => {
  open PaymentType
  switch layout {
  | ObjectLayout(obj) => obj
  | StringLayout(str) => {
      ...defaultLayout,
      \"type": str,
    }
  }
}

let getAllBanknames = obj => {
  obj->Array.reduce([], (acc, item) => {
    item->Array.map(val => acc->Array.push(val))->ignore
    acc
  })
}

let clientTimeZone = dateTimeFormat().resolvedOptions().timeZone
let clientCountry = Utils.getClientCountry(clientTimeZone)

let postalRegex = (postalCodes: array<PostalCodeType.postalCodes>, ~country=?) => {
  let country = country->Option.getOr(clientCountry.isoAlpha2)
  let countryPostal = Utils.getCountryPostal(country, postalCodes)
  countryPostal.regex
}

let setRightIconForCvc = (~cardEmpty, ~cardInvalid, ~color, ~cardComplete) => {
  open Utils
  if cardEmpty {
    <Icon size=brandIconSize name="cvc-empty" />
  } else if cardInvalid {
    <div style={color: color}>
      <Icon size=brandIconSize name="cvc-invalid" />
    </div>
  } else if cardComplete {
    <Icon size=brandIconSize name="cvc-complete" />
  } else {
    <Icon size=brandIconSize name="cvc-empty" />
  }
}

let useCardDetails = (~cvcNumber, ~isCvcValidValue, ~isCVCValid) => {
  React.useMemo(() => {
    let isCardDetailsEmpty = String.length(cvcNumber) == 0
    let isCardDetailsValid = isCvcValidValue == "valid"
    let isCardDetailsInvalid = isCvcValidValue == "invalid"
    (isCardDetailsEmpty, isCardDetailsValid, isCardDetailsInvalid)
  }, (cvcNumber, isCvcValidValue, isCVCValid))
}

let getWalletBrandIcon = (customerMethod: PaymentType.customerMethods) => {
  let iconName = switch customerMethod.paymentMethodType {
  | Some("apple_pay") => "apple_pay_saved"
  | Some("google_pay") => "google_pay_saved"
  | Some("samsung_pay") => "samsung_pay_saved"
  | Some("paypal") => "paypal"
  | _ => "default-card"
  }

  <Icon size=Utils.brandIconSize name=iconName />
}

let getPaymentMethodBrand = (customerMethod: PaymentType.customerMethods) => {
  switch customerMethod.paymentMethod {
  | "wallet" => getWalletBrandIcon(customerMethod)
  | _ =>
    getCardBrandIcon(
      switch customerMethod.card.scheme {
      | Some(ele) => ele
      | None => ""
      }->getCardType,
      ""->CardThemeType.getPaymentMode,
    )
  }
}

let getAllMatchedCardSchemes = cardNumber => {
  CardPattern.cardPatterns->Array.reduce([], (acc, item) => {
    if String.match(cardNumber, item.pattern)->Option.isSome {
      acc->Array.push(item.issuer)
    }
    acc
  })
}

let isCardSchemeEnabled = (~cardScheme, ~enabledCardSchemes) => {
  enabledCardSchemes->Array.includes(cardScheme)
}

let getFirstValidCardSchemeFromPML = (~cardNumber, ~enabledCardSchemes) => {
  let allMatchedCards = getAllMatchedCardSchemes(cardNumber->clearSpaces)
  allMatchedCards->Array.find(card =>
    isCardSchemeEnabled(~cardScheme=card->String.toLowerCase, ~enabledCardSchemes)
  )
}

let getEligibleCoBadgedCardSchemes = (~matchedCardSchemes, ~enabledCardSchemes) => {
  matchedCardSchemes->Array.filter(ele => {
    enabledCardSchemes->Array.includes(ele->String.toLowerCase)
  })
}

let getCardBrandFromStates = (cardBrand, cardScheme, showFields) => {
  !showFields ? cardScheme : cardBrand
}

let getCardBrandInvalidError = (~cardBrand, ~localeString: LocaleStringTypes.localeStrings) => {
  switch cardBrand {
  | "" => localeString.enterValidCardNumberErrorText
  | cardBrandValue => localeString.cardBrandConfiguredErrorText(cardBrandValue)
  }
}

let emitExpiryDate = formattedExpiry =>
  Utils.messageParentWindow([("expiryDate", formattedExpiry->JSON.Encode.string)])

let emitIsFormReadyForSubmission = isFormReadyForSubmission =>
  Utils.messageParentWindow([
    ("isFormReadyForSubmission", isFormReadyForSubmission->JSON.Encode.bool),
  ])
