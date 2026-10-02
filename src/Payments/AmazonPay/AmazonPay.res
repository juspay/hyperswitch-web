open AmazonPayHelpers
open AmazonPayHooks

@react.component
let make = (~amazonPayToken) => {
  let token = amazonPayToken->amazonPayTokenMapper

  token->useAmazonPay

  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let showFullScreenLoader = () =>
    Utils.messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
    ])

  <div onClick={_ => showFullScreenLoader()} id="AmazonPayButton" />
}

let default = make
