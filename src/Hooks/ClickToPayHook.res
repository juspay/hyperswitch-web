open ClickToPayHelpers
open Utils
let useClickToPay = (
  ~areClickToPayUIScriptsLoaded,
  ~setSessions,
  ~setAreClickToPayUIScriptsLoaded,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  let clickToPayProvider = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayProvider)
  let (ctpHelperAtom, setCtpHelperAtom) = Recoil.useRecoilState(RecoilAtoms.ctpHelperAtom)

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let sessionsObj = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let {publishableKey, clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isProd = publishableKey->String.startsWith("pk_prd_")

  let getVisaCards: (
    ~identityValue: string,
    ~otp: string,
    ~identityType: ClickToPayHelpers.identityType,
  ) => promise<unit> = async (~identityValue, ~otp, ~identityType) => {
    let consumerIdentity = {
      identityProvider: "SRC",
      identityValue,
      identityType,
    }
    let getCardsConfig = switch otp->String.length {
    | 6 => {consumerIdentity, validationData: otp}
    | _ => {consumerIdentity: consumerIdentity}
    }

    try {
      let cardsResult = await getCardsVisaUnified(~getCardsConfig)
      Console.log(cardsResult)
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
          setCtpHelperAtom(prev => {
            ...prev,
            visaComponentState: NONE,
          })

          //TODO: handle the case when no cards were found

          setClickToPayConfig(prev => {
            ...prev,
            clickToPayCards: cards,
          })
        }
      | PENDING_CONSUMER_IDV =>
        setCtpHelperAtom(prev => {
          ...prev,
          visaComponentState: OTP_INPUT,
          maskedIdentity: cardsResult.maskedValidationChannel->Option.getOr(""),
        })
      | ADD_CARD =>
        // TODO: need to prompt user to add card
        setCtpHelperAtom(prev => {
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
                setCtpHelperAtom(prev => {
                  ...prev,
                  otpError: "VALIDATION_DATA_INVALID",
                })
              | "OTP_SEND_FAILED" =>
                //TODO: need to handle this case properly
                Console.log("OTP_SEND_FAILED")

              | "ACCT_INACCESSIBLE" => //TODO: need to handle this case properly
                ()
              | _ =>
                setCtpHelperAtom(prev => {
                  ...prev,
                  otpError: "NONE",
                })
              }
            | None =>
              setCtpHelperAtom(prev => {
                ...prev,
                visaComponentState: NONE,
              })
            }
          | None =>
            setCtpHelperAtom(prev => {
              ...prev,
              visaComponentState: NONE,
            })
          }
        } else {
          // TODO: handle this case we there is error in getting cards without otp
          setCtpHelperAtom(prev => {
            ...prev,
            visaComponentState: NONE,
          })
          Console.log("get cards failed!")
        }
      }
    } catch {
    | _ =>
      setCtpHelperAtom(prev => {
        ...prev,
        visaComponentState: NONE,
      })
    }
  }

  let initVisaUnified = async email => {
    try {
      switch ctpHelperAtom.clickToPayToken {
      | Some(token) => {
          let initConfig = {
            dpaTransactionOptions: {
              dpaLocale: token.locale,
              paymentOptions: [
                {
                  dpaDynamicDataTtlMinutes: 15,
                  dynamicDataType: #CARD_APPLICATION_CRYPTOGRAM_LONG_FORM,
                },
              ],
              transactionAmount: {
                transactionAmount: token.transactionAmount->Float.toString,
                transactionCurrencyCode: token.transactionCurrencyCode,
              },
              dpaBillingPreference: "NONE",
              consumerNationalIdentifierRequested: false,
              payloadTypeIndicator: "FULL",
              acquirerBIN: token.acquirerBIN,
              acquirerMerchantId: token.acquirerMerchantId,
              merchantCategoryCode: token.merchantCategoryCode,
              merchantCountryCode: token.merchantCountryCode,
              merchantOrderId: clientSecret->Option.getOr(""),
            },
          }

          setCtpHelperAtom(prev => {
            ...prev,
            visaComponentState: CARDS_LOADING,
          })
          let _ = await vsdk.initialize(initConfig)
          let _ = await getVisaCards(~identityValue=email, ~otp="", ~identityType=EMAIL_ADDRESS)
        }
      | None => ()
      }
    } catch {
    | _ =>
      setCtpHelperAtom(prev => {
        ...prev,
        visaComponentState: NONE,
      })
    }
  }

  let getClickToPayToken = ssn => {
    let dict = ssn->getDictFromJson
    let clickToPaySessionObj = SessionsType.itemToObjMapper(dict, ClickToPayObject)
    switch SessionsType.getPaymentSessionObj(clickToPaySessionObj.sessionsToken, ClickToPay) {
    | ClickToPayTokenOptional(Some(token)) =>
      setCtpHelperAtom(prev => {
        ...prev,
        clickToPayToken: ClickToPayHelpers.clickToPayTokenItemToObjMapper(token),
      })
      Some(ClickToPayHelpers.clickToPayTokenItemToObjMapper(token))
    | _ => None
    }
  }

  let setClickToPayNotReady = () =>
    setClickToPayConfig(prev => {
      ...prev,
      isReady: Some(false),
    })

  let visaScriptOnLoadCallback = ssn => {
    switch getClickToPayToken(ssn) {
    | Some(clickToPayToken) => setTimeout(() => {
        setClickToPayConfig(prev => {
          ...prev,
          isReady: Some(true),
          availableCardBrands: clickToPayToken.cardBrands,
          email: clickToPayToken.email,
          dpaName: clickToPayToken.dpaName,
        })
      }, 6000)->ignore
    | None => setClickToPayNotReady()
    }
  }

  let loadVisaScript = async ssn => {
    try {
      ClickToPayHelpers.loadClickToPayUIScripts(
        loggerState,
        () => setAreClickToPayUIScriptsLoaded(_ => true),
        setClickToPayNotReady,
      )
      switch getClickToPayToken(ssn) {
      | Some(clickToPayToken) =>
        ClickToPayHelpers.loadVisaScript(
          clickToPayToken,
          isProd,
          () => visaScriptOnLoadCallback(ssn),
          setClickToPayNotReady,
        )

      | None => setClickToPayNotReady()
      }
    } catch {
    | _ => setClickToPayNotReady()
    }
  }

  let loadMastercardClickToPayScript = ssn => {
    open Promise
    switch getClickToPayToken(ssn) {
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
      clickToPayConfig.isReady == Some(true) &&
      clickToPayProvider == VISA &&
      areClickToPayUIScriptsLoaded &&
      ctpHelperAtom.clickToPayToken->Option.isSome
    ) {
      initVisaUnified(clickToPayConfig.email)->ignore
    }
    None
  }, (
    clickToPayConfig.isReady,
    areClickToPayUIScriptsLoaded,
    clickToPayProvider,
    ctpHelperAtom.clickToPayToken,
  ))

  React.useEffect(() => {
    if clickToPayConfig.email !== "" && ctpHelperAtom.consumerIdentity.identityValue === "" {
      setCtpHelperAtom(prev => {
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
    if clickToPayConfig.isReady == Some(true) && clickToPayProvider == MASTERCARD {
      let fetchCards = async () => {
        let cardsResult = await ClickToPayHelpers.getCards(loggerState)
        switch cardsResult {
        | Ok(cards) =>
          setClickToPayConfig(prev => {
            ...prev,
            clickToPayCards: Some(cards),
          })
        | Error(_) => ()
        }
      }
      fetchCards()->ignore
    }
    None
  }, (clickToPayConfig.isReady, clickToPayProvider))

  React.useEffect(() => {
    switch sessionsObj {
    | Loaded(ssn) => {
        setSessions(_ => ssn)
        switch clickToPayProvider {
        | VISA => loadVisaScript(ssn)->ignore
        | MASTERCARD => {
            let _ = loadMastercardClickToPayScript(ssn)
          }
        | NONE => setClickToPayNotReady()
        }
      }
    | _ => ()
    }
    None
  }, [sessionsObj])

  getVisaCards
}
