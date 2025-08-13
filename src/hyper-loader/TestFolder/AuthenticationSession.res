open Utils
open Identity
open LoggerUtils
open EventListenerManager

let make = (
  ~clientSecret,
  ~publishableKey,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~iframeRef,
  ~setIframeRef,
  ~profileId,
  ~sdkSessionId,
  ~analyticsMetadata,
  ~customBackendUrl,
) => {
  let widgets = widgetOptions => {
    // open Promise
    let widgetOptionsDict = widgetOptions->JSON.Decode.object
    // elementsOptionsDict
    // ->Option.forEach(x => x->Dict.set("launchTime", Date.now()->JSON.Encode.float))
    // ->ignore

    let authenticationId = clientSecret->String.split("_secret")->Array.get(0)->Option.getOr("")

    AuthenticationSessionElements.make(
      widgetOptions,
      setIframeRef,
      ~sdkSessionId,
      ~publishableKey,
      ~profileId,
      ~clientSecret,
      ~authenticationId,
      // ~ephemeralKey={ephemeralKeyId},
      // ~pmClientSecret={pmClientSecretId},
      // ~pmSessionId={pmSessionIdVal},
      ~logger,
      ~analyticsMetadata,
      ~customBackendUrl,
    )
  }

  let postSubmitMessage = message => {
    iframeRef.contents->Array.forEach(ifR => {
      Console.log3("===> Posting message to iframe", ifR, message)
      ifR->Window.iframePostMessage(message)
    })
  }

  // let confirmAuthentication = (payload, isOneClick, result, ~isSdkButton=false) => {
  let confirmAuthentication = _ => {
    let confirmTimestamp = Date.now()
    // let confirmParams =
    //   payload
    //   ->JSON.Decode.object
    //   ->Option.flatMap(x => x->Dict.get("confirmParams"))
    //   ->Option.getOr(Dict.make()->JSON.Encode.object)

    // let redirect = payload->getDictFromJson->getString("redirect", "if_required")

    // let url =
    //   confirmParams
    //   ->JSON.Decode.object
    //   ->Option.flatMap(x => x->Dict.get("return_url"))
    //   ->Option.flatMap(JSON.Decode.string)
    //   ->Option.getOr("")

    Promise.make((resolve1, _) => {
      let handleMessage = (event: Types.event) => {
        let json = event.data->anyTypeToJson
        let dict = json->getDictFromJson
        switch dict->Dict.get("authenticationSuccessful") {
        | Some(val) =>
          logApi(
            ~apiLogType=Method,
            ~optLogger=logger,
            ~result=val,
            ~paymentMethod="confirmPayment",
            ~eventName=CONFIRM_PAYMENT,
          )
          let data = dict->Dict.get("data")->Option.getOr(Dict.make()->JSON.Encode.object)
          // let returnUrl =
          //   dict->Dict.get("url")->Option.flatMap(JSON.Decode.string)->Option.getOr(url)

          // if isOneClick {
          //   iframeRef.contents->Array.forEach(ifR => {
          //     // to unset one click button loader
          //     ifR->Window.iframePostMessage(
          //       [("oneClickDoSubmit", false->JSON.Encode.bool)]->Dict.fromArray,
          //     )
          //   })
          // }
          postSubmitMessage(dict)

          let submitSuccessfulValue = val->JSON.Decode.bool->Option.getOr(false)

          if !submitSuccessfulValue {
            resolve1(json)
          } else {
            resolve1(data)
          }
        | None => ()
        }
      }

      Console.log("===> Inside confirmAuthentication")
      // let message = isOneClick
      //   ? [("oneClickDoSubmit", result->JSON.Encode.bool)]->Dict.fromArray
      //   : [
      //       ("doSubmit", true->JSON.Encode.bool),
      //       ("clientSecret", clientSecret.contents->JSON.Encode.string),
      //       ("confirmTimestamp", confirmTimestamp->JSON.Encode.float),
      //       ("readyTimestamp", readyTimestamp->JSON.Encode.float),
      //       (
      //         "confirmParams",
      //         [
      //           ("return_url", url->JSON.Encode.string),
      //           ("publishableKey", publishableKey->JSON.Encode.string),
      //           ("redirect", redirect->JSON.Encode.string),
      //         ]->getJsonFromArrayOfJson,
      //       ),
      //     ]->Dict.fromArray
      let message = [
        ("doAuthentication", true->JSON.Encode.bool),
        ("clientSecret", clientSecret->JSON.Encode.string),
        // ("confirmTimestamp", confirmTimestamp->JSON.Encode.float),
        // ("readyTimestamp", Date.now()->JSON.Encode.float),
        // (
        //   "confirmParams",
        //   [
        //     ("return_url", url->JSON.Encode.string),
        //     ("publishableKey", publishableKey->JSON.Encode.string),
        //     ("redirect", redirect->JSON.Encode.string),
        //   ]->getJsonFromArrayOfJson,
        // ),
      ]->Dict.fromArray
      addSmartEventListener("message", handleMessage, "onSubmit")

      Console.log2("===> IframRef", iframeRef)

      postSubmitMessage(message)
    })
  }

  let resetSelectedSavedMethod = () => {
    let message = [("resetSelectedSavedMethod", true->JSON.Encode.bool)]
    postSubmitMessage(message->Dict.fromArray)

    messageTopWindow(message)
  }

  let returnObject: Types.authenticationSession = {
    widgets,
    confirmAuthentication,
    resetSelectedSavedMethod,
  }

  returnObject
}
