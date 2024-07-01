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
      if linkToken->String.length > 0 {
        let pmAuthConnectorArray =
          metaData
          ->getArray("pmAuthConnectorArray")
          ->Array.map(ele => ele->JSON.Decode.string)

        setLinkToken(_ => linkToken)
        setPmAuthConnectorsArr(_ => pmAuthConnectorArray)
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  React.useEffect(() => {
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
    None
  }, [pmAuthConnectorsArr])

  React.useEffect(() => {
    if isReady && linkToken->String.length > 0 {
      let handler = Plaid.create({
        token: linkToken,
        onSuccess: (publicToken, _) => {
          handlePostMessage([
            ("fullscreen", false->JSON.Encode.bool),
            ("isPlaid", true->JSON.Encode.bool),
            ("publicToken", publicToken->JSON.Encode.string),
          ])
        },
        onExit: json => {
          handlePostMessage([
            ("fullscreen", false->JSON.Encode.bool),
            ("isPlaid", true->JSON.Encode.bool),
            ("publicToken", ""->JSON.Encode.string),
          ])
        },
      })

      handler.open_()
    }

    None
  }, (isReady, linkToken))

  <div className="bg-black/40 backdrop-blur-sm" />
}
