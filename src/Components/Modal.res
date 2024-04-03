let close = setOpenModal => {
  setOpenModal(_ => false)
  setTimeout(() => {
    Utils.handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
  }, 450)->ignore
}

@react.component
let make = (
  ~children,
  ~closeCallback=?,
  ~loader=false,
  ~showClose=true,
  ~testMode=true,
  ~setOpenModal,
  ~openModal,
) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let closeModal = () => {
    setOpenModal(_ => false)
    setTimeout(() => {
      switch closeCallback {
      | Some(fn) => fn()
      | None => ()
      }
      Utils.handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
    }, 450)->ignore
  }

  React.useEffect(() => {
    loader ? setOpenModal(_ => false) : setOpenModal(_ => true)
    None
  }, [loader])

  let loaderVisibility = loader ? "visible" : "hidden"
  let contentVisibility = React.useMemo(() => {
    !openModal ? "hidden" : "visible"
  }, [openModal])

  let marginTop = testMode ? "mt-8" : "mt-6"

  let animate = contentVisibility == "visible" ? "animate-zoomIn" : "animate-zoomOut"
  let loaderUI =
    <div className={`flex justify-center m-auto ${loaderVisibility}`}>
      <Loader showText=false />
    </div>
  <div
    className="h-screen w-screen bg-black/40 flex m-auto items-center backdrop-blur-sm overflow-scroll"
    style={ReactDOMStyle.make(
      ~transition="opacity .35s ease .1s,background-color 600ms linear",
      ~opacity=!openModal ? "0" : "100",
      (),
    )}>
    {loaderUI}
    {<div
      className={`w-full h-full sm:h-auto sm:w-[55%] md:w-[45%] lg:w-[35%] xl:w-[32%] 2xl:w-[27%]  m-auto bg-white flex flex-col justify-start sm:justify-center px-5 pb-5 md:pb-6 pt-4 md:pt-7 rounded-none sm:rounded-md relative overflow-scroll ${animate}`}
      style={ReactDOMStyle.make(
        ~transition="opacity .35s ease .1s,transform .35s ease .1s,-webkit-transform .35s ease .1s",
        ~opacity=!openModal ? "0" : "100",
        ~backgroundColor={
          themeObj.colorBackground === "transparent"
            ? ""
            : themeObj.colorBackground->Utils.rgbaTorgb
        },
        (),
      )}>
      <div className="absolute top-0 left-0 w-full flex flex-col">
        <RenderIf condition={testMode && !Window.isProd}>
          <div
            className="w-full h-6 text-[#885706] bg-[#FDD486] text-xs flex justify-center items-center font-semibold">
            {React.string("TEST DATA")}
          </div>
        </RenderIf>
        <RenderIf condition=showClose>
          <div
            className="p-4 flex justify-end self-end mb-4 cursor-pointer"
            onClick={_ => closeModal()}>
            <Icon name="cross" size=23 />
          </div>
        </RenderIf>
      </div>
      <div className={`mt-12 sm:${marginTop}`}> children </div>
    </div>}
  </div>
}
