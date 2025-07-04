open ClickToPayHelpers
open Utils
let useClickToPay = (
  ~areClickToPayUIScriptsLoaded,
  ~setSessions,
  ~setAreClickToPayUIScriptsLoaded,
  ~savedMethods,
  ~loadSavedCards,
  ~setShowPaymentElementScreen,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  let {clickToPayProvider, isReady} = clickToPayConfig
  let setClickToPayProvider = provider =>
    setClickToPayConfig(prev => {
      ...prev,
      clickToPayProvider: provider,
    })

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let sessionsObj = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let {clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let closeComponentIfSavedMethodsAreEmpty = () => {
    if savedMethods->Array.length === 0 && loadSavedCards !== PaymentType.LoadingSavedCards {
      setShowPaymentElementScreen(_ => true)
    }
  }

  let setClickToPayNotReady = () =>
    setClickToPayConfig(prev => {
      ...prev,
      isReady: Some(false),
    })

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
          | Some(profilesArray) =>
            loggerState.setLogInfo(
              ~value={
                "message": "Cards fetched successfully",
                "scheme": clickToPayProvider,
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
            switch profilesArray[0] {
            | Some(profile) => Some(profile.maskedCards)
            | None => None
            }
          | None => None
          }
          setClickToPayConfig(prev => {
            ...prev,
            visaComponentState: NONE,
          })

          setClickToPayConfig(prev => {
            ...prev,
            clickToPayCards: cards,
          })
        }
      | PENDING_CONSUMER_IDV =>
        setClickToPayConfig(prev => {
          ...prev,
          visaComponentState: OTP_INPUT,
          maskedIdentity: cardsResult.maskedValidationChannel->Option.getOr(""),
        })
      | ADD_CARD =>
        setClickToPayConfig(prev => {
          ...prev,
          visaComponentState: NONE,
        })
      | FAILED
      | ERROR =>
        if otp != "" {
          switch cardsResult.error {
          | Some(err) =>
            switch err.reason {
            | Some(reason) =>
              switch reason {
              | "VALIDATION_DATA_INVALID" =>
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "VALIDATION_DATA_INVALID",
                })
              | "OTP_SEND_FAILED" =>
                loggerState.setLogError(
                  ~value={
                    "message": "OTP SEND FAILED",
                    "scheme": clickToPayProvider,
                  }
                  ->JSON.stringifyAny
                  ->Option.getOr(""),
                  ~eventName=CLICK_TO_PAY_FLOW,
                )
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "NONE",
                })

              | "ACCT_INACCESSIBLE" =>
                loggerState.setLogError(
                  ~value={
                    "message": `Maximum getCard call attempts reached (ACCT_INACCESSIBLE) - ${reason}`,
                    "scheme": clickToPayProvider,
                  }
                  ->JSON.stringifyAny
                  ->Option.getOr(""),
                  ~eventName=CLICK_TO_PAY_FLOW,
                )
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "ACCT_INACCESSIBLE",
                })
              | _ =>
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "NONE",
                })
                loggerState.setLogError(
                  ~value={
                    "message": `get cards call failed - ${reason}`,
                    "scheme": clickToPayProvider,
                  }
                  ->JSON.stringifyAny
                  ->Option.getOr(""),
                  ~eventName=CLICK_TO_PAY_FLOW,
                )
              }
            | None =>
              setClickToPayConfig(prev => {
                ...prev,
                visaComponentState: NONE,
              })
            }
          | None =>
            setClickToPayConfig(prev => {
              ...prev,
              visaComponentState: NONE,
            })
          }
        } else {
          setClickToPayConfig(prev => {
            ...prev,
            visaComponentState: NONE,
          })
          loggerState.setLogError(
            ~value={
              "message": "initial get cards call failed",
              "scheme": clickToPayProvider,
            }
            ->JSON.stringifyAny
            ->Option.getOr(""),
            ~eventName=CLICK_TO_PAY_FLOW,
          )
        }
      }
    } catch {
    | err => {
        setClickToPayNotReady()
        loggerState.setLogError(
          ~value={
            "message": `get cards call failed - ${err->Utils.formatException->JSON.stringify}`,
            "scheme": clickToPayProvider,
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
      }
    }
  }

  let initVisaUnified = async email => {
    try {
      switch clickToPayConfig.clickToPayToken {
      | Some(token) => {
          let initConfig = getVisaInitConfig(token, clientSecret)

          setClickToPayConfig(prev => {
            ...prev,
            visaComponentState: CARDS_LOADING,
          })
          let _ = await vsdk.initialize(initConfig)
          let _ = await getVisaCards(~identityValue=email, ~otp="", ~identityType=EMAIL_ADDRESS)
        }
      | None => ()
      }
    } catch {
    | err =>
      setClickToPayNotReady()
      closeComponentIfSavedMethodsAreEmpty()
      loggerState.setLogError(
        ~value={
          "message": `SDK initialization failed - ${err->Utils.formatException->JSON.stringify}`,
          "scheme": clickToPayProvider,
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
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
        loggerState,
        () => setAreClickToPayUIScriptsLoaded(_ => true),
        setClickToPayNotReady,
      )
      switch ctpToken {
      | Some(clickToPayToken) =>
        ClickToPayHelpers.loadVisaScript(
          clickToPayToken,
          () => visaScriptOnLoadCallback(ctpToken),
          () => {
            setClickToPayNotReady()
            loggerState.setLogError(
              ~value={
                "message": "CTP UI script loading failed",
                "scheme": clickToPayProvider,
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
          },
        )

      | None => setClickToPayNotReady()
      }
    } catch {
    | err => {
        setClickToPayNotReady()
        loggerState.setLogError(
          ~value={
            "message": `CTP UI script loading failed - ${err
              ->Utils.formatException
              ->JSON.stringify}`,
            "scheme": clickToPayProvider,
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
      }
    }
  }

  let loadMastercardClickToPayScript = ctpToken => {
    open Promise
    switch ctpToken {
    | Some(clickToPayToken) =>
      ClickToPayHelpers.loadClickToPayScripts(loggerState)
      ->then(_ => {
        setAreClickToPayUIScriptsLoaded(_ => true)
        resolve()
      })
      ->catch(_ => {
        loggerState.setLogError(
          ~value="ClickToPay UI Kit CSS Load Error",
          ~eventName=CLICK_TO_PAY_SCRIPT,
        )
        resolve()
      })
      ->ignore
      ClickToPayHelpers.loadMastercardScript(clickToPayToken, loggerState)
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
            let cardsResult = await ClickToPayHelpers.getCards(loggerState)
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
