open Types
open ErrorUtils
open Identity
open Utils
open EventListenerManager

let isVisaScriptLoaded = ref(false)
let isVisaInitialized = ref(false)
let visaGetCardsResponse = ref(Nullable.null)
let initConfigRef = ref(Nullable.null)

let paymentTokenRef = ref("")
let clickToPayTokenRef = ref(JSON.Encode.null)
let clickToPayProviderRef = ref("")
let isClickToPayRememberMeRef = ref(false)

let make = (
  options,
  setIframeRef,
  ~sdkSessionId,
  ~publishableKey,
  ~profileId,
  ~clientSecret,
  ~authenticationId,
  // ~ephemeralKey={ephemeralKeyId},
  // ~pmClientSecret={pmClientSecretId},
  // ~pmSessionId={pmSessionIdVal},
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~analyticsMetadata,
  ~customBackendUrl,
) => {
  let hyperComponentName = AuthenticationSessionElements
  try {
    let iframeRef = []
    let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
    let savedPaymentElement = Dict.make()
    let localOptions = options->JSON.Decode.object->Option.getOr(Dict.make())

    let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

    let appearance =
      localOptions->Dict.get("appearance")->Option.getOr(Dict.make()->JSON.Encode.object)
    let launchTime = localOptions->getFloat("launchTime", 0.0)

    let fonts =
      localOptions
      ->Dict.get("fonts")
      ->Option.flatMap(JSON.Decode.array)
      ->Option.getOr([])
      ->JSON.Encode.array

    let customPodUri =
      options
      ->JSON.Decode.object
      ->Option.flatMap(x => x->Dict.get("customPodUri"))
      ->Option.flatMap(JSON.Decode.string)
      ->Option.getOr("")

    let localSelectorString = "hyper-preMountLoader-iframe"
    let mountPreMountLoaderIframe = () => {
      if (
        Window.querySelector(
          `#orca-payment-element-iframeRef-${localSelectorString}`,
        )->Js.Nullable.isNullable
      ) {
        let componentType = "preMountLoader"
        let iframeDivHtml = `<div id="orca-element-${localSelectorString}" style= "height: 0px; width: 0px; display: none;"  class="${componentType}">
          <div id="orca-fullscreen-iframeRef-${localSelectorString}"></div>
           <iframe
           id ="orca-payment-element-iframeRef-${localSelectorString}"
           name="orca-payment-element-iframeRef-${localSelectorString}"
          src="${ApiEndpoint.sdkDomainUrl}/index.html?fullscreenType=${componentType}&publishableKey=${publishableKey}&authenticationClientSecret=${clientSecret}&authenticationId=${authenticationId}&profileId=${profileId}&sessionId=${sdkSessionId}&endpoint=${endpoint}&hyperComponentName=${hyperComponentName->getStrFromHyperComponentName}"
          allow="*"
          name="orca-payment"
          style="outline: none;"
        ></iframe>
        </div>`
        let iframeDiv = Window.createElement("div")
        iframeDiv->Window.innerHTML(iframeDivHtml)
        Window.body->Window.appendChild(iframeDiv)
      }

      let elem = Window.querySelector(`#orca-payment-element-iframeRef-${localSelectorString}`)
      elem
    }

    let locale = localOptions->getJsonStringFromDict("locale", "auto")
    let loader = localOptions->getJsonStringFromDict("loader", "")

    let preMountLoaderIframeDiv = mountPreMountLoaderIframe()

    let unMountPreMountLoaderIframe = () => {
      switch preMountLoaderIframeDiv->Nullable.toOption {
      | Some(iframe) => iframe->remove
      | None => ()
      }
    }

    let preMountLoaderMountedPromise = Promise.make((resolve, _reject) => {
      let preMountLoaderIframeCallback = (ev: Types.event) => {
        let json = ev.data->Identity.anyTypeToJson
        let dict = json->getDictFromJson
        if dict->Dict.get("preMountLoaderIframeMountedCallback")->Option.isSome {
          resolve(true->JSON.Encode.bool)
        } else if dict->Dict.get("preMountLoaderIframeUnMount")->Option.isSome {
          unMountPreMountLoaderIframe()
        }
      }
      addSmartEventListener(
        "message",
        preMountLoaderIframeCallback,
        "onPreMountLoaderIframeCallback",
      )
    })

    let fetchSavedPaymentMethods = (mountedIframeRef, disableSaveCards, componentType) => {
      Promise.make((resolve, _) => {
        if !disableSaveCards {
          let handleSavedPaymentMethodsLoaded = (event: Types.event) => {
            let json = event.data->Identity.anyTypeToJson
            let dict = json->getDictFromJson
            let isSavedPaymentMethodsData = dict->getString("data", "") === "saved_payment_methods"
            if isSavedPaymentMethodsData {
              resolve()
              let json = dict->getJsonFromDict("response", JSON.Encode.null)
              let msg = [("savedPaymentMethods", json)]->Dict.fromArray
              mountedIframeRef->Window.iframePostMessage(msg)
            }
          }
          addSmartEventListener(
            "message",
            handleSavedPaymentMethodsLoaded,
            `onSavedPaymentMethodsLoaded-${componentType}`,
          )
        } else {
          resolve()
        }
        let msg =
          [("sendSavedPaymentMethodsResponse", !disableSaveCards->JSON.Encode.bool)]->Dict.fromArray
        preMountLoaderIframeDiv->Window.iframePostMessage(msg)
      })
    }

    let fetchEnabledAuthnMethodsToken = (mountedIframeRef, disableSaveCards, componentType) => {
      Promise.make((resolve, _) => {
        if !disableSaveCards {
          let handleEnabledAuthnMethodsLoaded = (event: Types.event) => {
            let json = event.data->Identity.anyTypeToJson
            let dict = json->getDictFromJson
            let isEnabledAuthnMethodsData =
              dict->getString("data", "") === "enabled_authn_methods_token"
            if isEnabledAuthnMethodsData {
              resolve()
              let json = dict->getJsonFromDict("response", JSON.Encode.null)
              let msg = [("enabledAuthnMethodsToken", json)]->Dict.fromArray
              mountedIframeRef->Window.iframePostMessage(msg)
            }
          }
          addSmartEventListener(
            "message",
            handleEnabledAuthnMethodsLoaded,
            `onEnabledAuthnMethodsLoaded-${componentType}`,
          )
        } else {
          resolve()
        }
        let msg =
          [
            ("sendEnabledAuthnMethodsTokenResponse", !disableSaveCards->JSON.Encode.bool),
          ]->Dict.fromArray
        preMountLoaderIframeDiv->Window.iframePostMessage(msg)
      })
    }

    // let handleVisaGetCards = async (~identityValue, ~otp, ~identityType, ~event) => {
    //   try {
    //     let cardsResult = await ClickToPayHelpers.getCardsVisaUnified(
    //       ~identityValue,
    //       ~otp,
    //       ~identityType,
    //     )

    //     let msg =
    //       [
    //         ("fetchedVisaCardsResult", true->JSON.Encode.bool),
    //         ("cardsResult", cardsResult->Identity.anyTypeToJson),
    //         ("otp", otp->JSON.Encode.string),
    //       ]
    //       ->Dict.fromArray
    //       ->JSON.Encode.object
    //     // event.source->Window.sendPostMessageJSON(msg)
    //     mountedIframeRef->Window.iframePostMessage(msg)
    //   } catch {
    //   | _ => {
    //       let msg =
    //         [
    //           ("fetchedVisaCardsResult", true->JSON.Encode.bool),
    //           ("error", "Failed to fetch Visa cards"->JSON.Encode.string),
    //         ]
    //         ->Dict.fromArray
    //         ->JSON.Encode.object
    //       event.source->Window.sendPostMessageJSON(msg)
    //     }
    //   }
    // }

    // let handleInitializeVisaClickToPay = async (
    //   ~initConfig,
    //   ~event,
    //   ~identityValue,
    //   ~otp,
    //   ~identityType,
    // ) => {
    //   try {
    //     Console.log2("===> Initializing Visa Click to Pay", ClickToPayHelpers.vsdk)

    //     let _ = await ClickToPayHelpers.vsdk.initialize(initConfig)

    //     let msg =
    //       [
    //         ("initializedClickToPay", true->JSON.Encode.bool),
    //         ("identityValue", identityValue->JSON.Encode.string),
    //         ("otp", otp->JSON.Encode.string),
    //         ("identityType", identityType->JSON.Encode.string),
    //       ]
    //       ->Dict.fromArray
    //       ->JSON.Encode.object
    //     event.source->Window.sendPostMessageJSON(msg)
    //   } catch {
    //   | _ => {
    //       let msg =
    //         [
    //           ("initializedClickToPay", true->JSON.Encode.bool),
    //           ("error", "Failed to initialize Click to Pay"->JSON.Encode.string),
    //         ]
    //         ->Dict.fromArray
    //         ->JSON.Encode.object
    //       event.source->Window.sendPostMessageJSON(msg)
    //     }
    //   }
    // }

    // let handleVisaClickToPayMounted = (event: Types.event) => {
    //   let json = event.data->anyTypeToJson
    //   let dict = json->getDictFromJson
    //   let componentName = getString(dict, "componentName", "payment")

    //   if dict->Dict.get("loadClickToPayScript")->Option.isSome {
    //     let clickToPayToken =
    //       dict
    //       ->Dict.get("clickToPayToken")
    //       ->Option.getOr(JSON.Encode.null)
    //       ->ClickToPayHelpers.clickToPayTokenItemToObjMapper

    //     ClickToPayHelpers.loadVisaScript(
    //       clickToPayToken,
    //       () => {
    //         Console.log("===> Click to Pay Script Loaded")
    //         let msg =
    //           [
    //             ("finishLoadingClickToPayScript", true->JSON.Encode.bool),
    //             (
    //               "clickToPayToken",
    //               clickToPayToken->ClickToPayHelpers.clickToPayToJsonItemToObjMapper,
    //             ),
    //           ]
    //           ->Dict.fromArray
    //           ->JSON.Encode.object
    //         event.source->Window.sendPostMessageJSON(msg)
    //         // visaScriptOnLoadCallback(ctpToken)
    //       },
    //       () => {
    //         Console.log("===> Failed to Load the script")
    //         let msg =
    //           [
    //             ("finishLoadingClickToPayScript", true->JSON.Encode.bool),
    //             ("clickToPayLoadFailure", true->JSON.Encode.bool),
    //           ]
    //           ->Dict.fromArray
    //           ->JSON.Encode.object
    //         event.source->Window.sendPostMessageJSON(msg)

    //         // setClickToPayNotReady()
    //         // loggerState.setLogError(
    //         //   ~value={
    //         //     "message": "CTP UI script loading failed",
    //         //     "scheme": clickToPayProvider,
    //         //   }
    //         //   ->JSON.stringifyAny
    //         //   ->Option.getOr(""),
    //         //   ~eventName=CLICK_TO_PAY_FLOW,
    //         // )
    //       },
    //     )
    //   } else if dict->Dict.get("initializeVisaClickToPay")->Option.isSome {
    //     let clickToPayToken =
    //       dict
    //       ->Dict.get("clickToPayToken")
    //       ->Option.getOr(JSON.Encode.null)
    //       ->ClickToPayHelpers.clickToPayTokenItemToObjMapper

    //     let clientSecret = dict->getOptionString("clientSecret")

    //     let initConfig = ClickToPayHelpers.getVisaInitConfig(clickToPayToken, clientSecret)

    //     let identityValue = dict->getString("identityValue", "")
    //     let otp = dict->getString("otp", "")
    //     let identityType = dict->getString("identityType", "EMAIL_ADDRESS")

    //     Console.log("===> Trying to Initialize Visa Click to Pay At Top Level")

    //     handleInitializeVisaClickToPay(
    //       ~initConfig,
    //       ~event,
    //       ~identityValue,
    //       ~otp,
    //       ~identityType,
    //     )->ignore
    //   } else if dict->Dict.get("getVisaCards")->Option.isSome {
    //     let identityValue = dict->getString("identityValue", "")
    //     let otp = dict->getString("otp", "")
    //     let identityType =
    //       dict
    //       ->getString("identityType", "EMAIL_ADDRESS")
    //       ->ClickToPayHelpers.getIdentityTypeFromString

    //     handleVisaGetCards(~identityValue, ~otp, ~identityType, ~event)->ignore
    //   }
    // }

    // addSmartEventListener("message", handleVisaClickToPayMounted, "onVisaClickToPayMount")

    let setElementIframeRef = ref => {
      iframeRef->Array.push(ref)->ignore
      setIframeRef(ref)
    }
    let getElement = componentName => {
      savedPaymentElement->Dict.get(componentName)
    }
    let update = newOptions => {
      let newOptionsDict = newOptions->getDictFromJson
      switch newOptionsDict->Dict.get("locale") {
      | Some(val) => localOptions->Dict.set("locale", val)
      | None => ()
      }
      switch newOptionsDict->Dict.get("appearance") {
      | Some(val) => localOptions->Dict.set("appearance", val)
      | None => ()
      }

      iframeRef->Array.forEach(iframe => {
        let message =
          [
            ("ElementsUpdate", true->JSON.Encode.bool),
            ("options", newOptionsDict->JSON.Encode.object),
          ]->Dict.fromArray
        iframe->Window.iframePostMessage(message)
      })
    }
    let fetchUpdates = () => {
      Promise.make((resolve, _) => {
        setTimeout(() => resolve(Dict.make()->JSON.Encode.object), 1000)->ignore
      })
    }

    let create = (componentType, newOptions) => {
      componentType == "" ? manageErrorWarning(REQUIRED_PARAMETER, ~dynamicStr="type", ~logger) : ()
      let otherElements = componentType->isOtherElements
      switch componentType {
      | "savedCardElement" => ()
      | str => Console.warn(`Unknown Key: ${str} type in create`)
      }

      let mountPostMessage = (
        mountedIframeRef,
        selectorString,
        _sdkHandleOneClickConfirmPayment,
      ) => {
        open Promise

        let widgetOptions = [
          ("clientSecret", clientSecret->JSON.Encode.string),
          // ("authenticationClientSecret", clientSecret->JSON.Encode.string),
          ("appearance", appearance),
          ("locale", locale),
          ("loader", loader),
          ("fonts", fonts),
        ]->getJsonFromArrayOfJson
        let message = [
          (
            "paymentElementCreate",
            componentType->getIsComponentTypeForPaymentElementCreate->JSON.Encode.bool,
          ),
          ("otherElements", otherElements->JSON.Encode.bool),
          ("options", newOptions),
          ("componentType", componentType->JSON.Encode.string),
          ("paymentOptions", widgetOptions),
          ("iframeId", selectorString->JSON.Encode.string),
          ("publishableKey", publishableKey->JSON.Encode.string),
          ("profileId", profileId->JSON.Encode.string),
          ("endpoint", endpoint->JSON.Encode.string),
          ("sdkSessionId", sdkSessionId->JSON.Encode.string),
          ("customPodUri", customPodUri->JSON.Encode.string),
          ("parentURL", "*"->JSON.Encode.string),
          ("analyticsMetadata", analyticsMetadata),
          ("launchTime", launchTime->JSON.Encode.float),
          ("customBackendUrl", customBackendUrl->JSON.Encode.string),
          (
            "onSavedMethodChanged",
            EventListenerManager.eventListenerMap
            ->Dict.get("onSavedMethodChanged")
            ->Option.isSome
            ->JSON.Encode.bool,
          ),
          ("selectedPaymentToken", paymentTokenRef.contents->JSON.Encode.string),
        ]->Dict.fromArray

        preMountLoaderMountedPromise
        ->then(async _ => {
          let disableSavedPaymentMethods =
            newOptions
            ->getDictFromJson
            ->getBool("displaySavedPaymentMethods", true)
          if (
            disableSavedPaymentMethods &&
            !(expressCheckoutComponents->Array.includes(componentType))
          ) {
            try {
              await fetchEnabledAuthnMethodsToken(mountedIframeRef, false, componentType)
              let msg = [("cleanUpPreMountLoaderIframe", true->JSON.Encode.bool)]->Dict.fromArray
              preMountLoaderIframeDiv->Window.iframePostMessage(msg)
            } catch {
            | _ => ()
            }
          }
        })
        ->catch(_ => resolve())
        ->ignore
        mountedIframeRef->Window.iframePostMessage(message)

        // let fetchEnabledAuthnMethodsToken = (mountedIframeRef, disableSaveCards, componentType) => {
        //   Promise.make((resolve, _) => {
        //     if !disableSaveCards {
        //       let handleEnabledAuthnMethodsLoaded = (event: Types.event) => {
        //         let json = event.data->Identity.anyTypeToJson
        //         let dict = json->getDictFromJson
        //         let isEnabledAuthnMethodsData =
        //           dict->getString("data", "") === "enabled_authn_methods_token"
        //         if isEnabledAuthnMethodsData {
        //           resolve()
        //           let json = dict->getJsonFromDict("response", JSON.Encode.null)
        //           let msg = [("enabledAuthnMethodsToken", json)]->Dict.fromArray
        //           mountedIframeRef->Window.iframePostMessage(msg)
        //         }
        //       }
        //       addSmartEventListener(
        //         "message",
        //         handleEnabledAuthnMethodsLoaded,
        //         `onEnabledAuthnMethodsLoaded-${componentType}`,
        //       )
        //     } else {
        //       resolve()
        //     }
        //     let msg =
        //       [
        //         ("sendEnabledAuthnMethodsTokenResponse", !disableSaveCards->JSON.Encode.bool),
        //       ]->Dict.fromArray
        //     preMountLoaderIframeDiv->Window.iframePostMessage(msg)
        //   })
        // }

        let handleVisaGetCards = async (
          ~identityValue,
          ~otp,
          ~identityType,
          ~event,
          ~doSignOut=false,
        ) => {
          try {
            if doSignOut {
              switch initConfigRef.contents->Nullable.toOption {
              | Some(initConfig) => {
                  visaGetCardsResponse := Nullable.null
                  let _ = await ClickToPayHelpers.signOutVisaUnified()
                  let _ = await ClickToPayHelpers.vsdk.initialize(initConfig)
                }
              | None => ()
              }
            }
            switch visaGetCardsResponse.contents->Nullable.toOption {
            | Some(cardsResult) => {
                let msg =
                  [
                    ("fetchedVisaCardsResult", true->JSON.Encode.bool),
                    ("cardsResult", cardsResult->Identity.anyTypeToJson),
                    ("otp", otp->JSON.Encode.string),
                  ]->Dict.fromArray
                // event.source->Window.sendPostMessageJSON(msg)
                mountedIframeRef->Window.iframePostMessage(msg)
              }
            | None => {
                let cardsResult = await ClickToPayHelpers.getCardsVisaUnified(
                  ~identityValue,
                  ~otp,
                  ~identityType,
                )

                if cardsResult.actionCode == SUCCESS {
                  visaGetCardsResponse := Nullable.make(cardsResult)
                }
                let msg =
                  [
                    ("fetchedVisaCardsResult", true->JSON.Encode.bool),
                    ("cardsResult", cardsResult->Identity.anyTypeToJson),
                    ("otp", otp->JSON.Encode.string),
                  ]->Dict.fromArray
                // event.source->Window.sendPostMessageJSON(msg)
                mountedIframeRef->Window.iframePostMessage(msg)
              }
            }

            // let cardsResult = await ClickToPayHelpers.getCardsVisaUnified(
            //   ~identityValue,
            //   ~otp,
            //   ~identityType,
            // )
            // Console.log2("Cards Result", cardsResult)
            // let msg =
            //   [
            //     ("fetchedVisaCardsResult", true->JSON.Encode.bool),
            //     ("cardsResult", cardsResult->Identity.anyTypeToJson),
            //     ("otp", otp->JSON.Encode.string),
            //   ]->Dict.fromArray
            // // event.source->Window.sendPostMessageJSON(msg)
            // mountedIframeRef->Window.iframePostMessage(msg)
          } catch {
          | _ => {
              let msg =
                [
                  ("fetchedVisaCardsResult", true->JSON.Encode.bool),
                  ("error", "Failed to fetch Visa cards"->JSON.Encode.string),
                ]->Dict.fromArray
              // event.source->Window.sendPostMessageJSON(msg)
              mountedIframeRef->Window.iframePostMessage(msg)
            }
          }
        }

        let handleInitializeVisaClickToPay = async (
          ~initConfig,
          ~event,
          ~identityValue,
          ~otp,
          ~identityType,
        ) => {
          let handleSuccessPostMessage = () => {
            let msg =
              [
                ("initializedClickToPay", true->JSON.Encode.bool),
                ("identityValue", identityValue->JSON.Encode.string),
                ("otp", otp->JSON.Encode.string),
                ("identityType", identityType->JSON.Encode.string),
              ]->Dict.fromArray
            // ->JSON.Encode.object
            // event.source->Window.sendPostMessageJSON(msg)
            mountedIframeRef->Window.iframePostMessage(msg)
          }

          let handleErrorPostMessage = () => {
            let msg =
              [
                ("initializedClickToPay", true->JSON.Encode.bool),
                ("error", "Failed to initialize Click to Pay"->JSON.Encode.string),
              ]->Dict.fromArray
            // event.source->Window.sendPostMessageJSON(msg)
            mountedIframeRef->Window.iframePostMessage(msg)
          }

          try {
            if !isVisaInitialized.contents {
              initConfigRef := Nullable.make(initConfig)
              let timeOut = delay(15000)->then(_ => {
                let errorMsg =
                  [("error", "Request Timed Out"->JSON.Encode.string)]->getJsonFromArrayOfJson
                reject(Exn.anyToExnInternal(errorMsg))
              })

              Promise.race([ClickToPayHelpers.vsdk.initialize(initConfig), timeOut])
              ->then(_ => {
                isVisaInitialized := true
                handleSuccessPostMessage()
                resolve()
              })
              ->catch(_ => {
                handleErrorPostMessage()
                resolve()
              })
              ->ignore
            } else {
              handleSuccessPostMessage()
            }
          } catch {
          | err => {
              Console.log2("===> Error", err)
              handleErrorPostMessage()
            }
          }
        }

        let handleVisaClickToPayMounted = (event: Types.event) => {
          let json = event.data->anyTypeToJson
          let dict = json->getDictFromJson
          let componentName = getString(dict, "componentName", "payment")

          if dict->Dict.get("loadClickToPayScript")->Option.isSome {
            let clickToPayToken =
              dict
              ->Dict.get("clickToPayToken")
              ->Option.getOr(JSON.Encode.null)
              ->ClickToPayHelpers.clickToPayTokenItemToObjMapper

            if isVisaScriptLoaded.contents {
              let msg =
                [
                  ("finishLoadingClickToPayScript", true->JSON.Encode.bool),
                  (
                    "clickToPayToken",
                    clickToPayToken->ClickToPayHelpers.clickToPayToJsonItemToObjMapper,
                  ),
                ]->Dict.fromArray
              mountedIframeRef->Window.iframePostMessage(msg)
            } else {
              ClickToPayHelpers.loadVisaScript(
                clickToPayToken,
                () => {
                  isVisaScriptLoaded := true
                  let msg =
                    [
                      ("finishLoadingClickToPayScript", true->JSON.Encode.bool),
                      (
                        "clickToPayToken",
                        clickToPayToken->ClickToPayHelpers.clickToPayToJsonItemToObjMapper,
                      ),
                    ]->Dict.fromArray
                  // ->JSON.Encode.object
                  // event.source->Window.sendPostMessageJSON(msg)
                  mountedIframeRef->Window.iframePostMessage(msg)
                  // visaScriptOnLoadCallback(ctpToken)
                },
                () => {
                  let msg =
                    [
                      ("finishLoadingClickToPayScript", true->JSON.Encode.bool),
                      ("clickToPayLoadFailure", true->JSON.Encode.bool),
                    ]->Dict.fromArray
                  // event.source->Window.sendPostMessageJSON(msg)
                  mountedIframeRef->Window.iframePostMessage(msg)

                  // setClickToPayNotReady()
                  // loggerState.setLogError(
                  //   ~value={
                  //     "message": "CTP UI script loading failed",
                  //     "scheme": clickToPayProvider,
                  //   }
                  //   ->JSON.stringifyAny
                  //   ->Option.getOr(""),
                  //   ~eventName=CLICK_TO_PAY_FLOW,
                  // )
                },
              )
            }
          } else if dict->Dict.get("initializeVisaClickToPay")->Option.isSome {
            let clickToPayToken =
              dict
              ->Dict.get("clickToPayToken")
              ->Option.getOr(JSON.Encode.null)
              ->ClickToPayHelpers.clickToPayTokenItemToObjMapper

            let clientSecret = dict->getOptionString("clientSecret")

            let initConfig = ClickToPayHelpers.getVisaInitConfig(clickToPayToken, clientSecret)

            let identityValue = dict->getString("identityValue", "")
            let otp = dict->getString("otp", "")
            let identityType = dict->getString("identityType", "EMAIL_ADDRESS")

            handleInitializeVisaClickToPay(
              ~initConfig,
              ~event,
              ~identityValue,
              ~otp,
              ~identityType,
            )->ignore
          } else if dict->Dict.get("getVisaCards")->Option.isSome {
            let identityValue = dict->getString("identityValue", "")
            let otp = dict->getString("otp", "")
            let doSignOut = dict->getBool("signOut", false)
            let identityType =
              dict
              ->getString("identityType", "EMAIL_ADDRESS")
              ->ClickToPayHelpers.getIdentityTypeFromString

            handleVisaGetCards(~identityValue, ~otp, ~identityType, ~event, ~doSignOut)->ignore
          } else if dict->Dict.get("onSavedMethodChanged")->Option.isSome {
            let paymentToken = dict->Utils.getString("paymentToken", "")
            let clickToPayToken = dict->Utils.getJsonFromDict("clickToPayToken", JSON.Encode.null)
            let clickToPayProvider = dict->Utils.getString("clickToPayProvider", "")
            let isClickToPayRememberMe = dict->Utils.getBool("isClickToPayRememberMe", false)

            paymentTokenRef := paymentToken
            clickToPayTokenRef := clickToPayToken
            clickToPayProviderRef := clickToPayProvider
            isClickToPayRememberMeRef := isClickToPayRememberMe
          } else if dict->Dict.get("handleClickToPayAuthentication")->Option.isSome {
            let paymentToken = paymentTokenRef.contents
            let clickToPayToken =
              clickToPayTokenRef.contents->ClickToPayHelpers.clickToPayTokenItemToObjMapper
            let clickToPayProvider =
              clickToPayProviderRef.contents->ClickToPayHelpers.getCtpProvider
            let isClickToPayRememberMe = isClickToPayRememberMeRef.contents

            ClickToPayHelpers.handleProceedToPay(
              ~srcDigitalCardId=paymentToken,
              ~logger,
              ~clickToPayProvider,
              ~isClickToPayRememberMe,
              ~clickToPayToken=Some(clickToPayToken),
              ~orderId=clientSecret,
            )
            ->then(resp => {
              let msg =
                [
                  ("handleClickToPayAuthenticationComplete", true->JSON.Encode.bool),
                  ("payload", resp.payload),
                  ("email", clickToPayToken.email->JSON.Encode.string),
                  ("clickToPayProvider", clickToPayProviderRef.contents->JSON.Encode.string),
                  ("publishableKey", publishableKey->JSON.Encode.string),
                  ("customPodUri", customPodUri->JSON.Encode.string),
                  ("clientSecret", clientSecret->JSON.Encode.string),
                  ("authenticationId", authenticationId->JSON.Encode.string),
                  ("profileId", profileId->JSON.Encode.string),
                  ("endpoint", endpoint->JSON.Encode.string),
                ]->Dict.fromArray

              event.source->Window.sendPostMessage(msg)
              // mountedIframeRef->Window.iframePostMessage(msg)
              resolve()
            })
            ->ignore
            ()
          } else if dict->Dict.get("resetSelectedSavedMethod")->Option.isSome {
            paymentTokenRef := ""
            clickToPayTokenRef := JSON.Encode.null
            clickToPayProviderRef := ""
            isClickToPayRememberMeRef := false
          }
        }

        addSmartEventListener("message", handleVisaClickToPayMounted, "onVisaClickToPayMount")
      }

      let paymentElement = LoaderPaymentElement.make(
        componentType,
        newOptions,
        setElementIframeRef,
        iframeRef,
        mountPostMessage,
        ~isAuthenticationSessionElements=true,
        ~redirectionFlags=RecoilAtoms.defaultRedirectionFlags,
      )
      savedPaymentElement->Dict.set(componentType, paymentElement)
      paymentElement
    }
    {
      getElement,
      update,
      fetchUpdates,
      create,
    }
  } catch {
  | e => {
      Sentry.captureException(e)
      defaultElement
    }
  }
}
