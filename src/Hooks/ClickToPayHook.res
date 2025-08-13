open ClickToPayHelpers
open Utils
let useClickToPay = (
  ~areClickToPayUIScriptsLoaded,
  ~setSessions,
  ~setAreClickToPayUIScriptsLoaded,
  ~savedMethods,
  ~loadSavedCards,
  ~isSavedCardElement=false,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  let setShowPaymentMethodsScreen = Recoil.useSetRecoilState(RecoilAtoms.showPaymentMethodsScreen)
  let {clickToPayProvider, isReady} = clickToPayConfig
  let setClickToPayProvider = provider =>
    setClickToPayConfig(prev => {
      ...prev,
      clickToPayProvider: provider,
    })

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let sessionsObj = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)

  let getEnabledAuthnMethodsToken = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.enabledAuthnMethodsToken,
  )

  let {clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

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

  let (keys, setKeys) = Recoil.useRecoilState(RecoilAtoms.keys)

  let {iframeId} = keys

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

  let handleVisaGetCardsResult = (cardsResult: ClickToPayHelpers.getCardsResultType, ~otp) => {
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
    // } catch {
    // | err => {
    // setClickToPayNotReady()
    // loggerState.setLogError(
    //   ~value={
    //     "message": `get cards call failed - ${err->Utils.formatException->JSON.stringify}`,
    //     "scheme": clickToPayProvider,
    //   }
    //   ->JSON.stringifyAny
    //   ->Option.getOr(""),
    //   ~eventName=CLICK_TO_PAY_FLOW,
    // )
    //   }
  }

  let getVisaCards: (
    ~identityValue: string,
    ~otp: string,
    ~identityType: ClickToPayHelpers.identityType,
    ~signOut: bool,
  ) => promise<unit> = async (~identityValue, ~otp, ~identityType, ~signOut) => {
    messageParentWindow([
      ("getVisaCards", true->JSON.Encode.bool),
      ("identityValue", identityValue->JSON.Encode.string),
      ("otp", otp->JSON.Encode.string),
      ("identityType", ClickToPayHelpers.getIdentityType(identityType)->JSON.Encode.string),
      ("signOut", signOut->JSON.Encode.bool),
    ])
    // try {
    //   let cardsResult = await getCardsVisaUnified(~identityValue, ~otp, ~identityType)

    //   switch cardsResult.actionCode {
    //   | SUCCESS => {
    //       let cards = switch cardsResult.profiles {
    //       | Some(profilesArray) =>
    //         loggerState.setLogInfo(
    //           ~value={
    //             "message": "Cards fetched successfully",
    //             "scheme": clickToPayProvider,
    //           }
    //           ->JSON.stringifyAny
    //           ->Option.getOr(""),
    //           ~eventName=CLICK_TO_PAY_FLOW,
    //         )
    //         switch profilesArray[0] {
    //         | Some(profile) => Some(profile.maskedCards)
    //         | None => None
    //         }
    //       | None => None
    //       }
    //       setClickToPayConfig(prev => {
    //         ...prev,
    //         visaComponentState: NONE,
    //       })

    //       setClickToPayConfig(prev => {
    //         ...prev,
    //         clickToPayCards: cards,
    //       })
    //     }
    //   | PENDING_CONSUMER_IDV =>
    //     setClickToPayConfig(prev => {
    //       ...prev,
    //       visaComponentState: OTP_INPUT,
    //       maskedIdentity: cardsResult.maskedValidationChannel->Option.getOr(""),
    //     })
    //   | ADD_CARD =>
    //     setClickToPayConfig(prev => {
    //       ...prev,
    //       visaComponentState: NONE,
    //     })
    //   | FAILED
    //   | ERROR =>
    //     if otp != "" {
    //       switch cardsResult.error {
    //       | Some(err) =>
    //         switch err.reason {
    //         | Some(reason) =>
    //           switch reason {
    //           | "VALIDATION_DATA_INVALID" =>
    //             setClickToPayConfig(prev => {
    //               ...prev,
    //               otpError: "VALIDATION_DATA_INVALID",
    //             })
    //           | "OTP_SEND_FAILED" =>
    //             loggerState.setLogError(
    //               ~value={
    //                 "message": "OTP SEND FAILED",
    //                 "scheme": clickToPayProvider,
    //               }
    //               ->JSON.stringifyAny
    //               ->Option.getOr(""),
    //               ~eventName=CLICK_TO_PAY_FLOW,
    //             )
    //             setClickToPayConfig(prev => {
    //               ...prev,
    //               otpError: "NONE",
    //             })

    //           | "ACCT_INACCESSIBLE" =>
    //             loggerState.setLogError(
    //               ~value={
    //                 "message": `Maximum getCard call attempts reached (ACCT_INACCESSIBLE) - ${reason}`,
    //                 "scheme": clickToPayProvider,
    //               }
    //               ->JSON.stringifyAny
    //               ->Option.getOr(""),
    //               ~eventName=CLICK_TO_PAY_FLOW,
    //             )
    //             setClickToPayConfig(prev => {
    //               ...prev,
    //               otpError: "ACCT_INACCESSIBLE",
    //             })
    //           | _ =>
    //             setClickToPayConfig(prev => {
    //               ...prev,
    //               otpError: "NONE",
    //             })
    //             loggerState.setLogError(
    //               ~value={
    //                 "message": `get cards call failed - ${reason}`,
    //                 "scheme": clickToPayProvider,
    //               }
    //               ->JSON.stringifyAny
    //               ->Option.getOr(""),
    //               ~eventName=CLICK_TO_PAY_FLOW,
    //             )
    //           }
    //         | None =>
    //           setClickToPayConfig(prev => {
    //             ...prev,
    //             visaComponentState: NONE,
    //           })
    //         }
    //       | None =>
    //         setClickToPayConfig(prev => {
    //           ...prev,
    //           visaComponentState: NONE,
    //         })
    //       }
    //     } else {
    //       setClickToPayConfig(prev => {
    //         ...prev,
    //         visaComponentState: NONE,
    //       })
    //       loggerState.setLogError(
    //         ~value={
    //           "message": "initial get cards call failed",
    //           "scheme": clickToPayProvider,
    //         }
    //         ->JSON.stringifyAny
    //         ->Option.getOr(""),
    //         ~eventName=CLICK_TO_PAY_FLOW,
    //       )
    //     }
    //   }
    // } catch {
    // | err => {
    //     setClickToPayNotReady()
    //     loggerState.setLogError(
    //       ~value={
    //         "message": `get cards call failed - ${err->Utils.formatException->JSON.stringify}`,
    //         "scheme": clickToPayProvider,
    //       }
    //       ->JSON.stringifyAny
    //       ->Option.getOr(""),
    //       ~eventName=CLICK_TO_PAY_FLOW,
    //     )
    //   }
    // }
    ()
  }

  let {clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  React.useEffect0(() => {
    let handleVisaClickToPayOnLoad = (ev: Window.event) => {
      let json = ev.data->safeParse
      try {
        let dict = json->getDictFromJson
        if dict->Dict.get("finishLoadingClickToPayScript")->Option.isSome {
          if dict->Dict.get("clickToPayToken")->Option.isSome {
            messageParentWindow([
              ("param", `clickToPayHidden`->JSON.Encode.string),
              ("iframeId", iframeId->JSON.Encode.string),
            ])

            let clickToPayToken =
              dict
              ->Dict.get("clickToPayToken")
              ->Option.getOr(JSON.Encode.null)
              ->ClickToPayHelpers.clickToPayTokenItemToObjMapper
            visaScriptOnLoadCallback(Some(clickToPayToken))
          } else {
            setClickToPayNotReady()
            loggerState.setLogError(
              ~value={
                "message": "CTP script loading failed",
                "scheme": clickToPayProvider,
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
          }
        } else if dict->Dict.get("initializedClickToPay")->Option.isSome {
          if dict->Dict.get("error")->Option.isNone {
            let identityValue =
              dict
              ->Dict.get("identityValue")
              ->Option.getOr(JSON.Encode.null)
              ->JSON.Decode.string
              ->Option.getOr("")
            let otp = dict->Utils.getString("otp", "")
            let identityType =
              dict
              ->Utils.getString("identityType", "")
              ->ClickToPayHelpers.getIdentityTypeFromString

            getVisaCards(~identityValue, ~otp, ~identityType, ~signOut=false)->ignore
          } else {
            setClickToPayNotReady()
            closeComponentIfSavedMethodsAreEmpty()
            loggerState.setLogError(
              ~value={
                "message": `SDK initialization failed - Error Initializing Click to Pay - ${dict
                  ->Dict.get("error")
                  ->Option.getOr(JSON.Encode.null)
                  ->JSON.Decode.string
                  ->Option.getOr("")}`,
                "scheme": clickToPayProvider,
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
          }
        } else if dict->Dict.get("fetchedVisaCardsResult")->Option.isSome {
          if dict->Dict.get("cardsResult")->Option.isSome {
            let cardsResult =
              dict
              ->Dict.get("cardsResult")
              ->Option.getOr(JSON.Encode.null)
              ->ClickToPayHelpers.jsonToCardsResultType
            let otp = dict->Utils.getString("otp", "")

            handleVisaGetCardsResult(cardsResult, ~otp)
          } else {
            setClickToPayNotReady()
            loggerState.setLogError(
              ~value={
                "message": `get cards call failed - Something Went Wrong`,
                // "message": `get cards call failed - ${err->Utils.formatException->JSON.stringify}`,
                "scheme": clickToPayProvider,
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
          }
        } else if dict->Dict.get("doAuthentication")->Option.isSome {
          messageParentWindow([("handleClickToPayAuthentication", true->JSON.Encode.bool)])
        }
      } catch {
      | _ => Console.warn("Something went wrong while receiving data")
      // logger.setLogError(
      //   ~value="Error in parsing Apple Pay Data",
      //   ~eventName=APPLE_PAY_FLOW,
      //   ~paymentMethod="APPLE_PAY",
      //   // ~internalMetadata=err->formatException->JSON.stringify,
      // )
      }
    }
    Window.addEventListener("message", handleVisaClickToPayOnLoad)
    Some(
      () => {
        Window.removeEventListener("message", handleVisaClickToPayOnLoad)
      },
    )
  })

  let initVisaUnified = async email => {
    try {
      switch clickToPayConfig.clickToPayToken {
      | Some(token) => {
          let initConfig = getVisaInitConfig(token, clientSecret)

          setClickToPayConfig(prev => {
            ...prev,
            visaComponentState: CARDS_LOADING,
          })

          messageParentWindow([
            ("initializeVisaClickToPay", true->JSON.Encode.bool),
            ("clickToPayToken", token->ClickToPayHelpers.clickToPayToJsonItemToObjMapper),
            ("clientSecret", clientSecret->Option.getOr("")->JSON.Encode.string),
            ("identityValue", email->JSON.Encode.string),
            ("otp", ""->JSON.Encode.string),
            ("identityType", EMAIL_ADDRESS->ClickToPayHelpers.getIdentityType->JSON.Encode.string),
          ])
          // let _ = await vsdk.initialize(initConfig)
          // let _ = await getVisaCards(~identityValue=email, ~otp="", ~identityType=EMAIL_ADDRESS)
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

  let loadVisaScript = async ctpToken => {
    try {
      ClickToPayHelpers.loadClickToPayUIScripts(
        loggerState,
        () => setAreClickToPayUIScriptsLoaded(_ => true),
        setClickToPayNotReady,
      )
      switch ctpToken {
      | Some(clickToPayToken) =>
        messageParentWindow([
          ("loadClickToPayScript", true->JSON.Encode.bool),
          ("clickToPayToken", clickToPayToken->ClickToPayHelpers.clickToPayToJsonItemToObjMapper),
        ])

        messageParentWindow([
          ("fullscreen", false->JSON.Encode.bool),
          ("hiddenIframe", true->JSON.Encode.bool),
          ("param", `clickToPayHidden`->JSON.Encode.string),
          ("iframeId", iframeId->JSON.Encode.string),
        ])
      // ClickToPayHelpers.loadVisaScript(
      //   clickToPayToken,
      //   () => visaScriptOnLoadCallback(ctpToken),
      //   () => {
      //     setClickToPayNotReady()
      //     loggerState.setLogError(
      //       ~value={
      //         "message": "CTP UI script loading failed",
      //         "scheme": clickToPayProvider,
      //       }
      //       ->JSON.stringifyAny
      //       ->Option.getOr(""),
      //       ~eventName=CLICK_TO_PAY_FLOW,
      //     )
      //   },
      // )

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
      Console.log("$$$ Initializing Visa Click to Pay")
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

  // React.useEffect(() => {
  //   if !isSavedCardElement {
  //     switch sessionsObj {
  //     | Loaded(ssn) => {
  //         setSessions(_ => ssn)
  //         let ctpToken = ssn->getClickToPayToken
  //         ctpToken->Option.forEach(token => {
  //           switch token.provider->String.toLowerCase {
  //           | "visa" =>
  //             loadVisaScript(ctpToken)->ignore
  //             setClickToPayProvider(VISA)
  //           | "mastercard" => {
  //               loadMastercardClickToPayScript(ctpToken)
  //               setClickToPayProvider(MASTERCARD)
  //             }
  //           | _ =>
  //             setClickToPayNotReady()
  //             setClickToPayProvider(NONE)
  //           }
  //         })
  //       }
  //     | _ => ()
  //     }
  //   }
  //   None
  // }, [sessionsObj])

  React.useEffect(() => {
    if isSavedCardElement {
      switch getEnabledAuthnMethodsToken {
      | Loaded(ssn) => {
          setSessions(_ => ssn)
          let ctpToken = ssn->getClickToPayToken
          //     ()
          // }
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
    }
    None
  }, [getEnabledAuthnMethodsToken])

  (getVisaCards, closeComponentIfSavedMethodsAreEmpty)
}
