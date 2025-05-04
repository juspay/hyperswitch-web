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
let styleValue = {width: "200%"}
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
  width: "200%",
  fontFamily: "-apple-system, BlinkMacSystemFont, Segoe UI",
  color: "#000000",
  \"&::placeholder": {
    color: "#bcbcbc",
  },
  fontSize: "16px",
  padding: "10px",
  paddingRight: "6px",
  height: "64px", // equivalent to h-16 in Tailwind
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
type fieldOptions = {
  \"type": string,
  name: string,
  placeholder: string,
  validations: array<string>,
  showCardIcon?: bool,
  css: cssType,
  style: styleField,
}
type returnValue = {
  field: (string, fieldOptions) => unit,
  submit: (string, JSON.t, (JSON.t, JSON.t) => unit) => unit,
}
type formState
type vGSForm
@send
external field: (string, fieldOptions) => unit = "field"
@val
external create: (string, string, formState => unit) => returnValue = "VGSCollect.create"

@react.component
let make = () => {
  let (vgsScriptLoaded, setVgsScriptLoaded) = React.useState(() => false)
  let vaultRef = React.useRef(Nullable.null)
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
  React.useEffect(() => {
    if vgsScriptLoaded {
      let vault = create("tnt6amq0tzx", "sandbox", state => {
        // Js.log2("VGS field state:", state)()
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
      vault.field(
        "#cc-expiry",
        {
          \"type": "card-expiration-date",
          name: "card_exp",
          placeholder: "MM / YY",
          validations: ["required", "validCardExpirationDate"],
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
          // showCardIcon: true,
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
  let submitCallback = React.useCallback((ev: Window.event) => {
    // ev->ReactEvent.Keyboard.preventDefault
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
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
          vault.submit("/post", "{}"->Identity.anyTypeToJson, (status, data) => {
            Console.log2("Tokenized Data =>", data)
            // set
          })
        | None => Js.Console.error("Vault not initialized")
        }
      // `)
      | None => Js.Console.error("Form not found")
      }
    }
  }, ())
  useSubmitPaymentData(submitCallback)
  <form id="vgs-collect-form">
    <label> {"Name on card"->React.string} </label>
    <div
      id="cc-name"
      className={`w-full h-16 relative mb-6 rounded shadow-[0_0_3px_0px_#bcbcbc] px-[10px] border border-transparent bg-white`}
    />
    <label> {"Card number"->React.string} </label>
    <div
      id="cc-number"
      className={`w-full h-16 relative mb-6 rounded shadow-[0_0_3px_0px_#bcbcbc] px-[10px] border border-transparent bg-white`}
      style={
        display: "flex",
        width: "100%",
      }
    />
    <div className="flex flex-row w-full place-content-between">
      <div className="w-[47%]">
        <label> {"Exp. Date"->React.string} </label>
        <div
          id="cc-expiry"
          className="w-full h-16 relative mb-6 rounded shadow-[0_0_3px_0px_#bcbcbc] px-[10px] border border-transparent bg-white"
        />
      </div>
      <div className="w-[47%]">
        <label> {"CVV/CVC"->React.string} </label>
        <div
          id="cc-cvc"
          className="w-full h-16 relative mb-6 rounded shadow-[0_0_3px_0px_#bcbcbc] px-[10px] border border-transparent bg-white"
          style={display: "flex"}
        />
      </div>
    </div>
    // <button type_="submit"> {"Test your form"->React.string} </button>
  </form>
}

let default = make
