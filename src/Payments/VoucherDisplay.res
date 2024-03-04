open Utils
@react.component
let make = () => {
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (returnUrl, setReturnUrl) = React.useState(_ => "")
  let (downloadUrl, setDownloadUrl) = React.useState(_ => "")
  let (reference, setReference) = React.useState(_ => "")
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let (downloadCounter, setDownloadCounter) = React.useState(_ => 0)
  let (paymentMethod, setPaymentMethod) = React.useState(_ => "")
  let (paymentIntent, setPaymentIntent) = React.useState(_ => Js.Json.null)
  let (loader, setLoader) = React.useState(_ => true)
  let linkRef = React.useRef(Js.Nullable.null)

  React.useEffect1(() => {
    switch linkRef.current->Js.Nullable.toOption {
    | Some(link) => link->Window.click
    | None => ()
    }
    None
  }, [loader])

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->Js.Json.boolean)])
    let handle = (ev: Window.event) => {
      let json = ev.data->Js.Json.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Js.Dict.get("fullScreenIframeMounted")->Belt.Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict =
          metadata->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
        setReturnUrl(_ => metaDataDict->getString("returnUrl", ""))
        setDownloadUrl(_ => metaDataDict->getString("voucherUrl", ""))
        setReference(_ => metaDataDict->getString("reference", ""))
        setPaymentMethod(_ => metaDataDict->getString("paymentMethod", ""))
        setPaymentIntent(_ => metaDataDict->getJsonObjectFromDict("payment_intent_data"))
        setLoader(_ => false)
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  let closeModal = () => {
    postSubmitResponse(~jsonData=paymentIntent, ~url=returnUrl)
    Modal.close(setOpenModal)
  }

  <Modal showClose=false openModal setOpenModal loader>
    <div className="flex flex-col h-full justify-between items-center">
      <div className="flex flex-col max-w-md justify-between items-center">
        <div className="flex flex-row w-full">
          <p className="Disclaimer font-medium text-sm text-[#151A1F] opacity-70">
            {React.string(
              `${paymentMethod->snakeToTitleCase} voucher was successfully generated! If the document hasn't started downloading automatically, click `,
            )}
            <a
              className="text font-medium text-sm text-[#006DF9] underline"
              href=downloadUrl
              ref={linkRef->ReactDOM.Ref.domRef}
              onClick={_ => {
                setDownloadCounter(c => c + 1)
                LoggerUtils.handleLogging(
                  ~optLogger=Some(logger),
                  ~value=downloadCounter->Js.Int.toString,
                  ~eventName=DISPLAY_VOUCHER,
                  ~paymentMethod,
                  (),
                )
              }}>
              {React.string("here")}
            </a>
            {React.string(" to download it.")}
          </p>
        </div>
        <div className="flex flex-row mt-4 w-full">
          <p className="Disclaimer font-medium text-sm text-[#151A1F] opacity-70">
            {React.string("Bar Code Reference: ")}
            <span className="Disclaimer font-bold text-sm text-[#151A1F] opacity-90">
              {React.string(reference)}
            </span>
          </p>
        </div>
        <div className="Disclaimer w-full mt-16 font-medium text-xs text-[#151A1F] opacity-50">
          {React.string(
            "Please do not close until you have successfully downloaded the voucher, after which you will be automatically redirected.",
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
