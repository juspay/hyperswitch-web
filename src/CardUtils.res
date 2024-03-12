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

type cardProps = (
  option<bool>,
  (option<bool> => option<bool>) => unit,
  string,
  JsxEvent.Form.t => unit,
  JsxEvent.Focus.t => unit,
  React.ref<Js.Nullable.t<Dom.element>>,
  React.element,
  string,
  (string => string) => unit,
  int,
)

type expiryProps = (
  option<bool>,
  (option<bool> => option<bool>) => unit,
  string,
  JsxEvent.Form.t => unit,
  JsxEvent.Focus.t => unit,
  React.ref<Js.Nullable.t<Dom.element>>,
  ReactEvent.Keyboard.t => unit,
  string,
  (string => string) => unit,
)

type cvcProps = (
  option<bool>,
  (option<bool> => option<bool>) => unit,
  string,
  (string => string) => unit,
  JsxEvent.Form.t => unit,
  JsxEvent.Focus.t => unit,
  React.ref<Js.Nullable.t<Dom.element>>,
  ReactEvent.Keyboard.t => unit,
  string,
  (string => string) => unit,
)
type zipProps = (
  option<bool>,
  (option<bool> => option<bool>) => unit,
  string,
  ReactEvent.Form.t => unit,
  ReactEvent.Focus.t => unit,
  React.ref<Js.Nullable.t<Dom.element>>,
  ReactEvent.Keyboard.t => unit,
  bool,
)
@val external document: 'a = "document"

@send external focus: Dom.element => unit = "focus"
@send external blur: Dom.element => unit = "blur"

type options = {timeZone: string}
type dateTimeFormat = {resolvedOptions: (. unit) => options}
@val @scope("Intl") external dateTimeFormat: (. unit) => dateTimeFormat = "DateTimeFormat"

let toInt = val => val->Belt.Int.fromString->Belt.Option.getWithDefault(0)
let toString = val => val->Belt.Int.toString

