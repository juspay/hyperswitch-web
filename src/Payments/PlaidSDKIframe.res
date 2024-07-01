@react.component
let make = () => {
  open Utils

  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let (linkToken, setLinkToken) = React.useState(_ => "")
  let (isReady, setIsReady) = React.useState(_ => false)
  let (pmAuthConnectorsArr, setPmAuthConnectorsArr) = React.useState(_ => [])

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let metaData = json->getDictFromJson->getDictFromDict("metadata")
      let linkToken = metaData->getString("linkToken", "")
      let pmAuthConnectorArray =
        metaData
        ->getArray("pmAuthConnectorArray")
        ->Array.map(ele => ele->JSON.Decode.string)
      setLinkToken(_ => linkToken)
      setPmAuthConnectorsArr(_ => pmAuthConnectorArray)
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  PmAuthConnectorUtils.mountAllRequriedAuthConnectorScripts(
    ~pmAuthConnectorsArr,
    ~onScriptLoaded=authConnector => {
      switch authConnector->PmAuthConnectorUtils.pmAuthNameToTypeMapper {
      | PLAID => setIsReady(_ => true)
      | NONE => ()
      }
    },
    ~logger,
  )

  React.useEffect(() => {
    if isReady && linkToken->String.length > 0 {
      let handler = Plaid.create({
        token: linkToken,
        onSuccess: (publicToken, _) => {
          Js.log2("Plaid link token onSuccess", publicToken)
        },
        onExit: json => {
          Console.log2("Plaid link token onExit", json)
        },
        onLoad: json => {
          Console.log2("Plaid link token onLoad", json)
        },
        onEvent: json => {
          Console.log2("Plaid link token onEvent", json)
        },
      })

      handler.open_()
    }

    None
  }, (isReady, linkToken))

  React.null
}
