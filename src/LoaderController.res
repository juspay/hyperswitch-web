open Utils
@react.component
let make = (~children, ~paymentMode, ~setIntegrateErrorError, ~logger) => {
  open RecoilAtoms
  //<...>//
  let (configAtom, setConfig) = Recoil.useRecoilState(configAtom)
  let (keys, setKeys) = Recoil.useRecoilState(keys)
  let (paymentlist, setList) = Recoil.useRecoilState(list)
  let (_, setSessions) = Recoil.useRecoilState(sessions)
  let (options, setOptions) = Recoil.useRecoilState(elementOptions)
  let (optionsPayment, setOptionsPayment) = Recoil.useRecoilState(optionAtom)
  let setSessionId = Recoil.useSetRecoilState(sessionId)
  let setBlockConfirm = Recoil.useSetRecoilState(isConfirmBlocked)
  let setSwitchToCustomPod = Recoil.useSetRecoilState(switchToCustomPod)
  let setIsGooglePayReady = Recoil.useSetRecoilState(isGooglePayReady)
  let setIsApplePayReady = Recoil.useSetRecoilState(isApplePayReady)
  let (divH, setDivH) = React.useState(_ => 0.0)
  let {showCardFormByDefault, paymentMethodOrder} = optionsPayment

  let divRef = React.useRef(Nullable.null)

  let {config} = configAtom
  let {iframeId} = keys

  let handlePostMessage = data => Utils.handlePostMessage(data, ~targetOrigin=keys.parentURL)

  let setUserFullName = Recoil.useLoggedSetRecoilState(userFullName, "fullName", logger)
  let setUserEmail = Recoil.useLoggedSetRecoilState(userEmailAddress, "email", logger)
  let setUserAddressline1 = Recoil.useLoggedSetRecoilState(userAddressline1, "line1", logger)
  let setUserAddressline2 = Recoil.useLoggedSetRecoilState(userAddressline2, "line2", logger)
  let setUserAddressCity = Recoil.useLoggedSetRecoilState(userAddressCity, "city", logger)
  let setUserAddressPincode = Recoil.useLoggedSetRecoilState(userAddressPincode, "pin", logger)
  let setUserAddressState = Recoil.useLoggedSetRecoilState(userAddressState, "state", logger)
  let setUserAddressCountry = Recoil.useLoggedSetRecoilState(userAddressCountry, "country", logger)
  let (_country, setCountry) = Recoil.useRecoilState(userCountry)

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
      let clientCountry = Utils.getClientCountry(clientTimeZone)
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
    switch paymentMode->CardTheme.getPaymentMode {
    | CardNumberElement
    | CardExpiryElement
    | CardCVCElement
    | Card =>
      setOptions(_ => ElementType.itemToObjMapper(optionsDict, logger))
    | Payment => {
        let paymentOptions = PaymentType.itemToObjMapper(optionsDict, logger)
        setOptionsPayment(_ => paymentOptions)
        optionsCallback(paymentOptions)
      }
    | _ => ()
    }
  }

  let setConfigs = (dict, themeValues: ThemeImporter.themeDataModule) => {
    let paymentOptions = dict->getDictFromObj("paymentOptions")
    let optionsDict = dict->getDictFromObj("options")
    let (default, defaultRules) = (themeValues.default, themeValues.defaultRules)
    let config = CardTheme.itemToObjMapper(paymentOptions, default, defaultRules, logger)

    let localeString = Utils.getWarningString(optionsDict, "locale", "", ~logger)

    let optionsAppearance = CardTheme.getAppearance(
      "appearance",
      optionsDict,
      default,
      defaultRules,
      logger,
    )
    let appearance =
      optionsAppearance == CardTheme.defaultAppearance ? config.appearance : optionsAppearance

    setConfig(_ => {
      config: {
        appearance,
        locale: config.locale,
        fonts: config.fonts,
        clientSecret: config.clientSecret,
        loader: config.loader,
      },
      themeObj: appearance.variables,
      localeString: localeString == ""
        ? CardTheme.getLocaleObject(config.locale)
        : CardTheme.getLocaleObject(localeString),
      showLoader: config.loader == Auto || config.loader == Always,
    })
  }

  React.useEffect0(() => {
    handlePostMessage([("iframeMounted", true->JSON.Encode.bool)])
    handlePostMessage([("applePayMounted", true->JSON.Encode.bool)])
    logger.setLogInitiated()
    let updatedState: PaymentType.loadType = switch paymentlist {
    | Loading =>
      showCardFormByDefault && Utils.checkPriorityList(paymentMethodOrder) ? SemiLoaded : Loading
    | x => x
    }
    switch updatedState {
    | Loaded(_) => logger.setLogInfo(~value="Loaded", ~eventName=LOADER_CHANGED, ())
    | Loading => logger.setLogInfo(~value="Loading", ~eventName=LOADER_CHANGED, ())
    | SemiLoaded => {
        setList(_ => updatedState)
        logger.setLogInfo(~value="SemiLoaded", ~eventName=LOADER_CHANGED, ())
      }
    | LoadError(x) =>
      logger.setLogError(~value="LoadError: " ++ x->JSON.stringify, ~eventName=LOADER_CHANGED, ())
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
  React.useEffect1(() => {
    switch paymentlist {
    | SemiLoaded => ()
    | Loaded(_val) => handlePostMessage([("ready", true->JSON.Encode.bool)])
    | _ => handlePostMessage([("ready", false->JSON.Encode.bool)])
    }
    None
  }, [paymentlist])

  React.useEffect1(() => {
    CardUtils.genreateFontsLink(config.fonts)
    let dict = config.appearance.rules->getDictFromJson
    if dict->Dict.toArray->Array.length > 0 {
      Utils.generateStyleSheet("", dict, "themestyle")
    }
    switch paymentMode->CardTheme.getPaymentMode {
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
          Utils.generateStyleSheet(class, dict, "widgetstyle")->ignore
        }
      })
      ->ignore
    }
    None
  }, [config])

  React.useEffect2(() => {
    open Promise
    let handleFun = (ev: Window.event) => {
      let json = try {
        ev.data->JSON.parseExn
      } catch {
      | _ => Dict.make()->JSON.Encode.object
      }
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
              if Window.isInteg {
                setBlockConfirm(_ => dict->getBool("blockConfirm", false))
                setSwitchToCustomPod(_ => dict->getBool("switchToCustomPod", false))
              }
              updateOptions(dict)
              setSessionId(_ => {
                sdkSessionId
              })
              if dict->getDictIsSome("publishableKey") {
                let publishableKey = dict->getString("publishableKey", "")
                logger.setMerchantId(publishableKey)
              }

              if dict->getDictIsSome("endpoint") {
                let endpoint = dict->getString("endpoint", "")
                ApiEndpoint.setApiEndPoint(endpoint)
              }
              if dict->getDictIsSome("analyticsMetadata") {
                let metadata = dict->getJsonObjectFromDict("analyticsMetadata")
                logger.setMetadata(metadata)
              }
              if dict->getDictIsSome("paymentOptions") {
                let paymentOptions = dict->Utils.getDictFromObj("paymentOptions")

                let clientSecret = getWarningString(paymentOptions, "clientSecret", "", ~logger)
                setKeys(prev => {
                  ...prev,
                  clientSecret: Some(clientSecret),
                })
                logger.setClientSecret(clientSecret)

                switch OrcaUtils.getThemePromise(paymentOptions) {
                | Some(promise) =>
                  promise
                  ->then(res => {
                    dict->setConfigs(res)
                    resolve()
                  })
                  ->ignore
                | None =>
                  dict->setConfigs({
                    default: DefaultTheme.default,
                    defaultRules: DefaultTheme.defaultRules,
                  })
                }
              }

              logger.setLogInfo(~value=Window.href, ~eventName=APP_RENDERED, ())
              [
                ("iframeId", "no-element"->JSON.Encode.string),
                ("publishableKey", ""->JSON.Encode.string),
                ("parentURL", "*"->JSON.Encode.string),
                ("sdkHandleOneClickConfirmPayment", true->JSON.Encode.bool),
              ]->Array.forEach(keyPair => {
                dict->CommonHooks.updateKeys(keyPair, setKeys)
              })

              logger.setLogInfo(~eventName=PAYMENT_OPTIONS_PROVIDED, ~value="", ())
            }
          } else if dict->getDictIsSome("paymentOptions") {
            let paymentOptions = dict->Utils.getDictFromObj("paymentOptions")

            let clientSecret = getWarningString(paymentOptions, "clientSecret", "", ~logger)
            setKeys(prev => {
              ...prev,
              clientSecret: Some(clientSecret),
            })
            logger.setClientSecret(clientSecret)

            switch OrcaUtils.getThemePromise(paymentOptions) {
            | Some(promise) =>
              promise
              ->then(res => {
                dict->setConfigs(res)
                resolve()
              })
              ->ignore
            | None =>
              dict->setConfigs({
                default: DefaultTheme.default,
                defaultRules: DefaultTheme.defaultRules,
              })
            }
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
              clientSecret: Some(val->JSON.Decode.string->Option.getOr("")),
            })
            setConfig(prev => {
              ...prev,
              config: {
                ...prev.config,
                clientSecret: val->JSON.Decode.string->Option.getOr(""),
              },
            })
          | None => ()
          }
          switch OrcaUtils.getThemePromise(optionsDict) {
          | Some(promise) =>
            promise
            ->then(res => {
              dict->setConfigs(res)
              resolve()
            })
            ->ignore
          | None =>
            dict->setConfigs({
              default: DefaultTheme.default,
              defaultRules: DefaultTheme.defaultRules,
            })
          }
        }
        if dict->getDictIsSome("sessions") {
          setSessions(_ => Loaded(dict->getJsonObjectFromDict("sessions")))
        }
        if dict->getDictIsSome("isReadyToPay") {
          setIsGooglePayReady(_ =>
            dict->getJsonObjectFromDict("isReadyToPay")->JSON.Decode.bool->Option.getOr(false)
          )
        }
        if dict->getDictIsSome("paymentMethodList") {
          let list = dict->getJsonObjectFromDict("paymentMethodList")
          let updatedState: PaymentType.loadType =
            list == Dict.make()->JSON.Encode.object
              ? LoadError(list)
              : switch list->Utils.getDictFromJson->Dict.get("error") {
                | Some(_) => LoadError(list)
                | None =>
                  let isNonEmptyPaymentMethodList =
                    list->Utils.getDictFromJson->Utils.getArray("payment_methods")->Array.length > 0
                  isNonEmptyPaymentMethodList ? Loaded(list) : LoadError(list)
                }
          switch updatedState {
          | Loaded(_) => logger.setLogInfo(~value="Loaded", ~eventName=LOADER_CHANGED, ())
          | LoadError(x) =>
            logger.setLogError(
              ~value="LoadError: " ++ x->JSON.stringify,
              ~eventName=LOADER_CHANGED,
              (),
            )
          | _ => ()
          }
          setList(_ => updatedState)
        }
        if dict->getDictIsSome("customerPaymentMethods") {
          let customerPaymentMethods = dict->PaymentType.createCustomerObjArr
          setOptionsPayment(prev => {
            ...prev,
            customerPaymentMethods,
          })
        }
        if dict->Dict.get("applePayCanMakePayments")->Option.isSome {
          setIsApplePayReady(_ => true)
        }
        if dict->Dict.get("applePaySessionObjNotPresent")->Option.isSome {
          setIsApplePayReady(prev => prev && false)
        }
      } catch {
      | _ => setIntegrateErrorError(_ => true)
      }
    }
    handleMessage(handleFun, "Error in parsing sent Data")
  }, (showCardFormByDefault, paymentMethodOrder))

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

  React.useEffect2(() => {
    Utils.handlePostMessage([
      ("iframeHeight", (divH +. 1.0)->JSON.Encode.float),
      ("iframeId", iframeId->JSON.Encode.string),
    ])
    None
  }, (divH, iframeId))
  //<...>//

  <div ref={divRef->ReactDOM.Ref.domRef}> children </div>
}
