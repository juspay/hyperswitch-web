open Utils
let getKeyValue = (json, str) => {
  json
  ->Dict.get(str)
  ->Option.getOr(Dict.make()->JSON.Encode.object)
  ->JSON.Decode.string
  ->Option.getOr("")
}

@react.component
let make = () => {
  let (qrCode, setQrCode) = React.useState(_ => "")
  let (expiryTime, setExpiryTime) = React.useState(_ => 900000.0)
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (return_url, setReturnUrl) = React.useState(_ => "")
  let (clientSecret, setClientSecret) = React.useState(_ => "")
  let (headers, setHeaders) = React.useState(_ => [])
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(RecoilAtoms.switchToCustomPod)

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
        let qrData = metaDataDict->getString("qrData", "")
        setQrCode(_ => qrData)
        let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
        setClientSecret(_ => paymentIntentId)
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
        if timeExpiry > 0.0 && timeExpiry < 900000.0 {
          setExpiryTime(_ => timeExpiry)
        }
        open Promise
        setHeaders(_ => headers->Dict.toArray)
        PaymentHelpers.pollRetrievePaymentIntent(
          paymentIntentId,
          headers->Dict.toArray,
          ~optLogger=Some(logger),
          ~switchToCustomPod,
        )
        ->then(res => {
          Modal.close(setOpenModal)
          postSubmitResponse(~jsonData=res, ~url=return_url)
          resolve(res)
        })
        ->ignore
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })
  React.useEffect(() => {
    if expiryTime < 1000.0 {
      Modal.close(setOpenModal)
    }
    let intervalID = setInterval(() => {
      setExpiryTime(prev => prev -. 1000.0)
    }, 1000)
    Some(
      () => {
        clearInterval(intervalID)
      },
    )
  }, [expiryTime])

  let closeModal = () => {
    open Promise
    PaymentHelpers.retrievePaymentIntent(
      clientSecret,
      headers,
      ~optLogger=Some(logger),
      ~switchToCustomPod,
    )
    ->then(json => {
      let dict = json->JSON.Decode.object->Option.getOr(Dict.make())
      let status = dict->getString("status", "")

      if status === "succeeded" {
        postSubmitResponse(~jsonData=json, ~url=return_url)
      } else if status === "failed" {
        postFailedSubmitResponse(
          ~errortype="confirm_payment_failed",
          ~message="Payment failed. Try again!",
        )
      } else {
        postFailedSubmitResponse(
          ~errortype="sync_payment_failed",
          ~message="Payment is processing. Try again later!",
        )
      }
      resolve(json)
    })
    ->then(_json => {
      Modal.close(setOpenModal)
      resolve(Nullable.null)
    })
    ->catch(e => {
      Console.log2("Retrieve Failed", e)
      resolve(Nullable.null)
    })
    ->ignore
  }

  let expiryString = React.useMemo(() => {
    let minutes = (expiryTime /. 60000.0)->Float.toInt->Int.toString
    let seconds = mod(expiryTime->Float.toInt, 60000)->Int.toString->String.slice(~start=0, ~end=2)
    let seconds = seconds->String.length == 1 ? `${seconds}0` : seconds
    `${minutes}:${seconds}`
  }, [expiryTime])

  <Modal showClose=false openModal setOpenModal>
    <div className="flex flex-col h-full justify-between items-center">
      <div
        className=" flex flex-row w-full justify-center items-start mb-8 font-medium text-2xl font-semibold text-[#151A1F] opacity-50">
        {expiryString->React.string}
      </div>
      <img style={height: "13rem"} src=qrCode />
      <div className=" flex flex-col max-w-md justify-between items-center">
        <div className="Disclaimer w-full mt-16 font-medium text-xs text-[#151A1F] opacity-50">
          {React.string(
            " The QR Code is valid for the next 15 minutes, please do not close until you have successfully completed the payment, after which you will be automatically redirected. ",
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
                closeModal()
              }}>
              {React.string("Done")}
            </button>
          </div>
        </div>
      </div>
    </div>
  </Modal>
}
