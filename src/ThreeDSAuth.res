open Utils

@react.component
let make = () => {
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (loader, setloader) = React.useState(_ => true)

  let threeDsAuthoriseUrl = React.useRef("")
  let (expiryTime, setExpiryTime) = React.useState(_ => 600000.0)

  let logger = OrcaLogger.make(~source=Elements(Payment), ())

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

  React.useEffect0(() => {
    handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
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
          if dict->Dict.get("error")->Option.isSome {
            let errorObj = PaymentError.itemToObjMapper(dict)
            handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
            postFailedSubmitResponse(
              ~errortype=errorObj.error.type_,
              ~message=errorObj.error.message,
            )
            JSON.Encode.null->resolve
          } else {
            let creq = dict->getString("challenge_request", "")
            let transStatus = dict->getString("trans_status", "Y")
            let acsUrl = dict->getString("acs_url", "")

            let ele = Window.querySelector("#threeDsAuthDiv")

            LoggerUtils.handleLogging(
              ~optLogger=Some(logger),
              ~eventName=DISPLAY_THREE_DS_SDK,
              ~value=transStatus,
              ~paymentMethod="CARD",
              (),
            )

            switch ele->Nullable.toOption {
            | Some(elem) =>
              if transStatus === "C" {
                setloader(_ => false)
                let form = elem->makeForm(acsUrl, "3dsChallenge")
                let input = Types.createElement("input")
                input.name = "creq"
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
            (),
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

  let expiryString = React.useMemo(() => {
    let minutes = (expiryTime /. 60000.0)->Belt.Float.toInt->Belt.Int.toString

    let seconds =
      mod(expiryTime->Belt.Float.toInt, 60000)->Belt.Int.toString->String.slice(~start=0, ~end=-3)
    Console.log(mod(expiryTime->Belt.Float.toInt, 60000))
    let secondsString =
      seconds->String.length == 1 ? `0${seconds}` : seconds->String.length == 0 ? "00" : seconds
    `${minutes}:${secondsString}`
  }, [expiryTime])
  <>
    <RenderIf condition={loader}>
      <PaymentLoader />
    </RenderIf>
    <Modal loader={loader} showClose=true openModal setOpenModal closeCallback={handleFrictionLess}>
      <div className="backdrop-blur-xl">
        <div
          className="flex flex-row w-full justify-center items-start font-medium text-2xl mb-2 font-semibold text-[#151A1F] opacity-50">
          {expiryString->React.string}
        </div>
        <div className="w-full font-medium text-xs text-[#151A1F] opacity-50 mb-2">
          {React.string(
            " Please complete the payment within next 10 minutes, after which you will be automatically redirected. ",
          )}
        </div>
        <div id="threeDsAuthDiv" className="hidden" />
        <iframe
          id="threeDsAuthFrame" name="threeDsAuthFrame" style={minHeight: "500px"} width="100%"
        />
      </div>
    </Modal>
  </>
}
