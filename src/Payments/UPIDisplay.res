open Utils
open RecoilAtoms
open UPITypes
open UPIHelpers

let defaultTimer = 300.0

@react.component
let make = () => {
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (return_url, setReturnUrl) = React.useState(_ => "")
  let (upiUrl, setUpiUrl) = React.useState(_ => "")
  let (paymentMethodType, setPaymentMethodType) = React.useState(_ => "")
  let (availableApps, setAvailableApps) = React.useState(_ => [])
  let (selectedApp, setSelectedApp) = React.useState(_ => None)
  let (currentScreen, setCurrentScreen) = React.useState(_ => AppSelection)
  let (timeRemaining, setTimeRemaining) = React.useState(_ => defaultTimer)
  let (clientSecret, setClientSecret) = React.useState(_ => "")
  let (headers, setHeaders) = React.useState(_ => [])
  let (publishableKey, setPublishableKey) = React.useState(_ => "")

  let (timer, setTimer) = React.useState(_ => 0.0)

  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)

  let startPaymentPolling = (~clientSecret, ~publishableKey, ~delayTime, ~frequency) => {
    if clientSecret !== "" && publishableKey !== "" {
      let pollPayment = async () => {
        try {
          let res = await PaymentHelpers.pollRetrievePaymentIntent(
            ~headers=headers->Dict.fromArray,
            clientSecret,
            ~publishableKey,
            ~logger,
            ~customPodUri,
            ~delayTime,
            ~frequency,
            ~count=0,
          )
          if res !== JSON.Encode.null {
            Modal.close(setOpenModal)
            postSubmitResponse(~jsonData=res, ~url=return_url)
          }
        } catch {
        | error => Console.error2("Error while polling payment intent:", error)
        }
      }
      pollPayment()->ignore
    }
  }

  let isAndroid = React.useMemo0(() => {
    getMobileOperatingSystem() === "ANDROID"
  })

  React.useEffect0(() => {
    let handleResponse = (event: Window.event) => {
      let json = event.data->safeParse
      let dict = json->getDictFromJson

      switch dict->Dict.get("paymentRequestResult") {
      | Some(val) =>
        let appAvailable = val->JSON.Decode.bool->Option.getOr(false)
        let appName = dict->getStringFromDict("app", "")
        let packageName = dict->getStringFromDict("packageName", "")

        if appAvailable {
          let newAvailableApp = [{name: appName, packageName}]
          setAvailableApps(prev => prev->Array.concat(newAvailableApp))
        }

      | None => ()
      }
    }
    Window.addEventListener("message", handleResponse)
    Some(
      () => {
        Window.removeEventListener("message", handleResponse)
      },
    )
  })

  React.useEffect(() => {
    if isAndroid {
      setAvailableApps(prev => prev->Array.concat([anyUpiApp]))
    }
    allUpiApps
    ->Array.map(app => {
      let message = [
        ("paymentRequest", true->JSON.Encode.bool),
        ("app", app.name->JSON.Encode.string),
        ("url", app.packageName->JSON.Encode.string),
      ]

      messageParentWindow(message)
    })
    ->ignore
    None
  }, [isMobileDevice, isAndroid])

  React.useEffect0(() => {
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let handleAsync = async () => {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
          let metadata = dict->getJsonObjectFromDict("metadata")
          let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())

          let paymentMethodType = metaDataDict->getString("paymentMethodType", "")
          let url = metaDataDict->getString("url", "")
          let publishableKey = metaDataDict->getString("publishableKey", "")
          let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
          let displayToTimestamp = metaDataDict->getFloat("displayToTimestamp", 0.0)
          let displayFromTimestamp = metaDataDict->getFloat("displayFromTimestamp", 0.0)
          let timerValue = (displayToTimestamp -. displayFromTimestamp) /. 1000000000.0
          let frequencyValue = metaDataDict->getInt("frequency", -1)
          let delayInSecs = metaDataDict->getInt("delayInSecs", 0)

          setTimer(_ => timerValue)
          setPaymentMethodType(_ => paymentMethodType)
          setUpiUrl(_ => url)
          setReturnUrl(_ => metadata->getDictFromJson->getString("return_url", ""))
          setPublishableKey(_ => publishableKey)
          setClientSecret(_ => paymentIntentId)
          if timerValue > 0.0 {
            setTimeRemaining(_ => timerValue)
          }

          let headersDict = metaDataDict->getDictFromDict("headers")
          let headers = Dict.make()
          headersDict
          ->Dict.toArray
          ->Array.forEach(entries => {
            let (x, val) = entries
            Dict.set(headers, x, val->getStringFromJson(""))
          })
          setHeaders(_ => headers->Dict.toArray)

          if paymentIntentId !== "" && publishableKey !== "" {
            startPaymentPolling(
              ~clientSecret=paymentIntentId,
              ~publishableKey,
              ~delayTime=delayInSecs * 1000,
              ~frequency=frequencyValue,
            )
          }
        }
      }
      handleAsync()->ignore
    }

    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  React.useEffect(() => {
    if paymentMethodType == "upi_collect" {
      setCurrentScreen(_ => VerificationScreen)
    }
    None
  }, [paymentMethodType])

  React.useEffect(() => {
    if (
      currentScreen === VerificationScreen ||
        (currentScreen === AppSelection && paymentMethodType === "upi_qr")
    ) {
      let intervalID = setInterval(() => {
        setTimeRemaining(
          prev => {
            if prev <= 1.0 {
              Modal.close(setOpenModal)
              postSubmitResponse(~jsonData=JSON.Encode.null, ~url=return_url)
              0.0
            } else {
              prev -. 1.0
            }
          },
        )
      }, 1000)

      Some(() => clearInterval(intervalID))
    } else {
      None
    }
  }, (currentScreen, paymentMethodType))

  let closeModal = async () => {
    try {
      let json = await PaymentHelpers.retrievePaymentIntent(
        clientSecret,
        ~headers=headers->Dict.fromArray,
        ~publishableKey,
        ~logger,
        ~customPodUri,
      )
      postSubmitResponse(~jsonData=json, ~url=return_url)
      Modal.close(setOpenModal)
    } catch {
    | e => {
        Console.error2("Retrieve Failed", e)
        Modal.close(setOpenModal)
        postSubmitResponse(~jsonData=JSON.Encode.null, ~url=return_url)
      }
    }
  }

  let handleClose = () => {
    closeModal()->ignore
  }

  <Modal showClose=true openModal setOpenModal closeCallback=handleClose>
    <div className="flex flex-col h-full justify-between items-center px-6 pb-6">
      <RenderIf condition={currentScreen === AppSelection}>
        <div className="w-full">
          <RenderIf condition={paymentMethodType === "upi_qr"}>
            <UPIQRCode upiUrl timer timeRemaining defaultTimer />
          </RenderIf>
          <RenderIf condition={paymentMethodType !== "upi_qr"}>
            <UPIAvailableAppsModal availableApps selectedApp setSelectedApp />
          </RenderIf>
        </div>
        <div className="w-full mt-6 space-y-3">
          <RenderIf condition={paymentMethodType === "upi_qr"}>
            <UPIButtons.DoneButton closeModal />
          </RenderIf>
          <RenderIf condition={paymentMethodType !== "upi_qr"}>
            <UPIButtons.AppSelectionButton
              selectedApp upiUrl setCurrentScreen setTimeRemaining timer defaultTimer
            />
          </RenderIf>
        </div>
      </RenderIf>
      <RenderIf condition={currentScreen === VerificationScreen}>
        <UPIWaitModal timeRemaining timer defaultTimer />
        <div className="w-full space-y-3">
          <UPIButtons.DoneButton closeModal />
          <RenderIf condition={paymentMethodType === "upi_intent"}>
            <UPIButtons.TryAnotherAppButton setCurrentScreen setSelectedApp />
          </RenderIf>
        </div>
      </RenderIf>
    </div>
  </Modal>
}
