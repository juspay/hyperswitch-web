open ClickToPayHelpers
open Utils
let useClickToPay = (
  ~areClickToPayUIScriptsLoaded,
  ~setSessions,
  ~setAreClickToPayUIScriptsLoaded,
  ~savedMethods,
  ~loadSavedCards,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Jotai.useAtom(JotaiAtoms.clickToPayConfig)
  let setShowPaymentMethodsScreen = Jotai.useSetAtom(JotaiAtoms.showPaymentMethodsScreen)
  let {clickToPayProvider, isReady} = clickToPayConfig
  let setClickToPayProvider = provider =>
    setClickToPayConfig(prev => {
      ...prev,
      clickToPayProvider: provider,
    })

  let sessionsObj = Jotai.useAtomValue(JotaiAtoms.sessions)
  let {clientSecret} = Jotai.useAtomValue(JotaiAtoms.keys)

  let closeComponentIfSavedMethodsAreEmpty = () => {
    if savedMethods->Array.length === 0 && loadSavedCards !== PaymentType.LoadingSavedCards {
      setShowPaymentMethodsScreen(_ => true)
    }
  }

  let setClickToPayNotReady = () =>
    setClickToPayConfig(prev => {
      ...prev,
      isReady: Some(false),
    })

  let setVisaComponentState = view => {
    SdkLogger.logState(~event=ClickToPayViewChanged({view: view->LoggerCommonHelpers.variantValue}))
    setClickToPayConfig(prev => {
      ...prev,
      visaComponentState: view,
    })
  }

  let getVisaCards: (
    ~identityValue: string,
    ~otp: string,
    ~identityType: ClickToPayHelpers.identityType,
  ) => promise<unit> = async (~identityValue, ~otp, ~identityType) => {
    let consumerIdentity = {
      identityProvider: "SRC",
      identityValue: identityType == EMAIL_ADDRESS
        ? identityValue
        : identityValue->String.replaceAll(" ", ""),
      identityType,
    }
    let getCardsConfig = if otp->String.length == 6 {
      {consumerIdentity, validationData: otp}
    } else {
      {consumerIdentity: consumerIdentity}
    }

    try {
      let cardsResult = await getCardsVisaUnified(~getCardsConfig)
      switch cardsResult.actionCode {
      | SUCCESS => {
          let cards = switch cardsResult.profiles {
          | Some(profilesArray) => {
              let brandCount = brand =>
                profilesArray
                ->Array.flatMap(profile => profile.maskedCards)
                ->Array.filter(card =>
                  card.paymentCardDescriptor->String.toLowerCase->String.includes(brand)
                )
                ->Array.length
              ClickToPayLogger.logLifecycle(
                ~event=CardsFetched({
                  visa: brandCount("visa"),
                  mastercard: brandCount("mastercard"),
                }),
              )
              switch profilesArray[0] {
              | Some(profile) => Some(profile.maskedCards)
              | None => None
              }
            }
          | None => None
          }
          setVisaComponentState(NONE)

          setClickToPayConfig(prev => {
            ...prev,
            clickToPayCards: cards,
          })
        }
      | PENDING_CONSUMER_IDV => {
          SdkLogger.logState(
            ~event=ClickToPayViewChanged({view: OTP_INPUT->LoggerCommonHelpers.variantValue}),
          )
          setClickToPayConfig(prev => {
            ...prev,
            visaComponentState: OTP_INPUT,
            maskedIdentity: cardsResult.maskedValidationChannel->Option.getOr(""),
          })
        }
      | ADD_CARD => setVisaComponentState(NONE)
      | FAILED
      | ERROR =>
        if otp != "" {
          switch cardsResult.error {
          | Some(err) =>
            switch err.reason {
            | Some(reason) =>
              switch reason {
              | "VALIDATION_DATA_INVALID" =>
                ClickToPayLogger.logLifecycle(~event=CardsFetchFailed({code: reason}))
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "VALIDATION_DATA_INVALID",
                })
              | "OTP_SEND_FAILED" =>
                ClickToPayLogger.logLifecycle(~event=CardsFetchFailed({code: reason}))
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "NONE",
                })

              | "ACCT_INACCESSIBLE" =>
                ClickToPayLogger.logLifecycle(~event=CardsFetchFailed({code: reason}))
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "ACCT_INACCESSIBLE",
                })
              | _ =>
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "NONE",
                })
                ClickToPayLogger.logLifecycle(~event=CardsFetchFailed({code: reason}))
              }
            | None => setVisaComponentState(NONE)
            }
          | None => setVisaComponentState(NONE)
          }
        } else {
          setVisaComponentState(NONE)
          ClickToPayLogger.logLifecycle(~event=CardsFetchFailed({code: "INITIAL_CALL_FAILED"}))
        }
      }
    } catch {
    | err => {
        setClickToPayNotReady()
        ClickToPayLogger.logLifecycle(~event=CardsFetchFailed({code: "EXCEPTION"}), ~exn=err)
      }
    }
  }

  let initVisaUnified = async email => {
    try {
      switch clickToPayConfig.clickToPayToken {
      | Some(token) => {
          let initConfig = getVisaInitConfig(token, clientSecret)

          setVisaComponentState(CARDS_LOADING)
          let _ = await vsdk.initialize(initConfig)
          let _ = await getVisaCards(~identityValue=email, ~otp="", ~identityType=EMAIL_ADDRESS)
        }
      | None => ()
      }
    } catch {
    | err =>
      setClickToPayNotReady()
      closeComponentIfSavedMethodsAreEmpty()
      ClickToPayLogger.logLifecycle(~event=ProviderInitFailed({code: "EXCEPTION"}), ~exn=err)
    }
  }

  let getClickToPayToken = ssn => {
    let dict = ssn->getDictFromJson
    let clickToPaySessionObj = SessionsType.itemToObjMapper(dict, ClickToPayObject)
    switch SessionsType.getPaymentSessionObj(clickToPaySessionObj.sessionsToken, ClickToPay) {
    | ClickToPayTokenOptional(Some(token)) =>
      setClickToPayConfig(prev => {
        ...prev,
        clickToPayToken: ClickToPayHelpers.clickToPayTokenItemToObjMapper(token),
      })
      Some(ClickToPayHelpers.clickToPayTokenItemToObjMapper(token))
    | _ => {
        setClickToPayNotReady()
        None
      }
    }
  }

  let visaScriptOnLoadCallback = (ctpToken: option<ClickToPayHelpers.clickToPayToken>) => {
    switch ctpToken {
    | Some(clickToPayToken) =>
      setClickToPayConfig(prev => {
        ...prev,
        isReady: Some(true),
        availableCardBrands: clickToPayToken.cardBrands,
        email: clickToPayToken.email,
        dpaName: clickToPayToken.dpaName,
      })
    | None => setClickToPayNotReady()
    }
  }

  let loadVisaScript = async ctpToken => {
    try {
      ClickToPayHelpers.loadClickToPayUIScripts(
        () => setAreClickToPayUIScriptsLoaded(_ => true),
        setClickToPayNotReady,
      )
      switch ctpToken {
      | Some(clickToPayToken) =>
        ClickToPayHelpers.loadVisaScript(
          clickToPayToken,
          () => visaScriptOnLoadCallback(ctpToken),
          () => setClickToPayNotReady(),
        )

      | None => setClickToPayNotReady()
      }
    } catch {
    | err => {
        setClickToPayNotReady()
        ClickToPayLogger.logScript(~event=UiKitScriptError, ~exn=err)
      }
    }
  }

  let loadMastercardClickToPayScript = ctpToken => {
    open Promise
    switch ctpToken {
    | Some(clickToPayToken) =>
      ClickToPayHelpers.loadClickToPayScripts()
      ->then(_ => {
        setAreClickToPayUIScriptsLoaded(_ => true)
        resolve()
      })
      ->catch(_ => {
        ClickToPayLogger.logScript(~event=UiKitScriptError)
        resolve()
      })
      ->ignore
      ClickToPayHelpers.loadMastercardScript(clickToPayToken)
      ->then(resp => {
        let availableCardBrands =
          resp
          ->Utils.getDictFromJson
          ->Utils.getArray("availableCardBrands")
          ->Array.map(item => item->JSON.Decode.string->Option.getOr(""))
          ->Array.filter(item => item !== "")
        setClickToPayConfig(prev => {
          ...prev,
          isReady: Some(true),
          availableCardBrands,
          email: clickToPayToken.email,
          dpaName: clickToPayToken.dpaName,
        })
        resolve()
      })
      ->catch(_ => {
        setClickToPayNotReady()
        resolve()
      })
      ->ignore
    | None => setClickToPayNotReady()
    }
  }

  React.useEffect(() => {
    if (
      isReady == Some(true) &&
      clickToPayProvider == VISA &&
      areClickToPayUIScriptsLoaded &&
      clickToPayConfig.clickToPayToken->Option.isSome
    ) {
      initVisaUnified(clickToPayConfig.email)->ignore
    }
    None
  }, (isReady, areClickToPayUIScriptsLoaded, clickToPayProvider, clickToPayConfig.clickToPayToken))

  React.useEffect(() => {
    if clickToPayConfig.email !== "" && clickToPayConfig.consumerIdentity.identityValue === "" {
      setClickToPayConfig(prev => {
        ...prev,
        consumerIdentity: {
          identityType: EMAIL_ADDRESS,
          identityValue: clickToPayConfig.email,
        },
      })
    }
    None
  }, [clickToPayConfig.email])

  React.useEffect(() => {
    if isReady == Some(true) && clickToPayProvider == MASTERCARD {
      (
        async () => {
          try {
            let cardsResult = await ClickToPayHelpers.getCards()
            switch cardsResult {
            | Ok(cards) =>
              setClickToPayConfig(prev => {
                ...prev,
                clickToPayCards: Some(cards),
              })
            | Error(_) => ()
            }
          } catch {
          | _ => ()
          }
        }
      )()->ignore
    }
    None
  }, (isReady, clickToPayProvider))

  React.useEffect(() => {
    switch sessionsObj {
    | Loaded(ssn) => {
        setSessions(_ => ssn)
        let ctpToken = ssn->getClickToPayToken
        ctpToken->Option.forEach(token => {
          switch token.provider->String.toLowerCase {
          | "visa" =>
            loadVisaScript(ctpToken)->ignore
            setClickToPayProvider(VISA)
          | "mastercard" => {
              loadMastercardClickToPayScript(ctpToken)
              setClickToPayProvider(MASTERCARD)
            }
          | _ =>
            setClickToPayNotReady()
            setClickToPayProvider(NONE)
          }
        })
      }
    | _ => ()
    }
    None
  }, [sessionsObj])

  (getVisaCards, closeComponentIfSavedMethodsAreEmpty)
}
