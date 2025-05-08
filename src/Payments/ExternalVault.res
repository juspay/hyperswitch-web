// VGSCollect.res
open Utils
type value = {color: string}
type value2 = {
  position: string,
  right: string,
  top: string,
  transform: string,
  height: string, // optional: shrink icon if needed
  width: string, // optional
  display: string, // ensures it's shown properly
  pointerEvents: string, // prevents clicking the icon
}
// type iframetype = {width: string}

type styleField = {width: string}
let styleValue = {width: "100%"}
type cssType = {
  display: string,
  boxSizing: string,
  width: string,
  fontFamily: string,
  color: string,
  \"&::placeholder": value,
  fontSize: string,
  padding: string,
  paddingRight: string,
  height: string,
  lineHeight: string,
  // display: string,
  // alignItems: string,
  \"::vgs-collect-field-icon": value2,
  iframe: styleField,
}

let cssValue = {
  display: "inline-block",
  boxSizing: "border-box",
  width: "100%",
  fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI",
  color: "#000000",
  \"&::placeholder": {
    color: "#bcbcbc",
  },
  fontSize: "16px",
  padding: "10px",
  paddingRight: "6px",
  height: "62px", // equivalent to h-16 in Tailwind
  lineHeight: "1.5rem",
  // display: "flex",
  // alignItems: "center",
  \"::vgs-collect-field-icon": {
    position: "absolute",
    right: "12px",
    top: "50%",
    transform: "translateY(-50%)",
    height: "24px", // optional: shrink icon if needed
    width: "40px", // optional
    display: "block", // ensures it's shown properly
    pointerEvents: "none", // prevents clicking the icon
  },
  iframe: styleValue,
}

// type cssType = {
//   color: string,
//   border: string,
//   \"border-radius": string,
//   //   background: string,
// }
type cardBrandInfo = {
  \"type": string,
  pattern: RescriptCore.Re.t,
  format?: RescriptCore.Re.t,
  length?: array<int>,
  cvcLength?: array<int>,
  luhn?: bool,
  useExtendedBin?: bool,
}

type fieldOptions = {
  \"type": string,
  name: string,
  placeholder: string,
  validations: array<string>,
  errorColor: string,
  showCardIcon?: bool,
  addCardBrands?: array<cardBrandInfo>,
  css: cssType,
  style: styleField,
}

type returnValue = {
  field: (string, fieldOptions) => unit,
  submit: (string, JSON.t, (int, JSON.t) => unit, JSON.t => unit) => unit,
}

type vGSForm
@send
external field: (string, fieldOptions) => unit = "field"
@val
external create: (string, string, JSON.t => unit) => returnValue = "VGSCollect.create"

// Define error state type
type errorInfo = {
  message: string,
  details: JSON.t,
  description: string,
  code: int,
}
type errorField = {
  errorMessages: array<string>,
  isDirty: bool,
  isEmpty: bool,
  isFocused: bool,
  isValid: bool,
  isTouched: bool,
  errors: array<errorInfo>,
  name: string,
}

type cardNumberField = {
  ...errorField,
  cardType: option<string>,
  last4: option<string>,
  bin: option<string>,
}

type formErrors = {
  card_holder?: errorField,
  card_number?: errorField,
  card_exp?: errorField,
  card_cvc?: errorField,
}

let cardBrandPatterns = CardPattern.cardPatterns->Array.map(obj => {
  let cardBrandName = obj.issuer->String.toLowerCase
  let formatterCardName = cardBrandName == "americanexpress" ? "amex" : cardBrandName
  let pattern = obj.pattern
  let length = obj.length
  let cvcLength = obj.cvcLength
  {\"type": formatterCardName, pattern, length, cvcLength}
})

