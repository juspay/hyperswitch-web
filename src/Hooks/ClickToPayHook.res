open ClickToPayHelpers
open Utils
let useClickToPay = (
  ~areClickToPayUIScriptsLoaded,
  ~setSessions,
  ~setAreClickToPayUIScriptsLoaded,
  ~savedMethods,
  ~loadSavedCards,
  ~setShowFields,
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
  let isProd = GlobalVars.isProd

  let closeComponentIfSavedMethodsAreEmpty = () => {
    if savedMethods->Array.length === 0 && loadSavedCards !== PaymentType.LoadingSavedCards {
      setShowFields(_ => true)
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
                setClickToPayConfig(prev => {
                  ...prev,
                  otpError: "NONE",
                })

              | "ACCT_INACCESSIBLE" =>
                setCtpLogError(
                  ~loggerState,
                  ~clickToPayProvider,
                  ~error=`Maximum getCard call attempts reached (ACCT_INACCESSIBLE) - ${reason}`,
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
                setCtpLogError(
                  ~loggerState,
                  ~clickToPayProvider,
                  ~error=`get cards call failed - ${reason}`,
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
          setCtpLogError(~loggerState, ~clickToPayProvider, ~error="initial get cards call failed")
        }
      }
    } catch {
    | err => {
        setClickToPayNotReady()
        setCtpLogError(
          ~loggerState,
          ~clickToPayProvider,
          ~error=`get cards call failed - ${err->Utils.formatException->JSON.stringify}`,
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
      setCtpLogError(
        ~loggerState,
        ~clickToPayProvider,
        ~error=`SDK initialization failed - ${err->Utils.formatException->JSON.stringify}`,
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
          isProd,
          () => visaScriptOnLoadCallback(ctpToken),
          () => {
            setClickToPayNotReady()
            setCtpLogError(~loggerState, ~clickToPayProvider, ~error="CTP UI script loading failed")
          },
        )

      | None => setClickToPayNotReady()
      }
    } catch {
    | err => {
        setClickToPayNotReady()
        setCtpLogError(
          ~loggerState,
          ~clickToPayProvider,
          ~error=`CTP UI script loading failed - ${err->Utils.formatException->JSON.stringify}`,
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
      ClickToPayHelpers.loadMastercardScript(clickToPayToken, isProd, loggerState)
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
