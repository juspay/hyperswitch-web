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
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (loader, setloader) = React.useState(_ => true)

  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

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
        let threeDsAuthoriseUrl =
          metaDataDict
          ->getJsonObjectFromDict("threeDSData")
          ->Js.Json.decodeObject
          ->Belt.Option.getWithDefault(Js.Dict.empty())
          ->getString("three_ds_authorize_url", "")
        let headers =
          headersDict
          ->Js.Dict.entries
          ->Js.Array2.map(entries => {
            let (x, val) = entries
            (x, val->Js.Json.decodeString->Belt.Option.getWithDefault(""))
          })

        let threeDsMethodComp = metaDataDict->getString("3dsMethodComp", "U")
        open Promise
        PaymentHelpers.threeDsAuth(
          ~optLogger=Some(logger),
          ~clientSecret=paymentIntentId,
          ~threeDsMethodComp,
          ~headers,
        )
        ->then(json => {
          let dict = json->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
          let creq = dict->getString("challenge_request", "")
          let transStatus = dict->getString("trans_status", "Y")
          let acsUrl = dict->getString("acs_url", "")

          let ele = Window.querySelector("#threeDsAuthDiv")

          switch ele->Js.Nullable.toOption {
          | Some(elem) =>
            if transStatus === "C" {
              setloader(_ => false)
              let form = elem->OrcaUtils.makeForm(acsUrl, "3dsChallenge")
              let input = Types.createElement("input")
              input.name = "creq"
              input.value = creq
              form.target = "threeDsAuthFrame"
              form.appendChild(. input)
              form.submit(.)
            } else {
              let form1 = elem->OrcaUtils.makeForm(threeDsAuthoriseUrl, "3dsFrintionLess")
              form1.submit(.)
            }
          | None => ()
          }
          resolve(json)
        })
        ->ignore
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  <Modal loader={loader} showClose=false openModal setOpenModal>
    <div className="backdrop-blur-xl">
      <div id="threeDsAuthDiv" className="hidden" />
      <iframe id="threeDsAuthFrame" name="threeDsAuthFrame" src="" height="500rem" width="100%" />
    </div>
  </Modal>
}
