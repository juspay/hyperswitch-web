open Utils

@react.component
let make = () => {
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (loader, setloader) = React.useState(_ => true)

  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
        let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
        let headersDict =
          metaDataDict
          ->getJsonObjectFromDict("headers")
          ->JSON.Decode.object
          ->Option.getOr(Dict.make())
        let threeDsAuthoriseUrl =
          metaDataDict
          ->getJsonObjectFromDict("threeDSData")
          ->JSON.Decode.object
          ->Option.getOr(Dict.make())
          ->getString("three_ds_authorize_url", "")
        let headers =
          headersDict
          ->Dict.toArray
          ->Array.map(entries => {
            let (x, val) = entries
            (x, val->JSON.Decode.string->Option.getOr(""))
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
          let dict = json->JSON.Decode.object->Option.getOr(Dict.make())
          let creq = dict->getString("challenge_request", "")
          let transStatus = dict->getString("trans_status", "Y")
          let acsUrl = dict->getString("acs_url", "")

          let ele = Window.querySelector("#threeDsAuthDiv")

          switch ele->Nullable.toOption {
          | Some(elem) =>
            if transStatus === "C" {
              setloader(_ => false)
              let form = elem->OrcaUtils.makeForm(acsUrl, "3dsChallenge")
              let input = Types.createElement("input")
              input.name = "creq"
              input.value = creq
              form.target = "threeDsAuthFrame"
              form.appendChild(input)
              form.submit()
            } else {
              let form1 = elem->OrcaUtils.makeForm(threeDsAuthoriseUrl, "3dsFrintionLess")
              form1.submit()
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
      <iframe
        id="threeDsAuthFrame"
        name="threeDsAuthFrame"
        style={ReactDOMStyle.make(~minHeight="500px", ())}
        width="100%"
      />
    </div>
  </Modal>
}
