open Utils
@react.component
let make = () => {
  let logger = HyperLogger.make(~source=Elements(Payment))

  let stateMetadataRef = React.useRef(Dict.make()->JSON.Encode.object)
  let consumePostMessageForThreeDsMethodCompletionRef = React.useRef(false)
  let threeDsUrlRef = React.useRef("")

  let iframeRef = React.useRef(Nullable.null)

  let initialLoadDoneRef = React.useRef(false)
  let isThreeDSMethodCompletionFired = React.useRef(false)
  let isThreeDSMethodFlowStarted = React.useRef(false)

  let (isClearInterval, setIsClearInterval) = React.useState(_ => false)
  let (isStartTimeout, setIsStartTimeout) = React.useState(_ => false)
  let (isStartPolling, setIsStartPolling) = React.useState(_ => false)

  let handleIframeContentLoaded = () => {
    stateMetadataRef.current
    ->Utils.getDictFromJson
    ->Dict.set("3dsMethodComp", "Y"->JSON.Encode.string)

    let metadataDict = stateMetadataRef.current->JSON.Decode.object->Option.getOr(Dict.make())
    let iframeId = metadataDict->getString("iframeId", "")

    if iframeId->String.length > 0 && !isThreeDSMethodCompletionFired.current {
      LoggerUtils.handleLogging(
        ~optLogger=Some(logger),
        ~eventName=THREE_DS_METHOD_RESULT,
        ~value="Y",
        ~paymentMethod="CARD",
      )

      isThreeDSMethodCompletionFired.current = true

      messageParentWindow([
        ("fullscreen", false->JSON.Encode.bool),
        ("param", "paymentloader"->JSON.Encode.string),
        ("iframeId", iframeId->JSON.Encode.string),
      ])

      messageParentWindow([
        ("fullscreen", true->JSON.Encode.bool),
        ("param", `3dsAuth`->JSON.Encode.string),
        ("iframeId", iframeId->JSON.Encode.string),
        ("metadata", stateMetadataRef.current),
      ])
    }
  }

  let getIframeContentDocument = () => {
    let contentWindowDoc =
      iframeRef.current
      ->Nullable.toOption
      ->Option.flatMap(ele => ele->Window.Element.nullableContentWindow->Nullable.toOption)
      ->Option.flatMap(ele => ele->Window.Element.document->Nullable.toOption)

    let contentDocument =
      iframeRef.current
      ->Nullable.toOption
      ->Option.flatMap(ele => ele->Window.Element.nullableContentDocument->Nullable.toOption)

    switch (contentDocument, contentWindowDoc) {
    | (Some(doc), _) => Some(doc)
    | _ => contentWindowDoc
    }
  }

  let handleOnLoad = _ => {
    if !consumePostMessageForThreeDsMethodCompletionRef.current {
      try {
        switch getIframeContentDocument() {
        | Some(doc) => {
            let currentUrl = doc->Window.Location.documentHref

            if !initialLoadDoneRef.current && (currentUrl === "about:blank" || currentUrl === "") {
              initialLoadDoneRef.current = true
            } else {
              handleIframeContentLoaded()
            }
          }
        | None => ()
        }
      } catch {
      | err => {
          let errorName =
            err
            ->Utils.formatException
            ->Utils.getDictFromJson
            ->Utils.getString("type", "")

          if errorName === "SecurityError" {
            handleIframeContentLoaded()
          }
        }
      }
    }
  }

  let handleOnError = value => {
    LoggerUtils.handleLogging(
      ~optLogger=Some(logger),
      ~eventName=THREE_DS_METHOD_RESULT,
      ~value,
      ~paymentMethod="CARD",
      ~logType=ERROR,
    )
    stateMetadataRef.current
    ->Utils.getDictFromJson
    ->Dict.set("3dsMethodComp", "N"->JSON.Encode.string)

    let metadataDict = stateMetadataRef.current->JSON.Decode.object->Option.getOr(Dict.make())
    let iframeId = metadataDict->getString("iframeId", "")

    if iframeId->String.length > 0 && !isThreeDSMethodCompletionFired.current {
      isThreeDSMethodCompletionFired.current = true

      messageParentWindow([
        ("fullscreen", true->JSON.Encode.bool),
        ("param", `3dsAuth`->JSON.Encode.string),
        ("iframeId", iframeId->JSON.Encode.string),
        ("metadata", stateMetadataRef.current),
      ])
    }
  }

  let pollForCompletion = () => {
    if !isThreeDSMethodCompletionFired.current {
      try {
        switch getIframeContentDocument() {
        | Some(doc) => {
            let currentUrl = doc->Window.Location.documentHref

            if doc->Window.readyState === "complete" && initialLoadDoneRef.current {
              if currentUrl !== "about:blank" && currentUrl !== "" {
                handleIframeContentLoaded()
                setIsClearInterval(_ => true)
              }
            }

            if !initialLoadDoneRef.current && currentUrl === "about:blank" {
              initialLoadDoneRef.current = true
            }
          }
        | None => ()
        }
      } catch {
      | err =>
        let errorName =
          err
          ->Utils.formatException
          ->Utils.getDictFromJson
          ->Utils.getString("type", "")

        if errorName === "SecurityError" {
          setIsClearInterval(_ => true)
          handleIframeContentLoaded()
        }
      }
    } else {
      setIsClearInterval(_ => true)
    }
  }

  React.useEffect(() => {
    if isStartPolling {
      let intervalId = setInterval(() => {
        pollForCompletion()
      }, 200)

      if isClearInterval {
        clearInterval(intervalId)
      }

      Some(
        () => {
          clearInterval(intervalId)
        },
      )
    } else {
      None
    }
  }, [isClearInterval, isStartPolling])

  React.useEffect(() => {
    if isStartTimeout {
      let timeoutId = setTimeout(() => {
        handleOnError("Timeout while waiting for ThreeDS Method completion")
      }, 15000) // 15 seconds timeout

      Some(
        () => {
          clearTimeout(timeoutId)
        },
      )
    } else {
      None
    }
  }, [isStartTimeout])

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      try {
        let json = ev.data->safeParse
        let dict = json->Utils.getDictFromJson
        if (
          dict->Dict.get("fullScreenIframeMounted")->Option.isSome &&
            !isThreeDSMethodFlowStarted.current
        ) {
          isThreeDSMethodFlowStarted.current = true
          let metadata = dict->getJsonObjectFromDict("metadata")

          stateMetadataRef.current = metadata

          let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
          let threeDsDataDict =
            metaDataDict
            ->Dict.get("threeDSData")
            ->Option.flatMap(JSON.Decode.object)
            ->Option.getOr(Dict.make())

          let threeDsMethodDetails =
            threeDsDataDict->Utils.getDictFromDict("three_ds_method_details")

          consumePostMessageForThreeDsMethodCompletionRef.current =
            threeDsMethodDetails->Utils.getBool(
              "consume_post_message_for_three_ds_method_completion",
              false,
            )

          let paymentIntentId = metaDataDict->Utils.getString("paymentIntentId", "")
          let publishableKey = metaDataDict->Utils.getString("publishableKey", "")

          logger.setClientSecret(paymentIntentId)
          logger.setMerchantId(publishableKey)

          let ele = Window.querySelector("#threeDsInvisibleDiv")

          switch ele->Nullable.toOption {
          | Some(elem) => {
              threeDsUrlRef.current =
                threeDsMethodDetails->Utils.getString("three_ds_method_url", "")
              let threeDsMethodData =
                threeDsMethodDetails->Utils.getString("three_ds_method_data", "")
              let threeDsMethodKey =
                threeDsMethodDetails->Utils.getString("three_ds_method_key", "threeDSMethodData")

              let form = elem->makeForm(threeDsUrlRef.current, "threeDsHiddenPostMethod")
              let input = Types.createElement("input")
              input.name = encodeURIComponent(threeDsMethodKey)
              let threeDsMethodStr = threeDsMethodData
              input.value = encodeURIComponent(threeDsMethodStr)
              form.target = "threeDsInvisibleIframe"
              form.appendChild(input)
              try {
                if !consumePostMessageForThreeDsMethodCompletionRef.current {
                  setIsStartPolling(_ => true)
                }
                setIsStartTimeout(_ => true)
                form.submit()
              } catch {
              | err => {
                  let exceptionMessage = err->Utils.formatException->JSON.stringify
                  handleOnError(exceptionMessage)
                }
              }
            }
          | None => handleOnError("Unable to Locate threeDsInvisibleDiv")
          }
        }
      } catch {
      | _err => ()
      }

      if consumePostMessageForThreeDsMethodCompletionRef.current && threeDsUrlRef.current !== "" {
        let url = URLModule.makeUrl(threeDsUrlRef.current)
        if url.origin === ev.origin {
          handleIframeContentLoaded()
        }
      }
    }

    Window.addEventListener("message", handle)
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])

    Some(
      () => {
        Window.removeEventListener("message", handle)
      },
    )
  })

  <>
    <PaymentLoader />
    <div id="threeDsInvisibleDiv" className="hidden" />
    <iframe
      id="threeDsInvisibleIframe"
      name="threeDsInvisibleIframe"
      title="3D Secure Invisible Frame"
      className="h-96 invisible"
      ref={iframeRef->ReactDOM.Ref.domRef}
      style={outline: "none"}
      onLoad={handleOnLoad}
      onError={_ => handleOnError("ThreeDS Method Iframe Load Error")}
    />
  </>
}
