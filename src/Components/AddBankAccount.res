open RecoilAtoms
open Utils
module ToolTip = {
  @react.component
  let make = (~openTip, ~forwardRef, ~onclick) => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
    <RenderIf condition={openTip}>
      <button
        className="h-auto max-w-30 w-auto cursor-pointer absolute m-1 px-1 py-2 top-[-3rem] right-[1em]"
        style={
          background: themeObj.colorBackground,
          color: themeObj.colorDanger,
          fontSize: themeObj.fontSizeBase,
          padding: `${themeObj.spacingUnit} ${themeObj.spacingUnit->Utils.addSize(
              7.0,
              Utils.Pixel,
            )}`,
          border: `1px solid ${themeObj.borderColor}`,
          borderRadius: themeObj.borderRadius,
          boxShadow: `0px 0px 8px ${themeObj.borderColor}`,
        }
        onClick={ev => onclick(ev)}
        ref={forwardRef->ReactDOM.Ref.domRef}>
        {React.string("Remove account")}
      </button>
    </RenderIf>
  }
}

@react.component
let make = (~modalData, ~setModalData) => {
  let isDataAvailable = modalData->Option.isSome
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let (openToolTip, setOpenToolTip) = React.useState(_ => false)
  let toolTipRef = React.useRef(Nullable.null)
  let triggerRef = React.useRef(Nullable.null)

  let openModal = () => {
    let metaData = [("config", config->Identity.anyTypeToJson)]->getJsonFromArrayOfJson

    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("iframeId", iframeId->JSON.Encode.string),
      ("metadata", metaData),
    ])
  }

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      try {
        let dict = ev.data->safeParse->getDictFromJson
        switch dict->Dict.get("fullScreenIframeMounted")->Option.flatMap(JSON.Decode.bool) {
        | Some(false) =>
          triggerRef.current->Nullable.toOption->Option.forEach(el => el->AccessibilityUtils.focus)
        | _ => ()
        }
      } catch {
      | _ => ()
      }
    }
    Window.addEventListener("message", handle)
    Some(() => Window.removeEventListener("message", handle))
  }, [])

  let triggerTabIndex = isDataAvailable ? -1 : 0

  <div
    ref={triggerRef->ReactDOM.Ref.domRef}
    className={`PickerItem flex flex-row justify-between items-center ${isDataAvailable
        ? ""
        : "cursor-pointer"}`}
    style={
      marginTop: themeObj.spacingGridColumn,
      padding: themeObj.spacingUnit->addSize(11.0, Pixel),
      color: {
        isDataAvailable ? themeObj.colorTextSecondary : themeObj.colorPrimary
      },
    }
    tabIndex=triggerTabIndex
    role=?{isDataAvailable ? None : Some("button")}
    ariaLabel=?{isDataAvailable ? None : Some(localeString.addBankAccount)}
    onClick=?{isDataAvailable ? None : Some(_ => openModal())}
    onKeyDown=?{isDataAvailable
      ? None
      : Some(AccessibilityUtils.onActivateKeyDown(~onActivate=() => openModal()))}>
    {switch modalData {
    | Some(data: ACHTypes.data) =>
      let last4digts =
        data.iban !== ""
          ? data.iban->CardValidations.clearSpaces->String.sliceToEnd(~start=-4)
          : data.accountNumber->String.sliceToEnd(~start=-4)

      <div className="flex flex-row justify-between w-full relative animate-slowShow">
        <div className="flex flex-row gap-4">
          <div>
            <Icon size=22 name="bank" />
          </div>
          <div className="tracking-wider"> {React.string(`Bank  **** ${last4digts}`)} </div>
        </div>
        <ToolTip
          openTip=openToolTip forwardRef=toolTipRef onclick={_ => {setModalData(_ => None)}}
        />
        <button
          type_="button"
          ariaLabel={localeString.openBankAccountOptionsLabel}
          className="PickerAction self-center w-auto cursor-pointer bg-transparent border-none p-0 inline-flex"
          onClick={event => {
            ReactEvent.Mouse.stopPropagation(event)
            setOpenToolTip(_ => true)
          }}>
          <Icon size=22 name="three-dots" />
        </button>
      </div>
    | None =>
      <>
        <div className="flex flex-row gap-4 animate-slowShow">
          <div>
            <Icon size=22 name="bank" />
          </div>
          <div ariaHidden=true> {React.string(localeString.addBankAccount)} </div>
        </div>
        <div className="PickerAction self-center">
          <Icon size=22 name="caret-right" />
        </div>
      </>
    }}
  </div>
}
