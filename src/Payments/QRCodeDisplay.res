open Utils

let maxQRTime = 900000.0

type paymentMethod =
  | DuitNow
  | Other

type paymentMethodConfig = {
  defaultColor: string,
  showBorder: bool,
  footerText: string,
  showLogo: bool,
  color: string,
  logoName: string,
}

let getKeyValue = (json, str) => {
  json
  ->Dict.get(str)
  ->Option.getOr(Dict.make()->JSON.Encode.object)
  ->JSON.Decode.string
  ->Option.getOr("")
}

let parsePaymentMethod = methodString => {
  switch methodString {
  | "duit_now" => DuitNow
  | _ => Other
  }
}

let getPaymentMethodConfig = (method): paymentMethodConfig => {
  switch method {
  | DuitNow => {
      defaultColor: "#ED2E67",
      showBorder: true,
      footerText: "MALAYSIA NATIONAL QR",
      showLogo: true,
      color: "",
      logoName: "duitNow",
    }
  | Other => {
      defaultColor: "transparent",
      showBorder: false,
      footerText: "",
      showLogo: false,
      color: "",
      logoName: "",
    }
  }
}

@react.component
let make = () => {
  let (qrCode, setQrCode) = React.useState(_ => "")
  let (expiryTime, setExpiryTime) = React.useState(_ => maxQRTime)
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (return_url, setReturnUrl) = React.useState(_ => "")
  let (clientSecret, setClientSecret) = React.useState(_ => "")
  let (sdkAuthorization, setSdkAuthorization) = React.useState(_ => "")
  let (headers, setHeaders) = React.useState(_ => [])
  let (publishableKey, setPublishableKey) = React.useState(_ => "")
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)
  let (paymentMethodConfig, setPaymentMethodConfig) = React.useState(_ =>
    getPaymentMethodConfig(Other)
  )

  React.useEffect0(() => {
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let handleAsync = async () => {
        let json = ev.data->safeParse
        let dict = json->Utils.getDictFromJson
        if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
          let metadata = dict->getJsonObjectFromDict("metadata")
          let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())

          let paymentMethodStr = metaDataDict->getString("paymentMethod", "")
          let parsedPaymentMethod = parsePaymentMethod(paymentMethodStr)

          let defaultConfig = getPaymentMethodConfig(parsedPaymentMethod)

          let qrData = metaDataDict->getString("qrData", "")
          let publishableKey = metaDataDict->getString("publishableKey", "")
          setPublishableKey(_ => publishableKey)
          setQrCode(_ => qrData)

          switch parsedPaymentMethod {
          | Other => setPaymentMethodConfig(_ => defaultConfig)
          | _ => {
              let displayText = metaDataDict->getString("display_text", defaultConfig.footerText)
              let borderColor = metaDataDict->getString("border_color", defaultConfig.defaultColor)

              let displayText = displayText === "" ? defaultConfig.footerText : displayText
              let borderColor = borderColor === "" ? defaultConfig.defaultColor : borderColor
              let showBorder = displayText !== "" && borderColor !== ""

              setPaymentMethodConfig(_ => {
                ...defaultConfig,
                color: borderColor,
                showBorder,
                footerText: displayText,
              })
            }
          }

          let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
          setClientSecret(_ => paymentIntentId)
          let sdkAuthorizationVal = metaDataDict->getString("sdkAuthorization", "")
          setSdkAuthorization(_ => sdkAuthorizationVal)
          let headersDict =
            metaDataDict
            ->getJsonObjectFromDict("headers")
            ->JSON.Decode.object
            ->Option.getOr(Dict.make())
          let headers = Dict.make()
          setReturnUrl(_ => metadata->getDictFromJson->getString("url", ""))
          headersDict
          ->Dict.toArray
          ->Array.forEach(entries => {
            let (x, val) = entries
            Dict.set(headers, x, val->getStringFromJson(""))
          })
          let expiryTime =
            metaDataDict->getString("expiryTime", "")->Float.fromString->Option.getOr(0.0)
          let timeExpiry = expiryTime -. Date.now()
          if timeExpiry > 0.0 && timeExpiry < maxQRTime {
            setExpiryTime(_ => timeExpiry)
          }
          setHeaders(_ => headers->Dict.toArray)

          try {
            let res = await PaymentHelpers.pollRetrievePaymentIntent(
              ~headers=headers->Dict.toArray->Dict.fromArray,
              paymentIntentId,
              ~publishableKey,
              ~logger,
              ~customPodUri,
              ~sdkAuthorization=Some(sdkAuthorizationVal),
            )
            Modal.close(setOpenModal)
            postSubmitResponse(~jsonData=res, ~url=return_url)
          } catch {
          | error => Console.error2("Error while polling payment intent:", error)
          }
        }
      }
      handleAsync()->ignore
    }

    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  let closeModal = async () => {
    try {
      let json = await PaymentHelpers.retrievePaymentIntent(
        clientSecret,
        ~headers=headers->Dict.fromArray,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~sdkAuthorization=Some(sdkAuthorization),
      )

      postSubmitResponse(~jsonData=json, ~url=return_url)
      Modal.close(setOpenModal)
    } catch {
    | e => Console.error2("Retrieve Failed", e)
    }
  }

  React.useEffect(() => {
    if expiryTime < 1000.0 {
      closeModal()->ignore
    }

    let intervalID = setInterval(() => {
      setExpiryTime(prev => prev -. 1000.0)
    }, 1000)

    Some(() => clearInterval(intervalID))
  }, [expiryTime])

  let expiryString = React.useMemo(() => {
    let minutes = (expiryTime /. 60000.0)->Float.toInt->Int.toString
    let seconds = (mod(expiryTime->Float.toInt, 60000) / 1000)->Int.toString
    let formatedSeconds = seconds->String.length == 1 ? `0${seconds}` : seconds
    `${minutes}:${formatedSeconds}`
  }, [expiryTime])

  let displayColor = React.useMemo(() => {
    !isValidHexColor(paymentMethodConfig.color) || paymentMethodConfig.color === ""
      ? paymentMethodConfig.defaultColor
      : paymentMethodConfig.color
  }, [paymentMethodConfig.color, paymentMethodConfig.defaultColor])

  <Modal showClose=false openModal setOpenModal>
    <div className="flex flex-col h-full justify-between items-center">
      <RenderIf condition={paymentMethodConfig.showLogo && paymentMethodConfig.logoName !== ""}>
        <div className="flex flex-row w-full justify-center items-start mb-2">
          <Icon size=84 width=84 name={paymentMethodConfig.logoName} />
        </div>
      </RenderIf>
      <div
        className="flex flex-row w-full justify-center items-start mb-8 font-medium text-2xl font-semibold text-[#151A1F] opacity-50">
        {expiryString->React.string}
      </div>
      <div
        style={
          borderColor: paymentMethodConfig.showBorder ? displayColor : "transparent",
          backgroundColor: paymentMethodConfig.showBorder ? displayColor : "transparent",
        }
        className={paymentMethodConfig.showBorder ? "border-[1em] rounded-md" : ""}>
        <div
          className={paymentMethodConfig.showBorder
            ? "border-[0.5em] border-white rounded-md"
            : ""}>
          <img style={height: "13rem"} src=qrCode alt="" />
        </div>
        <RenderIf condition={paymentMethodConfig.footerText !== ""}>
          <div
            style={backgroundColor: displayColor}
            className="font-bold flex justify-center items-end text-[1em] text-white h-[2em]">
            <p> {paymentMethodConfig.footerText->React.string} </p>
          </div>
        </RenderIf>
      </div>
      <div className="flex flex-col max-w-md justify-between items-center">
        <div className="Disclaimer w-full mt-16 font-medium text-xs text-[#151A1F] opacity-50">
          {React.string(
            "The QR Code is valid for the next 15 minutes, please do not close until you have successfully completed the payment, after which you will be automatically redirected.",
          )}
        </div>
        <div className="button w-full">
          <div>
            <button
              className="w-full mt-6 p-2 h-[40px]"
              style={
                background: "#006DF9",
                borderRadius: "4px",
                color: "#ffffff",
              }
              onClick={_ => {
                closeModal()->ignore
              }}>
              {React.string("Done")}
            </button>
          </div>
        </div>
      </div>
    </div>
  </Modal>
}
