open JotaiAtoms
open Utils

@react.component
let make = () => {
  let {themeObj, localeString} = Jotai.useAtomValue(configAtom)
  let keys = Jotai.useAtomValue(keys)
  let {parentURL} = keys
  let setShowPaymentMethodsScreen = Jotai.useSetAtom(showPaymentMethodsScreen)
  let placeholder =
    Jotai.useAtomValue(cardholderNamePlaceholder)->Option.getOr(localeString.cardHolderName)
  let (cardholderName, setCardholderName) = React.useState(_ => "")
  let nameRef = React.useRef(Nullable.null)

  React.useEffect0(() => {
    setShowPaymentMethodsScreen(_ => true)
    None
  })

  let groupIdFromUrl = CardUtils.getQueryParamsDictforKey(
    RescriptReactRouter.useUrl().search,
    "groupId",
  )
  let portKey = if groupIdFromUrl !== "" {
    CardFormCoordinator.portKey(~groupId=groupIdFromUrl, ~fieldName="cardholderName")
  } else {
    ""
  }

  React.useEffect(() => {
    if keys.iframeId !== "" && keys.iframeId !== "no-element" {
      SubscriptionEventHooks.emitReady(~iframeId=keys.iframeId, ~elementType="cardholderName")
    }
    None
  }, [keys.iframeId])

  React.useEffect(() => {
    let handleParentMessage = (ev: Window.event) => {
      if ev.source === iframeParent && (parentURL === "*" || ev.origin === parentURL) {
        let dict = ev.data->safeParse->getDictFromJson
        if dict->Dict.get("doFocus")->Option.isSome {
          CardUtils.focusRef(nameRef)
        } else if dict->Dict.get("doBlur")->Option.isSome {
          CardUtils.blurRef(nameRef)
        } else if dict->Dict.get("doClearValues")->Option.isSome {
          setCardholderName(_ => "")
        }
      }
    }
    handleMessage(handleParentMessage, "")
  }, [parentURL])

  React.useEffect(() => {
    let empty = cardholderName === ""
    let {windowPayload, portPayload} = CardFormPortProtocol.encodeFieldStateUpdate({
      cardBrand: "",
      fieldStatus: [("complete", !empty->JSON.Encode.bool), ("empty", empty->JSON.Encode.bool)]
      ->Dict.fromArray
      ->JSON.Encode.object,
      cardInfo: PaymentEventData.buildCardInfo(
        ~cardNumber="",
        ~expiry="",
        ~cvc="",
        ~brand="",
      )->PaymentEventData.cardInfoToJson,
      focusReady: false,
      rawCardNumber: None,
      rawCardExpiry: None,
      rawCvc: None,
      rawCardholderName: ?(empty ? None : Some(cardholderName)),
    })
    messageParentWindow([("cardStateUpdate", windowPayload)], ~targetOrigin=parentURL)
    if portKey !== "" && !SadPortRegistry.postFrame(~key=portKey, portPayload) {
      Console.warn(
        `[SecureCardholderNameField] dropped port frame for unregistered portKey "${portKey}"`,
      )
    }
    None
  }, (cardholderName, portKey))

  let onChange = ev => {
    let value: string = ReactEvent.Form.target(ev)["value"]
    setCardholderName(_ => value)
  }

  <div
    className="animate-slowShow flex flex-col"
    style={{gridGap: "0px", height: themeObj.inputFieldHeight}}
  >
    <PaymentInputField
      fieldName=localeString.cardHolderName
      value=cardholderName
      onChange
      type_="text"
      className="w-full"
      height=themeObj.inputFieldHeight
      inputRef=nameRef
      placeholder
      paymentType=CardThemeType.PaymentMethodsSDK
      id="card-holder-name"
      autocomplete="cc-name"
      isLabelHidden=true
      isErrorHidden=true
    />
  </div>
}