let getQueryParamsDictforKey = (searchParams, keyName) => {
  let dict = Js.Dict.empty()

  searchParams
  ->Js.String2.split("&")
  ->Js.Array2.forEach(paramStr => {
    let keyValArr = Js.String2.split(paramStr, "=")
    let key = keyValArr->Belt.Array.get(0)->Belt.Option.getWithDefault("")
    let value = if keyValArr->Js.Array2.length > 0 {
      keyValArr->Belt.Array.get(1)->Belt.Option.getWithDefault("")
    } else {
      ""
    }
    Js.Dict.set(dict, key, value)
  })

  dict->Js.Dict.get(keyName)->Belt.Option.getWithDefault("")
}
let cardType = val => {
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

let getobjFromCardPattern = cardBrand => {
  let patternsDict = CardPattern.cardPatterns
  patternsDict
  ->Js.Array2.filter(item => {
    cardBrand === item.issuer
  })
  ->Belt.Array.get(0)
  ->Belt.Option.getWithDefault(CardPattern.defaultCardPattern)
}

let clearSpaces = value => {
  value->Js.String2.replaceByRe(%re("/\D+/g"), "")
}

let slice = (val, from: int, to_: int) => {
  val->Js.String2.slice(~from, ~to_)
}

let getStrFromIndex = (arr: array<string>, index) => {
  arr->Belt.Array.get(index)->Belt.Option.getWithDefault("")
}

let formatCVCNumber = (val, cardType) => {
  let clearValue = val->clearSpaces
  let obj = getobjFromCardPattern(cardType)
  clearValue->slice(0, obj.maxCVCLenth)
}

let getCurrentMonthAndYear = (dateTimeIsoString: string) => {
  let tempTimeDateString = dateTimeIsoString->Js.String2.replace("Z", "")
  let tempTimeDate = tempTimeDateString->Js.String2.split("T")

  let date = tempTimeDate[0]->Option.getOr("")
  let dateComponents = date->Js.String2.split("-")

  let currentMonth = dateComponents->Belt.Array.get(1)->Belt.Option.getWithDefault("")
  let currentYear = dateComponents->Belt.Array.get(0)->Belt.Option.getWithDefault("")

  (currentMonth->toInt, currentYear->toInt)
}

let formatCardNumber = (val, cardType) => {
  let clearValue = val->clearSpaces
  let formatedCard = switch cardType {
  | AMEX => `${clearValue->slice(0, 4)} ${clearValue->slice(4, 10)} ${clearValue->slice(10, 15)}`
  | DINERSCLUB =>
    `${clearValue->slice(0, 4)} ${clearValue->slice(4, 10)} ${clearValue->slice(10, 14)}`
  | MASTERCARD
  | DISCOVER
  | SODEXO
  | RUPAY
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

  formatedCard->Js.String2.trim
}
let splitExpiryDates = val => {
  let split = val->Js.String2.split("/")
  let value = split->Js.Array2.map(item => item->Js.String2.trim)
  let month = value->Belt.Array.get(0)->Belt.Option.getWithDefault("")
  let year = value->Belt.Array.get(1)->Belt.Option.getWithDefault("")
  (month, year)
}
let getExpiryDates = val => {
  let date = Js.Date.make()->Js.Date.toISOString
  let (month, year) = splitExpiryDates(val)
  let (_, currentYear) = getCurrentMonthAndYear(date)
  let prefix = currentYear->Belt.Int.toString->Js.String2.slice(~from=0, ~to_=2)
  (month, `${prefix}${year}`)
}
let formatExpiryToTwoDigit = expiry => {
  if expiry->Js.String2.length == 2 {
    expiry
  } else {
    expiry->Js.String2.slice(~from=2, ~to_=4)
  }
}

let isExipryComplete = val => {
  let (month, year) = splitExpiryDates(val)
  month->Js.String2.length == 2 && year->Js.String2.length == 2
}

let formatCardExpiryNumber = val => {
  let clearValue = val->clearSpaces
  let expiryVal = clearValue->toInt
  let formatted = if expiryVal >= 2 && expiryVal <= 9 && clearValue->Js.String2.length == 1 {
    `0${clearValue} / `
  } else if clearValue->Js.String2.length == 2 && expiryVal > 12 {
    let val = clearValue->Js.String2.split("")
    `0${val->getStrFromIndex(0)} / ${val->getStrFromIndex(1)}`
  } else {
    clearValue
  }

  if clearValue->Js.String2.length >= 3 {
    `${formatted->slice(0, 2)} / ${formatted->slice(2, 4)}`
  } else {
    formatted
  }
}

let getCardBrand = cardNumber => {
  try {
    let card = cardNumber->Js.String2.replaceByRe(%re("/[^\d]/g"), "")
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
        ->Js.String2.replaceByRe(%re("/[^\d]/g"), "")
        ->Js.String2.substring(~from=0, ~to_=6)
        ->Belt.Int.fromString
        ->Belt.Option.getWithDefault(0)

      let range = cardRanges->Js.Array2.map(cardRange => {
        let (min, max) = cardRange

        intIsin >= min && intIsin <= max
      })
      range->Js.Array2.includes(true)
    }
    let patternsDict = CardPattern.cardPatterns
    if doesFallInRange(rupayRanges, card) {
      "RuPay"
    } else if doesFallInRange(masterCardRanges, card) {
      "Mastercard"
    } else {
      patternsDict
      ->Js.Array2.map(item => {
        if Js.String2.match_(card, item.pattern)->Belt.Option.isSome {
          item.issuer
        } else {
          ""
        }
      })
      ->Js.Array2.filter(item => item !== "")
      ->Belt.Array.get(0)
      ->Belt.Option.getWithDefault("")
    }
  } catch {
  | _error => ""
  }
}

let calculateLuhn = value => {
  let card = value->clearSpaces

  let splitArr = card->Js.String2.split("")->Js.Array2.reverseInPlace
  let unCheckArr = splitArr->Js.Array2.filteri((_, i) => {
    mod(i, 2) == 0
  })
  let checkArr =
    splitArr
    ->Js.Array2.filteri((_, i) => {
      mod(i + 1, 2) == 0
    })
    ->Js.Array2.map(item => {
      let val = item->toInt
      let double = val * 2
      let str = double->Belt.Int.toString
      let arr = str->Js.String2.split("")

      switch (arr[0], arr[1]) {
      | (Some(first), Some(second)) if double > 9 =>
        (first->toInt + second->toInt)->Belt.Int.toString
      | _ => str
      }
    })

  let sumofCheckArr = Belt.Array.reduce(checkArr, 0, (acc, val) => acc + val->toInt)
  let sumofUnCheckedArr = Belt.Array.reduce(unCheckArr, 0, (acc, val) => acc + val->toInt)
  let totalSum = sumofCheckArr + sumofUnCheckedArr
  mod(totalSum, 10) == 0
}

let getCardBrandIcon = (cardType, paymentType) => {
  open CardThemeType
  switch cardType {
  | VISA => <Icon size=Utils.brandIconSize name="visa-light" />
  | MASTERCARD => <Icon size=Utils.brandIconSize name="mastercard" />
  | AMEX => <Icon size=Utils.brandIconSize name="amex-light" />
  | MAESTRO => <Icon size=Utils.brandIconSize name="maestro" />
  | DINERSCLUB => <Icon size=Utils.brandIconSize name="diners" />
  | DISCOVER => <Icon size=Utils.brandIconSize name="discover" />
  | BAJAJ => <Icon size=Utils.brandIconSize name="card" />
  | SODEXO => <Icon size=Utils.brandIconSize name="card" />
  | RUPAY => <Icon size=Utils.brandIconSize name="rupay-card" />
  | JCB => <Icon size=Utils.brandIconSize name="jcb-card" />
  | CARTESBANCAIRES => <Icon size=Utils.brandIconSize name="card" />
  | UNIONPAY => <Icon size=Utils.brandIconSize name="card" />
  | INTERAC => <Icon size=Utils.brandIconSize name="interac" />
  | NOTFOUND =>
    switch paymentType {
    | Payment => <Icon size=Utils.brandIconSize name="base-card" />
    | Card
    | CardNumberElement
    | CardExpiryElement
    | CardCVCElement
    | NONE =>
      <Icon size=Utils.brandIconSize name="default-card" />
    }
  }
}

let getExpiryValidity = cardExpiry => {
  let date = Js.Date.make()->Js.Date.toISOString
  let (month, year) = getExpiryDates(cardExpiry)
  let (currentMonth, currentYear) = getCurrentMonthAndYear(date)
  let valid = if currentYear == year->toInt && month->toInt >= currentMonth && month->toInt <= 12 {
    true
  } else if (
    year->toInt > currentYear && year->toInt < 2075 && month->toInt >= 1 && month->toInt <= 12
  ) {
    true
  } else {
    false
  }
  valid
}
let isExipryValid = val => {
  val->Js.String2.length > 0 && getExpiryValidity(val) && isExipryComplete(val)
}

let cardNumberInRange = val => {
  let clearValue = val->clearSpaces
  let obj = getobjFromCardPattern(val->getCardBrand)
  let cardLengthInRange = obj.length->Js.Array2.map(item => {
    clearValue->Js.String2.length == item
  })
  cardLengthInRange
}
let max = (a, b) => {
  a > b ? a : b
}

let getMaxLength = val => {
  let obj = getobjFromCardPattern(val->getCardBrand)
  let maxValue = Js.Array.reduce(max, 0, obj.length)
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
  let cvcLengthInRange = obj.cvcLength->Js.Array2.map(item => {
    clearValue->Js.String2.length == item
  })
  cvcLengthInRange
}
let genreateFontsLink = (fonts: array<CardThemeType.fonts>) => {
  if fonts->Js.Array2.length > 0 {
    fonts
    ->Js.Array2.map(item =>
      if item.cssSrc != "" {
        let link = document["createElement"](. "link")
        link["href"] = item.cssSrc
        link["rel"] = "stylesheet"
        document["body"]["appendChild"](. link)
      } else if item.family != "" && item.src != "" {
        let newStyle = document["createElement"](. "style")
        newStyle["appendChild"](.
          document["createTextNode"](.
            `\
@font-face {\
    font-family: "${item.family}";\
    src: url(${item.src});\
    font-weight: "${item.weight}";\
}\
`,
          ),
        )->ignore
        document["body"]["appendChild"](. newStyle)
      }
    )
    ->ignore
  }
}
let maxCardLength = cardBrand => {
  let obj = getobjFromCardPattern(cardBrand)
  Belt.Array.reduce(obj.length, 0, (acc, val) => acc > val ? acc : val)
}

let cardValid = (cardNumber, cardBrand) => {
  let clearValueLength = cardNumber->clearSpaces->Js.String2.length
  (clearValueLength == maxCardLength(cardBrand) ||
    (cardBrand === "Visa" && clearValueLength == 16)) && calculateLuhn(cardNumber)
}
let blurRef = (ref: React.ref<Js.Nullable.t<Dom.element>>) => {
  ref.current->Js.Nullable.toOption->Belt.Option.forEach(input => input->blur)->ignore
}
let handleInputFocus = (
  ~currentRef: React.ref<Js.Nullable.t<Dom.element>>,
  ~destinationRef: React.ref<Js.Nullable.t<Dom.element>>,
) => {
  let optionalRef = destinationRef.current->Js.Nullable.toOption
  switch optionalRef {
  | Some(_) => optionalRef->Belt.Option.forEach(input => input->focus)->ignore
  | None => blurRef(currentRef)
  }
}

let getCardElementValue = (iframeId, key) => {
  let firstIframeVal = if (Window.parent->Window.frames)["0"]->Window.name !== iframeId {
    switch (Window.parent->Window.frames)["0"]
    ->Window.document
    ->Window.getElementById(key)
    ->Js.Nullable.toOption {
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
    ->Js.Nullable.toOption {
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
    ->Js.Nullable.toOption {
    | Some(dom) => dom->Window.value
    | None => ""
    }
  } else {
    ""
  }
  thirdIframeVal === "" ? secondIframeVal === "" ? firstIframeVal : secondIframeVal : thirdIframeVal
}

let checkCardCVC = (cvcNumber, cardBrand) => {
  cvcNumber->Js.String2.length > 0 &&
    cvcNumberInRange(cvcNumber, cardBrand)->Js.Array2.includes(true)
}
let checkCardExpiry = expiry => {
  expiry->Js.String2.length > 0 && getExpiryValidity(expiry)
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

let pincodeVisibility = cardNumber => {
  let brand = getCardBrand(cardNumber)
  let brandPattern =
    CardPattern.cardPatterns
    ->Js.Array2.filter(obj => obj.issuer == brand)
    ->Belt.Array.get(0)
    ->Belt.Option.getWithDefault(CardPattern.defaultCardPattern)
  brandPattern.pincodeRequired
}

let swapCardOption = (cardOpts: array<string>, dropOpts: array<string>, selectedOption: string) => {
  let popEle = Js.Array2.pop(cardOpts)
  dropOpts->Js.Array2.push(popEle->Belt.Option.getWithDefault(""))->ignore
  cardOpts->Js.Array2.push(selectedOption)->ignore
  let temp: array<string> = dropOpts->Js.Array2.filter(item => item != selectedOption)
  (cardOpts, temp)
}

let setCardValid = (cardnumber, setIsCardValid) => {
  let cardBrand = getCardBrand(cardnumber)
  if cardValid(cardnumber, cardBrand) {
    setIsCardValid(_ => Some(true))
  } else if (
    !cardValid(cardnumber, cardBrand) && cardnumber->Js.String2.length == maxCardLength(cardBrand)
  ) {
    setIsCardValid(_ => Some(false))
  } else if !(cardnumber->Js.String2.length == maxCardLength(cardBrand)) {
    setIsCardValid(_ => None)
  }
}

let setExpiryValid = (expiry, setIsExpiryValid) => {
  if isExipryValid(expiry) {
    setIsExpiryValid(_ => Some(true))
  } else if !getExpiryValidity(expiry) && isExipryComplete(expiry) {
    setIsExpiryValid(_ => Some(false))
  } else if !isExipryComplete(expiry) {
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
  obj->Js.Array2.reduce((acc, item) => {
    item->Js.Array2.map(val => acc->Js.Array2.push(val))->ignore
    acc
  }, [])
}

let clientTimeZone = dateTimeFormat(.).resolvedOptions(.).timeZone
let clientCountry = Utils.getClientCountry(clientTimeZone)

let postalRegex = (postalCodes: array<PostalCodeType.postalCodes>, ~country=?, ()) => {
  let country = switch country {
  | Some(val) => val
  | None => clientCountry.isoAlpha2
  }
  let countryPostal = Utils.getCountryPostal(country, postalCodes)
  countryPostal.regex == "" ? "" : countryPostal.regex
}

let getCardDetailsFromCardProps = cardProps => {
  let defaultCardProps = (
    None,
    _ => (),
    "",
    _ => (),
    _ => (),
    React.useRef(Js.Nullable.null),
    <> </>,
    "",
    _ => (),
    0,
  )

  switch cardProps {
  | Some(cardProps) => cardProps
  | None => defaultCardProps
  }
}

let getExpiryDetailsFromExpiryProps = expiryProps => {
  let defaultExpiryProps = (
    None,
    _ => (),
    "",
    _ => (),
    _ => (),
    React.useRef(Js.Nullable.null),
    _ => (),
    "",
    _ => (),
  )

  switch expiryProps {
  | Some(expiryProps) => expiryProps
  | None => defaultExpiryProps
  }
}

let getCvcDetailsFromCvcProps = cvcProps => {
  let defaultCvcProps = (
    None,
    _ => (),
    "",
    _ => (),
    _ => (),
    _ => (),
    React.useRef(Js.Nullable.null),
    _ => (),
    "",
    _ => (),
  )

  switch cvcProps {
  | Some(cvcProps) => cvcProps
  | None => defaultCvcProps
  }
}

let setRightIconForCvc = (~cardEmpty, ~cardInvalid, ~color, ~cardComplete) => {
  if cardEmpty {
    <Icon size=Utils.brandIconSize name="cvc-empty" />
  } else if cardInvalid {
    <div style={ReactDOMStyle.make(~color, ())}>
      <Icon size=Utils.brandIconSize name="cvc-invalid" />
    </div>
  } else if cardComplete {
    <Icon size=Utils.brandIconSize name="cvc-complete" />
  } else {
    <Icon size=Utils.brandIconSize name="cvc-empty" />
  }
}

let useCardDetails = (~cvcNumber, ~isCvcValidValue, ~isCVCValid) => {
  React.useMemo3(() => {
    let isCardDetailsEmpty = Js.String2.length(cvcNumber) == 0
    let isCardDetailsValid = isCvcValidValue == "valid"
    let isCardDetailsInvalid = isCvcValidValue == "invalid"
    (isCardDetailsEmpty, isCardDetailsValid, isCardDetailsInvalid)
  }, (cvcNumber, isCvcValidValue, isCVCValid))
}
