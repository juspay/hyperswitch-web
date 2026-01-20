open Utils
@react.component
let make = (~children, ~paymentMode, ~setIntegrateErrorError, ~logger, ~initTimestamp) => {
  open RecoilAtoms
  open RecoilAtomsV2

  let (configAtom, setConfig) = Recoil.useRecoilState(configAtom)
  let (keys, setKeys) = Recoil.useRecoilState(keys)
  let (paymentMethodList, setPaymentMethodList) = Recoil.useRecoilState(paymentMethodList)
  let (_, setSessions) = Recoil.useRecoilState(sessions)
  let setBlockedBins = Recoil.useSetRecoilState(blockedBins)
  let (options, setOptions) = Recoil.useRecoilState(elementOptions)
  let (optionsPayment, setOptionsPayment) = Recoil.useRecoilState(optionAtom)
  let setPaymentManagementList = Recoil.useSetRecoilState(paymentManagementList)
  let setPaymentMethodsListV2 = Recoil.useSetRecoilState(paymentMethodsListV2)
  let setIntentList = Recoil.useSetRecoilState(intentList)
  let setSessionId = Recoil.useSetRecoilState(sessionId)
  let setBlockConfirm = Recoil.useSetRecoilState(isConfirmBlocked)
  let setCustomPodUri = Recoil.useSetRecoilState(customPodUri)
  let setIsGooglePayReady = Recoil.useSetRecoilState(isGooglePayReady)
  let setTrustPayScriptStatus = Recoil.useSetRecoilState(trustPayScriptStatus)
  let setIsApplePayReady = Recoil.useSetRecoilState(isApplePayReady)
  let setIsSamsungPayReady = Recoil.useSetRecoilState(isSamsungPayReady)
  let setUpdateSession = Recoil.useSetRecoilState(updateSession)
  let (divH, setDivH) = React.useState(_ => 0.0)
  let (launchTime, setLaunchTime) = React.useState(_ => 0.0)
  let {paymentMethodOrder} = optionsPayment
  let (_, setPaymentMethodCollectOptions) = Recoil.useRecoilState(paymentMethodCollectOptionAtom)
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")

  let divRef = React.useRef(Nullable.null)

  let {config} = configAtom
  let {iframeId} = keys

  let messageParentWindow = data => messageParentWindow(data, ~targetOrigin=keys.parentURL)

  let setUserFullName = Recoil.useSetRecoilState(userFullName)
  let setUserEmail = Recoil.useSetRecoilState(userEmailAddress)
  let setUserAddressline1 = Recoil.useSetRecoilState(userAddressline1)
  let setUserAddressline2 = Recoil.useSetRecoilState(userAddressline2)
  let setUserAddressCity = Recoil.useSetRecoilState(userAddressCity)
  let setUserAddressPincode = Recoil.useSetRecoilState(userAddressPincode)
  let setUserAddressState = Recoil.useSetRecoilState(userAddressState)
  let setUserAddressCountry = Recoil.useSetRecoilState(userAddressCountry)
  let setCountry = Recoil.useSetRecoilState(userCountry)
  let setIsCompleteCallbackUsed = Recoil.useSetRecoilState(isCompleteCallbackUsed)
  let setIsPaymentButtonHandlerProvided = Recoil.useSetRecoilState(
    isPaymentButtonHandlerProvidedAtom,
  )

  let optionsCallback = (optionsPayment: PaymentType.options) => {
    [
      (optionsPayment.defaultValues.billingDetails.name, setUserFullName),
      (optionsPayment.defaultValues.billingDetails.email, setUserEmail),
      (optionsPayment.defaultValues.billingDetails.address.line1, setUserAddressline1),
      (optionsPayment.defaultValues.billingDetails.address.line2, setUserAddressline2),
      (optionsPayment.defaultValues.billingDetails.address.city, setUserAddressCity),
      (optionsPayment.defaultValues.billingDetails.address.postal_code, setUserAddressPincode),
      (optionsPayment.defaultValues.billingDetails.address.state, setUserAddressState),
      (optionsPayment.defaultValues.billingDetails.address.country, setUserAddressCountry),
    ]->Array.forEach(val => {
      let (value, setValue) = val
      if value != "" {
        setValue(prev => {
          ...prev,
          value,
        })
      }
    })
    if optionsPayment.defaultValues.billingDetails.address.country === "" {
      let clientTimeZone = CardUtils.dateTimeFormat().resolvedOptions().timeZone
      let clientCountry = getClientCountry(clientTimeZone)
      setUserAddressCountry(prev => {
        ...prev,
        value: clientCountry.countryName,
      })
      setCountry(_ => clientCountry.countryName)
    } else {
      setUserAddressCountry(prev => {
        ...prev,
        value: optionsPayment.defaultValues.billingDetails.address.country,
      })
      setCountry(_ => optionsPayment.defaultValues.billingDetails.address.country)
    }
  }

  let updateOptions = dict => {
    let optionsDict = dict->getDictFromObj("options")
    switch paymentMode->CardThemeType.getPaymentMode {
    | CardNumberElement
    | CardExpiryElement
    | CardCVCElement
    | Card =>
      setOptions(_ => ElementType.itemToObjMapper(optionsDict, logger))
    | PaymentMethodCollectElement => {
        let paymentMethodCollectOptions = PaymentMethodCollectUtils.itemToObjMapper(optionsDict)
        setPaymentMethodCollectOptions(_ => paymentMethodCollectOptions)
      }
    | GooglePayElement
    | PayPalElement
    | ApplePayElement
    | SamsungPayElement
    | KlarnaElement
    | PazeElement
    | ExpressCheckoutElement
    | PaymentMethodsManagement
    | Payment => {
        let paymentOptions = PaymentType.itemToObjMapper(optionsDict, logger)
        setOptionsPayment(_ => paymentOptions)
        optionsCallback(paymentOptions)
      }
    | _ => ()
    }
  }

  let setConfigs = async (dict, themeValues: ThemeImporter.themeDataModule) => {
    try {
      let paymentOptions = dict->getDictFromObj("paymentOptions")
      let optionsDict = dict->getDictFromObj("options")
      let (default, defaultRules) = (themeValues.default, themeValues.defaultRules)
      let config = CardTheme.itemToObjMapper(paymentOptions, default, defaultRules, logger)
      let optionsLocaleString = getWarningString(optionsDict, "locale", "", ~logger)
      let optionsAppearance = CardTheme.getAppearance(
        "appearance",
        optionsDict,
        default,
        defaultRules,
        logger,
      )
      let appearance =
        optionsAppearance == CardTheme.defaultAppearance ? config.appearance : optionsAppearance
      let localeString = await CardTheme.getLocaleObject(
        optionsLocaleString == "" ? config.locale : optionsLocaleString,
      )
      let constantString = await CardTheme.getConstantStringsObject()
      let _ = await S3Utils.initializeCountryData(~locale=config.locale, ~logger)
      setConfig(_ => {
        config: {
          appearance,
          locale: config.locale === "auto" ? Window.Navigator.language : config.locale,
          fonts: config.fonts,
          clientSecret: config.clientSecret,
          ephemeralKey: config.ephemeralKey,
          pmClientSecret: config.pmClientSecret,
          pmSessionId: config.pmSessionId,
          loader: config.loader,
        },
        themeObj: appearance.variables,
        localeString,
        constantString,
        showLoader: config.loader == Auto || config.loader == Always,
      })
    } catch {
    | _ => ()
    }
  }

  let updateRedirectionFlags = UtilityHooks.useUpdateRedirectionFlags()

  React.useEffect0(() => {
    messageParentWindow([("iframeMounted", true->JSON.Encode.bool)])
    messageParentWindow([
      ("applePayMounted", true->JSON.Encode.bool),
      ("componentName", componentName->JSON.Encode.string),
    ])
    logger.setLogInitiated()
    let updatedState: PaymentType.loadType = switch paymentMethodList {
    | Loading => checkPriorityList(paymentMethodOrder) ? SemiLoaded : Loading
    | x => x
    }
    let finalLoadLatency = if launchTime <= 0.0 {
      0.0
    } else {
      Date.now() -. launchTime
    }
    switch updatedState {
    | Loaded(_) =>
      logger.setLogInfo(~value="Loaded", ~eventName=LOADER_CHANGED, ~latency=finalLoadLatency)
    | Loading =>
      logger.setLogInfo(~value="Loading", ~eventName=LOADER_CHANGED, ~latency=finalLoadLatency)
    | SemiLoaded => {
        setPaymentMethodList(_ => updatedState)
        logger.setLogInfo(~value="SemiLoaded", ~eventName=LOADER_CHANGED, ~latency=finalLoadLatency)
      }
    | LoadError(x) =>
      logger.setLogError(
        ~value="LoadError: " ++ x->JSON.stringify,
        ~eventName=LOADER_CHANGED,
        ~latency=finalLoadLatency,
      )
    }
    Window.addEventListener("click", ev =>
      handleOnClickPostMessage(~targetOrigin=keys.parentURL, ev)
    )
    Some(
      () => {
        Window.removeEventListener("click", ev =>
          handleOnClickPostMessage(~targetOrigin=keys.parentURL, ev)
        )
      },
    )
  })

  React.useEffect(() => {
    CardUtils.generateFontsLink(config.fonts)
    let dict = config.appearance.rules->getDictFromJson
    if dict->Dict.toArray->Array.length > 0 {
      generateStyleSheet("", dict, "themestyle")
    }
    switch paymentMode->CardThemeType.getPaymentMode {
    | Payment => ()
    | _ =>
      let styleClass = [
        ("input-base", options.style.base->getDictFromJson),
        ("input-complete", options.style.complete->getDictFromJson),
        ("input-invalid", options.style.invalid->getDictFromJson),
        ("input-empty", options.style.empty->getDictFromJson),
      ]
      styleClass
      ->Array.map(item => {
        let (class, dict) = item
        if dict->Dict.toArray->Array.length > 0 {
          generateStyleSheet(class, dict, "widgetstyle")->ignore
        }
      })
      ->ignore
    }
    None
  }, [config])

  React.useEffect(() => {
    open Promise
    let handleFun = (ev: Window.event) => {
      let json = ev.data->safeParse
      try {
        let dict = json->getDictFromJson
        if dict->getDictIsSome("paymentElementCreate") {
          if (
            dict
            ->Dict.get("paymentElementCreate")
            ->Option.flatMap(JSON.Decode.bool)
            ->Option.getOr(false)
          ) {
            if (
              dict->Dict.get("otherElements")->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)
            ) {
              updateOptions(dict)
            } else {
              let sdkSessionId = dict->getString("sdkSessionId", "no-element")
              logger.setSessionId(sdkSessionId)
              if GlobalVars.isInteg {
                setBlockConfirm(_ => dict->getBool("blockConfirm", false))
              }
              setCustomPodUri(_ => dict->getString("customPodUri", ""))
              updateOptions(dict)
              setSessionId(_ => {
                sdkSessionId
              })
              if dict->getDictIsSome("publishableKey") {
                let publishableKey = dict->getString("publishableKey", "")
                logger.setMerchantId(publishableKey)
              }
              if dict->getDictIsSome("analyticsMetadata") {
                let metadata = dict->getJsonObjectFromDict("analyticsMetadata")
                logger.setMetadata(metadata)
              }

              if dict->getDictIsSome("onCompleteDoThisUsed") {
                let isCallbackUsedVal = dict->Utils.getBool("onCompleteDoThisUsed", false)
                setIsCompleteCallbackUsed(_ => isCallbackUsedVal)
              }
              if dict->getDictIsSome("isPaymentButtonHandlerProvided") {
                let isSDKClick = dict->Utils.getBool("isPaymentButtonHandlerProvided", false)
                setIsPaymentButtonHandlerProvided(_ => isSDKClick)
              }
              if dict->getDictIsSome("paymentOptions") {
                let paymentOptions = dict->getDictFromObj("paymentOptions")

                let clientSecret = getWarningString(paymentOptions, "clientSecret", "", ~logger)
                let ephemeralKey = getWarningString(paymentOptions, "ephemeralKey", "", ~logger)
                let pmClientSecret = getWarningString(paymentOptions, "pmClientSecret", "", ~logger)
                let pmSessionId = getWarningString(paymentOptions, "pmSessionId", "", ~logger)
                setKeys(prev => {
                  ...prev,
                  clientSecret: Some(clientSecret),
                  ephemeralKey,
                  pmClientSecret,
                  pmSessionId,
                })
                logger.setClientSecret(clientSecret)

                // Update top redirection atom
                updateRedirectionFlags(paymentOptions)

                switch getThemePromise(paymentOptions) {
                | Some(promise) =>
                  promise
                  ->then(res => {
                    dict->setConfigs(res)
                  })
                  ->catch(_ => {
                    dict->setConfigs({
                      default: DefaultTheme.default,
                      defaultRules: DefaultTheme.defaultRules,
                    })
                  })
                | None =>
                  dict->setConfigs({
                    default: DefaultTheme.default,
                    defaultRules: DefaultTheme.defaultRules,
                  })
                }->ignore
              }
              let newLaunchTime = dict->getFloat("launchTime", 0.0)
              setLaunchTime(_ => newLaunchTime)
              let initLoadlatency = Date.now() -. newLaunchTime
              logger.setLogInfo(
                ~value=Window.hrefWithoutSearch,
                ~eventName=APP_RENDERED,
                ~latency=initLoadlatency,
              )
              [
                ("iframeId", "no-element"->JSON.Encode.string),
                ("publishableKey", ""->JSON.Encode.string),
                ("profileId", ""->JSON.Encode.string),
                ("paymentId", ""->JSON.Encode.string),
                ("parentURL", "*"->JSON.Encode.string),
                ("sdkHandleOneClickConfirmPayment", true->JSON.Encode.bool),
              ]->Array.forEach(keyPair => {
                dict->CommonHooks.updateKeys(keyPair, setKeys)
              })
              let renderLatency = Date.now() -. initTimestamp
              logger.setLogInfo(
                ~eventName=PAYMENT_OPTIONS_PROVIDED,
                ~latency=renderLatency,
                ~value="",
              )
            }
          } else if dict->getDictIsSome("paymentOptions") {
            let paymentOptions = dict->getDictFromObj("paymentOptions")

            let clientSecret = getWarningString(paymentOptions, "clientSecret", "", ~logger)
            let ephemeralKey = getWarningString(paymentOptions, "ephemeralKey", "", ~logger)
            let pmClientSecret = getWarningString(paymentOptions, "pmClientSecret", "", ~logger)
            let pmSessionId = getWarningString(paymentOptions, "pmSessionId", "", ~logger)
            setKeys(prev => {
              ...prev,
              clientSecret: Some(clientSecret),
              ephemeralKey,
              pmClientSecret,
              pmSessionId,
            })
            logger.setClientSecret(clientSecret)

            // Update top redirection atom
            updateRedirectionFlags(paymentOptions)

            switch getThemePromise(paymentOptions) {
            | Some(promise) =>
              promise
              ->then(res => {
                dict->setConfigs(res)
              })
              ->catch(_ => {
                dict->setConfigs({
                  default: DefaultTheme.default,
                  defaultRules: DefaultTheme.defaultRules,
                })
              })

            | None =>
              dict->setConfigs({
                default: DefaultTheme.default,
                defaultRules: DefaultTheme.defaultRules,
              })
            }->ignore
          }
        } else if dict->getDictIsSome("paymentElementsUpdate") {
          updateOptions(dict)
        } else if dict->getDictIsSome("ElementsUpdate") {
          let optionsDict = dict->getDictFromObj("options")
          let clientSecret = dict->Dict.get("clientSecret")
          switch clientSecret {
          | Some(val) =>
            setKeys(prev => {
              ...prev,
              clientSecret: Some(val->getStringFromJson("")),
            })
            setConfig(prev => {
              ...prev,
              config: {
                ...prev.config,
                clientSecret: val->getStringFromJson(""),
              },
            })
          | None => ()
          }
          switch getThemePromise(optionsDict) {
          | Some(promise) =>
            promise
            ->then(res => {
              dict->setConfigs(res)
            })
            ->catch(_ => {
              dict->setConfigs({
                default: DefaultTheme.default,
                defaultRules: DefaultTheme.defaultRules,
              })
            })

          | None =>
            dict->setConfigs({
              default: DefaultTheme.default,
              defaultRules: DefaultTheme.defaultRules,
            })
          }->ignore
        }
        if dict->getDictIsSome("sessions") {
          setSessions(_ => Loaded(dict->getJsonObjectFromDict("sessions")))
        }
        if dict->getDictIsSome("sessionUpdate") {
          setUpdateSession(_ => {
            dict->getJsonObjectFromDict("sessionUpdate")->JSON.Decode.bool->Option.getOr(false)
          })
        }
        if dict->getDictIsSome("isReadyToPay") {
          setIsGooglePayReady(_ =>
            dict->getJsonObjectFromDict("isReadyToPay")->JSON.Decode.bool->Option.getOr(false)
          )
        }
        if dict->getDictIsSome("trustPayScriptStatus") {
          setTrustPayScriptStatus(_ => {
            switch dict->getString("trustPayScriptStatus", "") {
            | "loading" => Loading
            | "loaded" => Loaded
            | "failed" => Failed
            | _ => NotLoaded
            }
          })
        }
        if dict->getDictIsSome("isSamsungPayReady") {
          setIsSamsungPayReady(_ => dict->getBool("isSamsungPayReady", false))
        }
        if (
          dict->getDictIsSome("customBackendUrl") &&
            dict
            ->getString("customBackendUrl", "")
            ->String.length > 0
        ) {
          if dict->getDictIsSome("endpoint") {
            switch dict->getString("endpoint", "") {
            | "" => ()
            | endpoint => ApiEndpoint.setApiEndPoint(endpoint)
            }
          }
        }
        if dict->getDictIsSome("getIntent") {
          let getIntentDict = dict->getJsonObjectFromDict("getIntent")->getDictFromJson
          let intentDetails = getIntentDict->UnifiedHelpersV2.createIntentDetails("response")
          setIntentList(_ => intentDetails)
        }
        if dict->getDictIsSome("paymentsListV2") {
          let paymentsListV2 = dict->getJsonObjectFromDict("paymentsListV2")
          let listDict = paymentsListV2->getDictFromJson

          let updatedState: UnifiedPaymentsTypesV2.loadstate =
            paymentsListV2 == Dict.make()->JSON.Encode.object
              ? LoadErrorV2(paymentsListV2)
              : switch listDict->Dict.get("error") {
                | Some(_) => LoadErrorV2(paymentsListV2)
                | None =>
                  let isNonEmptyPaymentMethodList = switch listDict->Dict.get("response") {
                  | Some(val) =>
                    val->getDictFromJson->getArray("payment_methods_enabled")->Array.length > 0
                  | None => false
                  }
                  isNonEmptyPaymentMethodList
                    ? listDict->UnifiedHelpersV2.createPaymentsObjArr("response")
                    : LoadErrorV2(paymentsListV2)
                }

          let evalMethodsList = () =>
            switch updatedState {
            | LoadedV2(_) => Console.info("Loaded payment methods list v2")
            | LoadErrorV2(x) =>
              Console.error2("Error in loading payment methods list v2: ", x->JSON.stringify)
            | _ => ()
            }

          evalMethodsList()

          setPaymentMethodsListV2(_ => updatedState)
        }
        if dict->getDictIsSome("paymentMethodList") {
          let paymentMethodList = dict->getJsonObjectFromDict("paymentMethodList")
          let listDict = paymentMethodList->getDictFromJson
          if optionsPayment.business.name === "" {
            setOptionsPayment(prev => {
              ...prev,
              business: {
                name: listDict->getString("merchant_name", ""),
              },
            })
          }
          let finalLoadLatency = if launchTime <= 0.0 {
            0.0
          } else {
            Date.now() -. launchTime
          }
          let updatedState: PaymentType.loadType =
            paymentMethodList == Dict.make()->JSON.Encode.object
              ? LoadError(paymentMethodList)
              : switch listDict->Dict.get("error") {
                | Some(_) => LoadError(paymentMethodList)
                | None =>
                  let isNonEmptyPaymentMethodList =
                    listDict->getArray("payment_methods")->Array.length > 0
                  isNonEmptyPaymentMethodList
                    ? Loaded(paymentMethodList)
                    : LoadError(paymentMethodList)
                }

          let evalMethodsList = () =>
            switch updatedState {
            | Loaded(_) =>
              logger.setLogInfo(
                ~value="Loaded",
                ~eventName=LOADER_CHANGED,
                ~latency=finalLoadLatency,
              )
            | LoadError(x) =>
              logger.setLogError(
                ~value="LoadError: " ++ x->JSON.stringify,
                ~eventName=LOADER_CHANGED,
                ~latency=finalLoadLatency,
              )
            | _ => ()
            }

          if !optionsPayment.displaySavedPaymentMethods {
            evalMethodsList()
          } else {
            switch optionsPayment.customerPaymentMethods {
            | LoadingSavedCards => ()
            | LoadedSavedCards(list, _) =>
              list->Array.length > 0
                ? logger.setLogInfo(
                    ~value="Loaded",
                    ~eventName=LOADER_CHANGED,
                    ~latency=finalLoadLatency,
                  )
                : evalMethodsList()
            | NoResult(_) => evalMethodsList()
            }
          }

          setPaymentMethodList(_ => updatedState)
        }
        if dict->getDictIsSome("customerPaymentMethods") {
          let customerPaymentMethods =
            dict->PaymentType.createCustomerObjArr("customerPaymentMethods")
          setOptionsPayment(prev => {
            ...prev,
            customerPaymentMethods,
          })
          let finalLoadLatency = if launchTime <= 0.0 {
            0.0
          } else {
            Date.now() -. launchTime
          }

          let evalMethodsList = () =>
            switch paymentMethodList {
            | Loaded(_) =>
              logger.setLogInfo(
                ~value="Loaded",
                ~eventName=LOADER_CHANGED,
                ~latency=finalLoadLatency,
              )
            | LoadError(x) =>
              logger.setLogError(
                ~value="LoadError: " ++ x->JSON.stringify,
                ~eventName=LOADER_CHANGED,
                ~latency=finalLoadLatency,
              )
            | _ => ()
            }

          switch optionsPayment.customerPaymentMethods {
          | LoadingSavedCards => ()
          | LoadedSavedCards(list, _) =>
            if list->Array.length > 0 {
              logger.setLogInfo(
                ~value="Loaded",
                ~eventName=LOADER_CHANGED,
                ~latency=finalLoadLatency,
              )
            } else {
              evalMethodsList()
            }
          | NoResult(_) => evalMethodsList()
          }
        }
        if dict->getDictIsSome("savedPaymentMethods") {
          let savedPaymentMethods = dict->PaymentType.createCustomerObjArr("savedPaymentMethods")
          setOptionsPayment(prev => {
            ...prev,
            savedPaymentMethods,
          })
          let finalLoadLatency = if launchTime <= 0.0 {
            -1.0
          } else {
            Date.now() -. launchTime
          }

          let evalMethodsList = () =>
            switch paymentMethodList {
            | Loaded(_) =>
              logger.setLogInfo(
                ~value="Loaded",
                ~eventName=LOADER_CHANGED,
                ~latency=finalLoadLatency,
              )
            | LoadError(x) =>
              logger.setLogError(
                ~value="LoadError: " ++ x->JSON.stringify,
                ~eventName=LOADER_CHANGED,
                ~latency=finalLoadLatency,
              )

            | _ => ()
            }

          switch optionsPayment.customerPaymentMethods {
          | LoadingSavedCards => ()
          | LoadedSavedCards(list, _) =>
            if list->Array.length > 0 {
              logger.setLogInfo(
                ~value="Loaded",
                ~eventName=LOADER_CHANGED,
                ~latency=finalLoadLatency,
              )
            } else {
              evalMethodsList()
            }
          | NoResult(_) => evalMethodsList()
          }
        }
        if dict->getDictIsSome("paymentManagementMethods") {
          let paymentManagementMethods =
            dict->UnifiedHelpersV2.createPaymentsObjArr("paymentManagementMethods")
          setPaymentManagementList(_ => paymentManagementMethods)
        }
        if dict->Dict.get("applePayCanMakePayments")->Option.isSome {
          setIsApplePayReady(_ => true)
        }
        if dict->Dict.get("applePaySessionObjNotPresent")->Option.isSome {
          setIsApplePayReady(prev => prev && false)
        }
        if dict->getDictIsSome("blockedBins") {
          let blockedBins = dict->getJsonObjectFromDict("blockedBins")
          setBlockedBins(_ => Loaded(blockedBins))
        }
      } catch {
      | _ => setIntegrateErrorError(_ => true)
      }
    }
    handleMessage(handleFun, "Error in parsing sent Data")
  }, (paymentMethodOrder, optionsPayment))

  let observer = ResizeObserver.newResizerObserver(entries => {
    entries
    ->Array.map(item => {
      setDivH(_ => item.contentRect.height)
    })
    ->ignore
  })
  switch divRef.current->Nullable.toOption {
  | Some(r) => observer.observe(r)
  | None => ()
  }

  React.useEffect(() => {
    let iframeHeight = divH->Float.equal(0.0) ? divH : divH +. 1.0
    messageParentWindow([
      ("iframeHeight", iframeHeight->JSON.Encode.float),
      ("iframeId", iframeId->JSON.Encode.string),
    ])
    None
  }, (divH, iframeId))

  <div ref={divRef->ReactDOM.Ref.domRef}> children </div>
}
