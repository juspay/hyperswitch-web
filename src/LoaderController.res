open Utils
@react.component
let make = (~children, ~paymentMode, ~setIntegrateErrorError, ~logger) => {
  open RecoilAtoms
  //<...>//
  let (configAtom, setConfig) = Recoil.useRecoilState(configAtom)
  let setApiEndpoint = Recoil.useSetRecoilState(endPoint)
  let (keys, setKeys) = Recoil.useRecoilState(keys)
  let (paymentlist, setList) = Recoil.useRecoilState(list)
  let (_, setSessions) = Recoil.useRecoilState(sessions)
  let (options, setOptions) = Recoil.useRecoilState(elementOptions)
  let (optionsPayment, setOptionsPayment) = Recoil.useRecoilState(optionAtom)
  let setSessionId = Recoil.useSetRecoilState(sessionId)
  let setBlockConfirm = Recoil.useSetRecoilState(isConfirmBlocked)
  let setSwitchToCustomPod = Recoil.useSetRecoilState(switchToCustomPod)
  let setIsGooglePayReady = Recoil.useSetRecoilState(isGooglePayReady)
  let (divH, setDivH) = React.useState(_ => 0.0)
  let {showCardFormByDefault, paymentMethodOrder} = optionsPayment

  let divRef = React.useRef(Js.Nullable.null)

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

  let updateOptions = dict => {
    let optionsDict = dict->getDictFromObj("options")
    switch paymentMode->CardTheme.getPaymentMode {
    | CardNumberElement
    | CardExpiryElement
    | CardCVCElement
    | Card =>
      setOptions(._ => ElementType.itemToObjMapper(optionsDict, logger))
    | Payment => setOptionsPayment(._ => PaymentType.itemToObjMapper(optionsDict, logger))
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

    setConfig(._ => {
      config: {
        appearance: appearance,
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
    handlePostMessage([("iframeMounted", true->Js.Json.boolean)])
    logger.setLogInitiated()
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
    | Loaded(_val) => handlePostMessage([("ready", true->Js.Json.boolean)])
    | _ => handlePostMessage([("ready", false->Js.Json.boolean)])
    }
    None
  }, [paymentlist])

  React.useEffect1(() => {
    CardUtils.genreateFontsLink(config.fonts)
    let dict = config.appearance.rules->getDictFromJson
    if dict->Js.Dict.entries->Js.Array2.length > 0 {
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
      ->Js.Array2.map(item => {
        let (class, dict) = item
        if dict->Js.Dict.entries->Js.Array2.length > 0 {
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
        ev.data->Js.Json.parseExn
      } catch {
      | _ => Js.Dict.empty()->Js.Json.object_
      }
      try {
        let dict = json->getDictFromJson
        if dict->getDictIsSome("paymentElementCreate") {
          if (
            dict
            ->Js.Dict.get("paymentElementCreate")
            ->Belt.Option.flatMap(Js.Json.decodeBoolean)
            ->Belt.Option.getWithDefault(false)
          ) {
            if (
              dict
              ->Js.Dict.get("otherElements")
              ->Belt.Option.flatMap(Js.Json.decodeBoolean)
              ->Belt.Option.getWithDefault(false)
            ) {
              updateOptions(dict)
            } else {
              let sdkSessionId = dict->getString("sdkSessionId", "no-element")
              logger.setSessionId(sdkSessionId)
              if Window.isInteg {
                setBlockConfirm(._ => dict->getBool("AOrcaBBlockPConfirm", false))
                setSwitchToCustomPod(._ => dict->getBool("switchToCustomPodABP", false))
              }
              updateOptions(dict)
              setSessionId(._ => {
                sdkSessionId
              })
              if dict->getDictIsSome("publishableKey") {
                let publishableKey = dict->getString("publishableKey", "")
                logger.setMerchantId(publishableKey)
                setApiEndpoint(._ => ApiEndpoint.getApiEndPoint(~publishableKey, ()))
              }

              if dict->getDictIsSome("paymentOptions") {
                let paymentOptions = dict->Utils.getDictFromObj("paymentOptions")

                let clientSecret = getWarningString(paymentOptions, "clientSecret", "", ~logger)
                setKeys(.prev => {
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

              logger.setLogInfo(~value="paymentElementCreate", ~eventName=APP_RENDERED, ())
              [
                ("iframeId", "no-element"->Js.Json.string),
                ("publishableKey", ""->Js.Json.string),
                ("parentURL", "*"->Js.Json.string),
                ("sdkHandleConfirmPayment", false->Js.Json.boolean),
              ]->Js.Array2.forEach(keyPair => {
                dict->CommonHooks.updateKeys(keyPair, setKeys)
              })

              logger.setLogInfo(~eventName=PAYMENT_OPTIONS_PROVIDED, ~value="", ())
            }
          } else if dict->getDictIsSome("paymentOptions") {
            let paymentOptions = dict->Utils.getDictFromObj("paymentOptions")

            let clientSecret = getWarningString(paymentOptions, "clientSecret", "", ~logger)
            setKeys(.prev => {
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
          let clientSecret = dict->Js.Dict.get("clientSecret")
          switch clientSecret {
          | Some(val) =>
            setKeys(.prev => {
              ...prev,
              clientSecret: Some(val->Js.Json.decodeString->Belt.Option.getWithDefault("")),
            })
            setConfig(.prev => {
              ...prev,
              config: {
                ...prev.config,
                clientSecret: val->Js.Json.decodeString->Belt.Option.getWithDefault(""),
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
          setSessions(._ => Loaded(dict->getJsonObjectFromDict("sessions")))
        }
        if dict->getDictIsSome("isReadyToPay") {
          setIsGooglePayReady(._ =>
            dict
            ->getJsonObjectFromDict("isReadyToPay")
            ->Js.Json.decodeBoolean
            ->Belt.Option.getWithDefault(false)
          )
        }
        if dict->getDictIsSome("paymentMethodList") {
          let list = dict->getJsonObjectFromDict("paymentMethodList")
          list == Js.Dict.empty()->Js.Json.object_
            ? setList(._ => LoadError(Js.Dict.empty()->Js.Json.object_))
            : switch list->Utils.getDictFromJson->Js.Dict.get("error") {
              | Some(err) => setList(._ => LoadError(err))
              | None => setList(._ => Loaded(list))
              }
        }
        if dict->getDictIsSome("customerPaymentMethods") {
          let customerPaymentMethods = dict->PaymentType.createCustomerObjArr
          setOptionsPayment(.prev => {
            ...prev,
            customerPaymentMethods: customerPaymentMethods,
          })
        }
      } catch {
      | _ => setIntegrateErrorError(_ => true)
      }
    }
    handleMessage(handleFun, "Error in parsing sent Data")
  }, (showCardFormByDefault, paymentMethodOrder))

  React.useEffect1(() => {
    [
      (optionsPayment.defaultValues.billingDetails.name, setUserFullName),
      (optionsPayment.defaultValues.billingDetails.email, setUserEmail),
      (optionsPayment.defaultValues.billingDetails.address.line1, setUserAddressline1),
      (optionsPayment.defaultValues.billingDetails.address.line2, setUserAddressline2),
      (optionsPayment.defaultValues.billingDetails.address.city, setUserAddressCity),
      (optionsPayment.defaultValues.billingDetails.address.postal_code, setUserAddressPincode),
      (optionsPayment.defaultValues.billingDetails.address.state, setUserAddressState),
      (optionsPayment.defaultValues.billingDetails.address.country, setUserAddressCountry),
    ]->Js.Array2.forEach(val => {
      let (value, setValue) = val
      if value != "" {
        setValue(.prev => {
          ...prev,
          value: value,
        })
      }
    })
    if optionsPayment.defaultValues.billingDetails.address.country === "" {
      let clientTimeZone = CardUtils.dateTimeFormat(.).resolvedOptions(.).timeZone
      let clientCountry = Utils.getClientCountry(clientTimeZone)
      setUserAddressCountry(.prev => {
        ...prev,
        value: clientCountry.countryName,
      })
      setCountry(._ => clientCountry.countryName)
    } else {
      setUserAddressCountry(.prev => {
        ...prev,
        value: optionsPayment.defaultValues.billingDetails.address.country,
      })
      setCountry(._ => optionsPayment.defaultValues.billingDetails.address.country)
    }
    None
  }, [optionsPayment])

  React.useEffect1(() => {
    switch paymentlist {
    | Loaded(_)
    | LoadError(_) => ()
    | _ =>
      setList(._ =>
        showCardFormByDefault && Utils.checkPriorityList(paymentMethodOrder) ? SemiLoaded : Loading
      )
    }
    None
  }, [paymentlist])

  let observer = ResizeObserver.newResizerObserver(entries => {
    entries
    ->Js.Array2.map(item => {
      setDivH(_ => item.contentRect.height)
    })
    ->ignore
  })
  switch divRef.current->Js.Nullable.toOption {
  | Some(r) => observer.observe(. r)
  | None => ()
  }

  React.useEffect2(() => {
    Utils.handlePostMessage([
      ("iframeHeight", (divH +. 1.0)->Js.Json.number),
      ("iframeId", iframeId->Js.Json.string),
    ])
    None
  }, (divH, iframeId))
  //<...>//

  <div ref={divRef->ReactDOM.Ref.domRef}> children </div>
}
