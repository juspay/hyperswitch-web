open Utils

@react.component
let make = () => {
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (loader, setloader) = React.useState(_ => true)

  let threeDsAuthoriseUrl = React.useRef("")
  let (expiryTime, setExpiryTime) = React.useState(_ => 600000.0)

  let logger = HyperLogger.make(~source=Elements(Payment))

  let handleFrictionLess = () => {
    let ele = Window.querySelector("#threeDsAuthDiv")
    switch ele->Nullable.toOption {
    | Some(elem) => {
        let form1 = elem->makeForm(threeDsAuthoriseUrl.current, "3dsFrictionLess")
        form1.submit()
      }
    | None => ()
    }
  }

  let eventsToSendToParent = ["confirmParams", "poll_status", "openurl_if_required"]

  eventsToSendToParent->UtilityHooks.useSendEventsToParent

  React.useEffect0(() => {
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson
      if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")
        let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
        let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
        let publishableKey = metaDataDict->getString("publishableKey", "")
        logger.setClientSecret(paymentIntentId)
        logger.setMerchantId(publishableKey)
        let headersDict =
          metaDataDict
          ->getJsonObjectFromDict("headers")
          ->JSON.Decode.object
          ->Option.getOr(Dict.make())
        threeDsAuthoriseUrl.current =
          metaDataDict
          ->getJsonObjectFromDict("threeDSData")
          ->JSON.Decode.object
          ->Option.getOr(Dict.make())
          ->getString("three_ds_authorize_url", "")
        let headers = headersDict->convertDictToArrayOfKeyStringTuples

        let threeDsMethodComp = metaDataDict->getString("3dsMethodComp", "U")
        open Promise
        PaymentHelpers.threeDsAuth(
          ~logger,
          ~clientSecret=paymentIntentId,
          ~threeDsMethodComp,
          ~headers=headers->Dict.fromArray,
        )
        ->then(json => {
          let dict = json->getDictFromJson
          if dict->Dict.get("error")->Option.isSome {
            let errorObj = PaymentError.itemToObjMapper(dict)
            messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
            postFailedSubmitResponse(
              ~errortype=errorObj.error.type_,
              ~message=errorObj.error.message,
            )
            JSON.Encode.null->resolve
          } else {
            let creq = dict->getString("challenge_request", "")
            let challengeRequestKey = dict->getString("challenge_request_key", "creq")
            let transStatus = dict->getString("trans_status", "Y")
            let acsUrl = dict->getString("acs_url", "")

            let ele = Window.querySelector("#threeDsAuthDiv")

            LoggerUtils.handleLogging(
              ~optLogger=Some(logger),
              ~eventName=DISPLAY_THREE_DS_SDK,
              ~value=transStatus,
              ~paymentMethod="CARD",
            )

            switch ele->Nullable.toOption {
            | Some(elem) =>
              if transStatus === "C" {
                setloader(_ => false)
                let form = elem->makeForm(acsUrl, "3dsChallenge")
                let input = Types.createElement("input")
                input.name = challengeRequestKey
                input.value = creq
                form.target = "threeDsAuthFrame"
                form.appendChild(input)
                form.submit()
              } else {
                handleFrictionLess()
              }
            | None => ()
            }
            resolve(json)
          }
        })
        ->catch(err => {
          let exceptionMessage = err->formatException
          LoggerUtils.handleLogging(
            ~optLogger=Some(logger),
            ~eventName=DISPLAY_THREE_DS_SDK,
            ~value=exceptionMessage->JSON.stringify,
            ~paymentMethod="CARD",
            ~logType=ERROR,
          )
          let errorObj = PaymentError.itemToObjMapper(dict)
          postFailedSubmitResponse(~errortype=errorObj.error.type_, ~message=errorObj.error.message)
          JSON.Encode.null->resolve
        })
        ->ignore
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  React.useEffect(() => {
    if expiryTime < 1000.0 {
      handleFrictionLess()
    }
    let intervalID = setInterval(() => {
      setExpiryTime(prev => prev -. 1000.0)
    }, 1000)
    Some(
      () => {
        clearInterval(intervalID)
      },
    )
  }, [expiryTime])

  <Modal loader={loader} openModal setOpenModal closeCallback={handleFrictionLess}>
    <div className="backdrop-blur-xl">
      <div id="threeDsAuthDiv" className="hidden" />
      <iframe
        id="threeDsAuthFrame"
        name="threeDsAuthFrame"
        title="3D Secure Authentication Frame"
        style={
          minHeight: "500px",
          outline: "none",
        }
        width="100%"
      />
    </div>
  </Modal>
}
