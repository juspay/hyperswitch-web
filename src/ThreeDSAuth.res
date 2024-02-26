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

  let (clientSecret, setClientSecret) = React.useState(_ => "")
  let (headers, setHeaders) = React.useState(_ => [])
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(RecoilAtoms.switchToCustomPod)
  let (frameStyle, setFrameStyle) = React.useState(() => "")

  let closeModal = () => {
    Modal.close(setOpenModal)
  }

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->Js.Json.boolean)])
    let handle = (ev: Window.event) => {
      let json = ev.data->Js.Json.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Js.Dict.get("fullScreenIframeMounted")->Belt.Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict =
          metadata->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
        let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
        let headersDict =
          metaDataDict
          ->getJsonObjectFromDict("headers")
          ->Js.Json.decodeObject
          ->Belt.Option.getWithDefault(Js.Dict.empty())

        let headers =
          headersDict
          ->Js.Dict.entries
          ->Js.Array2.map(entries => {
            let (x, val) = entries
            (x, val->Js.Json.decodeString->Belt.Option.getWithDefault(""))
          })

        setClientSecret(_ => paymentIntentId)

        open Promise

        PaymentHelpers.threeDsAuth(~optLogger=Some(logger), ~clientSecret=paymentIntentId, ~headers)
        ->then(json => {
          let dict = json->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
          let creq = dict->getString("challenge_request", "")
          let transStatus = dict->getString("trans_status", "Y")
          let acsUrl = dict->getString("acs_url", "")

          let ele = Window.querySelector("#threeDsAuthDiv")
          if transStatus === "C" {
            Js.log2("INSIDE", ele)
            switch ele->Js.Nullable.toOption {
            | Some(elem) => {
                let form = elem->OrcaUtils.makeForm(acsUrl)
                let input = Types.createElement("input")
                input.name = "creq"
                input.value = creq
                form.target = "threeDsAuthFrame"
                form.appendChild(. input)
                form.submit(.)
              }
            | None => ()
            }
          } else {
            ()
          }
          resolve(json)
        })
        ->ignore
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  //   let loaderString = () => {
  //     let outerStyle = `    -webkit-text-size-adjust: 100%;
  //     tab-size: 4;
  //     font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
  //     font-feature-settings: normal;
  //     font-variation-settings: normal;
  //     line-height: inherit;
  //     --tw-bg-opacity: 1;
  //     box-sizing: border-box;
  //     border-width: 0;
  //     border-style: solid;
  //     border-color: #e5e7eb;
  //     --tw-border-spacing-x: 0;
  //     --tw-border-spacing-y: 0;
  //     --tw-translate-x: 0;
  //     --tw-translate-y: 0;
  //     --tw-rotate: 0;
  //     --tw-skew-x: 0;
  //     --tw-skew-y: 0;
  //     --tw-scale-x: 1;
  //     --tw-scale-y: 1;
  //     --tw-pan-x: ;
  //     --tw-pan-y: ;
  //     --tw-pinch-zoom: ;
  //     --tw-scroll-snap-strictness: proximity;
  //     --tw-gradient-from-position: ;
  //     --tw-gradient-via-position: ;
  //     --tw-gradient-to-position: ;
  //     --tw-ordinal: ;
  //     --tw-slashed-zero: ;
  //     --tw-numeric-figure: ;
  //     --tw-numeric-spacing: ;
  //     --tw-numeric-fraction: ;
  //     --tw-ring-inset: ;
  //     --tw-ring-offset-width: 0px;
  //     --tw-ring-offset-color: #fff;
  //     --tw-ring-color: rgb(128 204 255 / 0.5);
  //     --tw-ring-offset-shadow: 0 0 #0000;
  //     --tw-ring-shadow: 0 0 #0000;
  //     --tw-shadow: 0 0 #0000;
  //     --tw-shadow-colored: 0 0 #0000;
  //     --tw-blur: ;
  //     --tw-brightness: ;
  //     --tw-contrast: ;
  //     --tw-grayscale: ;
  //     --tw-hue-rotate: ;
  //     --tw-invert: ;
  //     --tw-saturate: ;
  //     --tw-sepia: ;
  //     --tw-drop-shadow: ;
  //     --tw-backdrop-blur: ;
  //     --tw-backdrop-brightness: ;
  //     --tw-backdrop-contrast: ;
  //     --tw-backdrop-grayscale: ;
  //     --tw-backdrop-hue-rotate: ;
  //     --tw-backdrop-invert: ;
  //     --tw-backdrop-opacity: ;
  //     --tw-backdrop-saturate: ;
  //     --tw-backdrop-sepia: ;
  //     display: flex;
  //     flex-direction: row;
  //     gap: 2.5rem;`
  //     let innerStyle = `    -webkit-text-size-adjust: 100%;
  //     tab-size: 4;
  //     font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
  //     font-feature-settings: normal;
  //     font-variation-settings: normal;
  //     line-height: inherit;
  //     --tw-bg-opacity: 1;
  //     height: 52px;
  //     width: 52px;
  //     transform: none;
  //     box-sizing: border-box;
  //     border-width: 0;
  //     border-style: solid;
  //     border-color: #e5e7eb;
  //     --tw-border-spacing-x: 0;
  //     --tw-border-spacing-y: 0;
  //     --tw-translate-x: 0;
  //     --tw-translate-y: 0;
  //     --tw-rotate: 0;
  //     --tw-skew-x: 0;
  //     --tw-skew-y: 0;
  //     --tw-scale-x: 1;
  //     --tw-scale-y: 1;
  //     --tw-pan-x: ;
  //     --tw-pan-y: ;
  //     --tw-pinch-zoom: ;
  //     --tw-scroll-snap-strictness: proximity;
  //     --tw-gradient-from-position: ;
  //     --tw-gradient-via-position: ;
  //     --tw-gradient-to-position: ;
  //     --tw-ordinal: ;
  //     --tw-slashed-zero: ;
  //     --tw-numeric-figure: ;
  //     --tw-numeric-spacing: ;
  //     --tw-numeric-fraction: ;
  //     --tw-ring-inset: ;
  //     --tw-ring-offset-width: 0px;
  //     --tw-ring-offset-color: #fff;
  //     --tw-ring-color: rgb(128 204 255 / 0.5);
  //     --tw-ring-offset-shadow: 0 0 #0000;
  //     --tw-ring-shadow: 0 0 #0000;
  //     --tw-shadow: 0 0 #0000;
  //     --tw-shadow-colored: 0 0 #0000;
  //     --tw-blur: ;
  //     --tw-brightness: ;
  //     --tw-contrast: ;
  //     --tw-grayscale: ;
  //     --tw-hue-rotate: ;
  //     --tw-invert: ;
  //     --tw-saturate: ;
  //     --tw-sepia: ;
  //     --tw-drop-shadow: ;
  //     --tw-backdrop-blur: ;
  //     --tw-backdrop-brightness: ;
  //     --tw-backdrop-contrast: ;
  //     --tw-backdrop-grayscale: ;
  //     --tw-backdrop-hue-rotate: ;
  //     --tw-backdrop-invert: ;
  //     --tw-backdrop-opacity: ;
  //     --tw-backdrop-saturate: ;
  //     --tw-backdrop-sepia: ;
  //     display: block;
  //     vertical-align: middle;
  //     fill: currentColor;
  //     animation: 1.5s ease-in-out 180ms infinite normal none running slowShow;`

  //     `<div class="flex flex-row gap-10" style="" ><svg class="fill-current " height="52px" width="52px" transform="" style="animation: 1.5s ease-in-out 180ms infinite normal none running slowShow;"><use xlink:href="/0.20.3/v0/icons/orca.svg#hyperswitch-triangle"></use></svg><svg class="fill-current " height="52px" width="52px" transform="" style="animation: 1.5s ease-in-out 360ms infinite normal none running slowShow;"><use xlink:href="/0.20.3/v0/icons/orca.svg#hyperswitch-square"></use></svg><svg class="fill-current " height="52px" width="52px" transform="" style="animation: 1.5s ease-in-out 540ms infinite normal none running slowShow;"><use xlink:href="/0.20.3/v0/icons/orca.svg#hyperswitch-circle"></use></svg></div>`

  //   }

  let displayDiv = React.useMemo1(() => {
    <>
      <div id="threeDsAuthDiv" className="hidden" />
      <iframe
        // srcDoc={`<div style="display:flex;flex:1;justify-content:space-between;"><img src="https://media.licdn.com/dms/image/D5603AQFRHGKSvSI28w/profile-displayphoto-shrink_200_200/0/1706028854839?e=1712793600&v=beta&t=EZoEPGBDhQ6SOrgzyIfJkQO8d0CS3SrDpb2W7CO89_g"/><img src="https://images.mid-day.com/images/images/2020/sep/wantedsalman_l.jpg?tr=w-480,h-270" /></div><div>Wait, let me authenticate!</div>`}
        id="threeDsAuthFrame"
        name="threeDsAuthFrame"
        src=""
        height="500rem"
        width="100%"
      />
    </>
  }, [frameStyle])

  <Modal showClose=false openModal setOpenModal>
    <div className="backdrop-blur-xl"> {displayDiv} </div>
  </Modal>
}