@react.component
let make = () => {
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let supportedCardBrands = React.useMemo(() => {
    paymentMethodListValue->PaymentUtils.getSupportedCardBrands
  }, [paymentMethodListValue])
  Js.log2("Supported Card Brands:", supportedCardBrands)
  let (vgsScriptLoaded, setVgsScriptLoaded) = React.useState(() => false)
  let vaultRef = React.useRef(Nullable.null)
  let (formErrors, setFormErrors) = React.useState(() => Js.Dict.empty()->Obj.magic)
  let (currentCardBrand, setCurrentCardBrand) = React.useState(() => None)
  // let (customErrors, setCustomErrors) = React.useState(() => Js.Dict.empty()->Obj.magic)
  //   let (loggerState, _setLoggerState) = Recoil.useRecoilState(RecoilAtoms.loggerAtom)

  //   UtilityHooks.useHandlePostMessages(
  //     ~complete=isCompleted,
  //     ~empty=!isCompleted,
  //     ~paymentType="paypal",
  //   )

  let mountVGSSDK = () => {
    // let clientId = sessionObj.token
    let vgsScriptURL = `https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js`
    // loggerState.setLogInfo(~value="PayPal SDK Script Loading", ~eventName=PAYPAL_SDK_FLOW)
    let vgsScript = Window.createElement("script")
    vgsScript->Window.setAttribute(
      "integrity",
      "sha384-ddxU1XAc77oB4EIpKOgJQ3FN2a6STYPK0JipRqg1x/eW+n5MFn1XbbZa7+KRjkqc",
    )
    vgsScript->Window.setAttribute("type", "text/javascript")
    vgsScript->Window.setAttribute("crossorigin", "anonymous")
    vgsScript->Window.elementSrc(vgsScriptURL)
    vgsScript->Window.elementOnerror(exn => {
      Console.log2("Error in oading script==>", exn)
    })
    vgsScript->Window.elementOnload(_ => {
      setVgsScriptLoaded(_ => true)
      Console.log("VGS Script Loaded")
    })
    Window.body->Window.appendChild(vgsScript)
  }

  let getErrorMessage = fieldName => {
    switch Js.Dict.get(formErrors, fieldName) {
    | Some(field) if field.errorMessages->Array.length > 0 => Some(field.errorMessages[0])
    | _ => None
    }
  }

  let hasError = fieldName => {
    switch Js.Dict.get(formErrors, fieldName) {
    | Some(_) => true
    | None => false
    }
  }

  let handleFieldState = state => {
    Js.log2("VGS field state:", state)

    // Extract card type if available
    switch Js.Dict.get(state->Utils.getDictFromJson, "card_number")->Obj.magic {
    | Some(cardField) =>
      switch cardField.cardType {
      | Some(cardType) => setCurrentCardBrand(_ => Some(cardType))
      // Clear any custom error if the card brand changes
      // let newErrors = Dict.copy(customErrors)
      // newErrors->Js.Dict.set("card_number", None)
      // setCustomErrors(_ => newErrors)
      | _ => setCurrentCardBrand(_ => None)
      }
    | None => ()
    }
  }

  React.useEffect(() => {
    if vgsScriptLoaded {
      let vault = create("tnt6amq0tzx", "sandbox", state => {
        handleFieldState(state)
        ()
      })

      // Console.log2("This is vault==>", vault)
      vaultRef.current = Js.Nullable.return(vault)
      vault.field(
        "#cc-name",
        {
          \"type": "text",
          placeholder: "Joe Business",
          validations: ["required"],
          name: "card_holder",
          errorColor: "#D8000C",
          // css: {
          //   color: "red",
          //   border: "solid 1px #1b1d1f",
          //   \"border-radius": "5px",
          //   // background: "blue",
          // },
          css: cssValue,
          style: styleValue,
        },
      )
      vault.field(
        "#cc-number",
        {
          \"type": "card-number",
          name: "card_number",
          placeholder: "4111 1111 1111 1111",
          validations: ["required", "validCardNumber"],
          errorColor: "#D8000C",
          showCardIcon: true,
          addCardBrands: cardBrandPatterns,
          // css: {
          //   color: "#31708f",
          //   border: "solid 1px #1b1d1f",
          //   \"border-radius": "5px",
          //   // background: "green",
          //   // "line-height": "1.5rem",
          //   // "font-size": "24px",
          // },
          css: cssValue,
          style: styleValue,
        },
      )
      vault.field(
        "#cc-expiry",
        {
          \"type": "card-expiration-date",
          name: "card_exp",
          placeholder: "MM / YY",
          validations: ["required", "validCardExpirationDate"],
          errorColor: "#D8000C",
          // css: {
          //   color: "#31708f",
          //   border: "solid 1px #1b1d1f",
          //   \"border-radius": "5px",
          //   // background: "green",
          //   // "line-height": "1.5rem",
          //   // "font-size": "24px",
          // },
          css: cssValue,
          style: styleValue,
        },
      )
      vault.field(
        "#cc-cvc",
        {
          \"type": "card-security-code",
          name: "card_cvc",
          placeholder: "123",
          validations: ["required", "validCardSecurityCode"],
          errorColor: "#D8000C",
          showCardIcon: true,
          // css: {
          //   color: "#31708f",
          //   border: "solid 1px #1b1d1f",
          //   \"border-radius": "5px",
          //   // background: "green",
          //   // "line-height": "1.5rem",
          //   // "font-size": "24px",
          // },
          css: cssValue,
          style: styleValue,
        },
      )
    }
    None
  }, [vgsScriptLoaded])

  mountVGSSDK()

  let vgsCardTypeMapper = str => {
    switch str {
    | "amex" => "americanexpress"
    | _ => str
    }
  }

  let isCardBrandSupported = React.useCallback(() => {
    switch currentCardBrand {
    | Some(brand) =>
      // Check if the brand is in the supported list
      supportedCardBrands
      ->Option.getOr([])
      ->Array.some(supportedBrand =>
        supportedBrand->String.toLowerCase == brand->vgsCardTypeMapper->String.toLowerCase
      )
    | None => true // If no brand detected yet, don't block submission
    }
  }, (currentCardBrand, supportedCardBrands))

  let submitCallback = React.useCallback((ev: Window.event) => {
    // ev->ReactEvent.Keyboard.preventDefault
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    // if !isCardBrandSupported() {
    //   // Set a custom error for unsupported card brand
    //   let newErrors = Dict.copy(customErrors)
    //   let errorMessage = switch currentCardBrand {
    //   | Some(brand) => `Card brand "${brand}" is not supported`
    //   | None => "Card brand not detected"
    //   }
    //   newErrors->Js.Dict.set("card_number", Some(errorMessage))
    //   setCustomErrors(_ => newErrors)
    //   // postFailedSubmitResponse(
    //   //   ~errortype="validation_error",
    //   //   ~message="Please fill supported card brand",
    //   // )
    // } else {
    //   setCustomErrors(_ => Js.Dict.empty())
    if confirm.doSubmit {
      // Console.log2("coming here", ev)
      switch Window.window
      ->Window.document
      ->Window.getElementById("vgs-collect-form")
      ->Nullable.toOption {
      | Some(_) =>
        // Assuming `form` is a JS object available globally (e.g. via script tag)
        // and has a `submit` method like `form.submit("/post", {}, cb)`
        // %raw(`
        // let vault = create("tnt6amq0tzx", "sandbox", state => {Js.log2("VGS field state:", state)})
        // vault.submit("/post", "{}"->Identity.anyTypeToJson, (status, data) => {
        //   Console.log2("This is==>", data)
        //   // document.getElementById("result").innerHTML = JSON.stringify(data, null, 4)
        // })

        switch Js.Nullable.toOption(vaultRef.current) {
        | Some(vault) =>
          // if !isCardBrandSupported() {
          //   setFormErrors(_ => Js.Dict.empty()->Obj.magic)
          //   postFailedSubmitResponse(
          //     ~errortype="validation_error",
          //     ~message=`Card brand ${currentCardBrand->Option.getOr("")} not supported`,
          //   )
          // } else {
          vault.submit(
            "/post",
            "{}"->Identity.anyTypeToJson,
            (status, data) => {
              Js.Console.log2("Status =>", status)
              if status == 200 {
                Console.log2("Tokenized Data =>", data)
                Console.log("Success")

                setFormErrors(_ => Js.Dict.empty()->Obj.magic)
              }

              // set
            },
            error => {
              Console.log2("Error =>", error)
              postFailedSubmitResponse(
                ~errortype="validation_error",
                ~message="Please enter all fields",
              )
              setFormErrors(_ => error->Utils.getDictFromJson->Obj.magic)
              // set
            },
          )
        // }

        | None => Js.Console.error("Vault not initialized")
        }
      // `)
      | None => Js.Console.error("Form not found")
      }
    }
    // }
  }, ())

  useSubmitPaymentData(submitCallback)

  let getFieldClasses = fieldName => {
    let baseClasses = "w-full h-16 relative mb-1 rounded px-[10px] border bg-white overflow-hidden form-field-vgs"
    hasError(fieldName)
      ? baseClasses ++ " border-red-500"
      : baseClasses ++ " shadow-[0_0_3px_0px_#bcbcbc] border-transparent"
  }

  <form id="vgs-collect-form">
    <div className="mb-4">
      <label className="block mb-1"> {"Name on card"->React.string} </label>
      <div id="cc-name" className={getFieldClasses("card_holder")} />
      {switch getErrorMessage("card_holder") {
      | Some(errorMsg) =>
        <p className="text-red-500 text-sm mt-1"> {errorMsg->Option.getOr("")->React.string} </p>
      | None => React.null
      }}
    </div>
    <div className="mb-4">
      <label className="block mb-1"> {"Card number"->React.string} </label>
      <div
        id="cc-number"
        className={getFieldClasses("card_number")}
        style={
          display: "flex",
          width: "100%",
        }
      />
      {switch getErrorMessage("card_number") {
      | Some(errorMsg) =>
        <p className="text-red-500 text-sm mt-1"> {errorMsg->Option.getOr("")->React.string} </p>
      | None => React.null
      }}
    </div>
    <div className="flex flex-row w-full place-content-between mb-6">
      <div className="w-[47%]">
        <label className="block mb-1"> {"Exp. Date"->React.string} </label>
        <div id="cc-expiry" className={getFieldClasses("card_exp")} />
        {switch getErrorMessage("card_exp") {
        | Some(errorMsg) =>
          <p className="text-red-500 text-sm mt-1"> {errorMsg->Option.getOr("")->React.string} </p>
        | None => React.null
        }}
      </div>
      <div className="w-[47%]">
        <label className="block mb-1"> {"CVV/CVC"->React.string} </label>
        <div id="cc-cvc" className={getFieldClasses("card_cvc")} style={display: "flex"} />
        {switch getErrorMessage("card_cvc") {
        | Some(errorMsg) =>
          <p className="text-red-500 text-sm mt-1"> {errorMsg->Option.getOr("")->React.string} </p>
        | None => React.null
        }}
      </div>
    </div>

    // <button type_="submit"> {"Test your form"->React.string} </button>
  </form>
}

let default = make
