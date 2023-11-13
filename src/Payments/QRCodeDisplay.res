open Utils
let getKeyValue = (json, str) => {
  json
  ->Js.Dict.get(str)
  ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
  ->Js.Json.decodeString
  ->Belt.Option.getWithDefault("")
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
    handlePostMessage([("iframeMountedCallback", true->Js.Json.boolean)])
    let handle = (ev: Window.event) => {
      let json = ev.data->Js.Json.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Js.Dict.get("fullScreenIframeMounted")->Belt.Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict =
          metadata->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
        let qrData = metaDataDict->getString("qrData", "")
        setQrCode(_ => qrData)
        let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
        setClientSecret(_ => paymentIntentId)
        let headersDict =
          metaDataDict
          ->getJsonObjectFromDict("headers")
          ->Js.Json.decodeObject
          ->Belt.Option.getWithDefault(Js.Dict.empty())
        let headers = Js.Dict.empty()
        setReturnUrl(_ => metadata->getDictFromJson->getString("url", ""))
        headersDict
        ->Js.Dict.entries
        ->Js.Array2.forEach(entries => {
          let (x, val) = entries
          Js.Dict.set(headers, x, val->Js.Json.decodeString->Belt.Option.getWithDefault(""))
        })
        let _timeExpiry = metaDataDict->getString("expiryTime", "")
        open Promise
        setHeaders(_ => headers->Js.Dict.entries)
        PaymentHelpers.pollRetrievePaymentIntent(
          paymentIntentId,
          headers->Js.Dict.entries,
          ~optLogger=Some(logger),
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
  React.useEffect1(() => {
    if expiryTime < 1000.0 {
      Modal.close(setOpenModal)
    }
    let intervalID = Js.Global.setInterval(() => {
      setExpiryTime(prev => prev -. 1000.0)
    }, 1000)
    Some(
      () => {
        Js.Global.clearInterval(intervalID)
      },
    )
  }, [expiryTime])

  let closeModal = () => {
    open Promise
    PaymentHelpers.retrievePaymentIntent(clientSecret, headers, ~optLogger=Some(logger))
    ->then(json => {
      let dict = json->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
      let status = dict->getString("status", "")

      if status === "succeeded" {
        postSubmitResponse(~jsonData=json, ~url=return_url)
      } else {
        postFailedSubmitResponse(
          ~errortype="confirm_payment_failed",
          ~message="Payment failed. Try again!",
        )
      }
      resolve(json)
    })
    ->then(_json => {
      Modal.close(setOpenModal)
      resolve(Js.Nullable.null)
    })
    ->catch(e => {
      Js.log2("Retrieve Failed", e)
      resolve(Js.Nullable.null)
    })
    ->ignore
  }

  let expiryString = React.useMemo1(() => {
    let minutes = (expiryTime /. 60000.0)->Belt.Float.toInt->Belt.Int.toString
    let seconds =
      mod(expiryTime->Belt.Float.toInt, 60000)->Belt.Int.toString->Js.String2.slice(~from=0, ~to_=2)
    let seconds = seconds->Js.String2.length == 1 ? `${seconds}0` : seconds
    `${minutes}:${seconds}`
  }, [expiryTime])

  <Modal showClose=false openModal setOpenModal>
    <div className="flex flex-col h-full justify-between items-center">
      <div
        className=" flex flex-row w-full justify-center items-start mb-8 font-medium text-2xl font-semibold text-[#151A1F] opacity-50">
        {expiryString->React.string}
      </div>
      <img style={ReactDOMStyle.make(~height="8rem", ())} src=qrCode />
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
              style={ReactDOMStyle.make(
                ~background="#006DF9",
                ~borderRadius="4px",
                ~color="#ffffff",
                (),
              )}
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
