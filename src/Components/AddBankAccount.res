open RecoilAtoms
open Utils
module ToolTip = {
  @react.component
  let make = (~openTip, ~forwardRef, ~onclick) => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
    <RenderIf condition={openTip}>
      <button
        className="h-auto max-w-20 w-auto cursor-pointer absolute m-1 px-1 py-2 top-[-3rem] right-[1em]"
        style={ReactDOMStyle.make(
          ~background=themeObj.colorBackground,
          ~color=themeObj.colorDanger,
          ~fontSize=themeObj.fontSizeBase,
          ~padding=`${themeObj.spacingUnit} ${themeObj.spacingUnit->Utils.addSize(
              7.0,
              Utils.Pixel,
            )}`,
          ~border=`1px solid ${themeObj.borderColor}`,
          ~borderRadius=themeObj.borderRadius,
          ~boxShadow=`0px 0px 8px ${themeObj.borderColor}`,
          (),
        )}
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
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let (openToolTip, setOpenToolTip) = React.useState(_ => false)
  let toolTipRef = React.useRef(Nullable.null)

  let openModal = () => {
    handlePostMessage([
      ("fullscreen", true->JSON.Encode.bool),
      ("iframeId", iframeId->JSON.Encode.string),
    ])
  }
  <div
    className={`PickerItem flex flex-row justify-between items-center ${isDataAvailable
        ? ""
        : "cursor-pointer"}`}
    style={ReactDOMStyle.make(
      ~marginTop=themeObj.spacingGridColumn,
      ~padding=themeObj.spacingUnit->addSize(11.0, Pixel),
      ~color={
        isDataAvailable ? themeObj.colorTextSecondary : themeObj.colorPrimary
      },
      (),
    )}
    onClick={_ => isDataAvailable ? () : openModal()}>
    {switch modalData {
    | Some(data: ACHTypes.data) =>
      let last4digts =
        data.iban !== ""
          ? data.iban->CardUtils.clearSpaces->String.sliceToEnd(~start=-4)
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
        <div
          className="PickerAction self-center w-auto cursor-pointer"
          onClick={_ => setOpenToolTip(_ => true)}>
          <Icon size=22 name="three-dots" />
        </div>
      </div>
    | None =>
      <>
        <div className="flex flex-row gap-4 animate-slowShow">
          <div>
            <Icon size=22 name="bank" />
          </div>
          <div> {React.string(localeString.addBankAccount)} </div>
        </div>
        <div className="PickerAction self-center">
          <Icon size=22 name="caret-right" />
        </div>
      </>
    }}
  </div>
}
