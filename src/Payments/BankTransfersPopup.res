open Utils
let getKeyValue = (json, str) => {
  json
  ->Dict.get(str)
  ->Option.getOr(Dict.make()->JSON.Encode.object)
  ->JSON.Decode.string
  ->Option.getOr("")
}

@react.component
let make = (~transferType) => {
  let (keys, setKeys) = React.useState(_ => [])
  let (json, setJson) = React.useState(_ => Dict.make())
  let (postData, setPostData) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (return_url, setReturnUrl) = React.useState(_ => "")
  let (responseType, title) = switch transferType {
  | "achBankTransfer" => ("ach_credit_transfer", "ACH")
  | "bacsBankTransfer" => ("bacs_bank_instructions", "BACS")
  | "sepaBankTransfer" => ("sepa_bank_instructions", "SEPA")
  | _ => ("", "")
  }

  let (isCopied, setIsCopied) = React.useState(_ => false)
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (buttonElement, text) = React.useMemo(() => {
    !isCopied
      ? (
          <>
            <Icon name="copyIcon" size=22 />
            {React.string("Copy")}
          </>,
          "text-[#006DF9]",
        )
      : (
          <>
            <Icon name="ticMark" size=22 />
            {React.string("Copied")}
          </>,
          "text-[#c0c0c0] font-medium ",
        )
  }, [isCopied])
  let handleClick = keys => {
    let text =
      keys
      ->Array.map(item => `${item->snakeToTitleCase} : ${getKeyValue(json, item)}`)
      ->Array.joinWith(`\n`)
    handlePostMessage([("copy", true->JSON.Encode.bool), ("copyDetails", text->JSON.Encode.string)])
    setIsCopied(_ => true)
  }
  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let dictMetadata =
          dict
          ->getJsonObjectFromDict("metadata")
          ->getDictFromJson
          ->Dict.get(responseType)
          ->Option.getOr(Dict.make()->JSON.Encode.object)
          ->getDictFromJson
        setKeys(_ => dictMetadata->Dict.keysToArray)
        setJson(_ => dictMetadata)
        setPostData(_ => metadata->getDictFromJson->getJsonObjectFromDict("data"))
        setReturnUrl(_ => metadata->getDictFromJson->getString("url", ""))
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })
  <Modal showClose=false openModal setOpenModal>
    <div className="flex flex-col h-full justify-between items-center">
      <div className="flex flex-col w-full mt-4 max-w-md justify-between items-center">
        <div className="PopupIcon m-1 p-2">
          <Icon name="ach-transfer" size=45 />
        </div>
        <div className="Popuptitle flex w-[90%] justify-center">
          <span className="font-bold text-lg"> {React.string(`${title} bank transfer`)} </span>
        </div>
        <div className="PopupSubtitle w-[90%] text-center">
          <span className="font-medium text-sm text-[#151A1F] opacity-50">
            {React.string("Use these details to transfer amount")}
          </span>
        </div>
        <div
          className="DetailsSection w-full m-8 text-center"
          style={ReactDOMStyle.make(
            ~background="rgba(21, 26, 31, 0.03)",
            ~border="1px solid rgba(21, 26, 31, 0.06)",
            ~borderRadius="5px",
            (),
          )}>
          <div
            className="flex font-medium p-5 justify-between text-sm"
            style={ReactDOMStyle.make(~borderBottom="1px dashed rgba(21, 26, 31, 0.06)", ())}>
            <span className="text-[#151a1fe6]"> {React.string("Bank Account Details")} </span>
            <button
              className={`flex flex-row ${text} cursor-pointer`} onClick={_ => handleClick(keys)}>
              {buttonElement}
            </button>
          </div>
          <div className="Details pt-5">
            {keys
            ->Array.map(item =>
              <div className="flex px-5 pb-5 justify-between text-sm">
                <div>
                  <span className="text-[#151A1F] font-medium opacity-60">
                    {React.string(`${item->snakeToTitleCase} : `)}
                  </span>
                  <span className="text-[#151A1F] font-semibold opacity-80">
                    {React.string(getKeyValue(json, item))}
                  </span>
                </div>
              </div>
            )
            ->React.array}
          </div>
        </div>
      </div>
      <div className=" flex flex-col max-w-md justify-between items-center">
        <div className="Disclaimer w-full mt-16 font-medium text-xs text-[#151A1F] opacity-50">
          {React.string(
            " Please make a note of these details, before closing this popup. You will not be able to generate this details again. ",
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
                postSubmitResponse(~jsonData=postData, ~url=return_url)
                Modal.close(setOpenModal)
              }}>
              {React.string("Done")}
            </button>
          </div>
        </div>
      </div>
    </div>
  </Modal>
}
