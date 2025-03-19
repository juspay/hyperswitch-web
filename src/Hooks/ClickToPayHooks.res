open ClickToPayHelpers
open Utils
let useClickToPay = (
  ~areClickToPayUIScriptsLoaded,
  ~setSessions,
  ~setAreClickToPayUIScriptsLoaded,
) => {
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)
  let (clickToPayProvider, _) = Recoil.useRecoilState(RecoilAtoms.clickToPayProvider)
  let (visaComponentState, setVisaComponentState) = React.useState(_ => NONE)
  let (maskedIdentity, setMaskedIdentity) = React.useState(_ => "")
  let (otpError, setOtpError) = React.useState(_ => "")
  let (consumerIdentity, setConsumerIdentity) = React.useState(_ => {
    identityType: EMAIL_ADDRESS,
    identityValue: "",
  })
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let sessionsObj = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let getVisaCards = async (
    ~identityValue=clickToPayConfig.email,
    ~otp="",
    ~identityType=consumerIdentity.identityType,
  ) => {
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
          setVisaComponentState(_ => NONE)

          //TODO: handle the case when no cards were found

          let _ = setClickToPayConfig(prev => {
            ...prev,
            clickToPayCards: cards,
          })
        }
      | PENDING_CONSUMER_IDV => {
          setVisaComponentState(_ => OTP_INPUT)
          setMaskedIdentity(_ => cardsResult.maskedValidationChannel->Option.getOr(""))
        }
      | ADD_CARD =>
        // TODO: need to prompt user to add card
        setVisaComponentState(_ => NONE)

        ()
      | FAILED
      | ERROR =>
        if otp != "" {
          switch cardsResult.error {
          | Some(err) =>
            switch err.reason {
            | Some(reason) =>
              switch reason {
              | "VALIDATION_DATA_INVALID" => setOtpError(_ => "VALIDATION_DATA_INVALID")
              | "OTP_SEND_FAILED" =>
                //TODO: need to handle this case properly
                Console.log("OTP_SEND_FAILED")

              | "ACCT_INACCESSIBLE" => //TODO: need to handle this case properly
                ()
              | _ => setOtpError(_ => "NONE")
              }
            | None => setVisaComponentState(_ => NONE)
            }
          | None => setVisaComponentState(_ => NONE)
          }
        } else {
          // TODO: handle this case we there is error in getting cards without otp
          setVisaComponentState(_ => NONE)
          Console.log("get cards failed!")
        }
      }
    } catch {
    | _ => setVisaComponentState(_ => NONE)
    }
  }

  let initVisaUnified = async email => {
    try {
      let initConfig = {
        dpaTransactionOptions: {
          dpaLocale: "en_US",
          paymentOptions: [
            {
              dpaDynamicDataTtlMinutes: 15,
              dynamicDataType: #CARD_APPLICATION_CRYPTOGRAM_LONG_FORM,
            },
          ],
          transactionAmount: {
            transactionAmount: "123.94",
            transactionCurrencyCode: "USD",
          },
          dpaBillingPreference: "NONE",
          consumerNationalIdentifierRequested: false,
          payloadTypeIndicator: "FULL",
          acquirerBIN: "455555",
          acquirerMerchantId: "12345678",
          merchantCategoryCode: "4829",
          merchantCountryCode: "US",
          merchantOrderId: "fd65f14b-8155-47f0-bfa9-65ff9df0f760",
        },
        correlationId: "my-id",
      }

      setVisaComponentState(_ => CARDS_LOADING)
      let _ = await vsdk.initialize(initConfig)
      let _ = await getVisaCards(~identityValue=email)
    } catch {
    | _ => setVisaComponentState(_ => NONE)
    }
  }
  let visaScriptOnLoadCallback = ssn => {
    let dict = ssn->getDictFromJson
    let clickToPaySessionObj = SessionsType.itemToObjMapper(dict, ClickToPayObject)
    let clickToPayToken = SessionsType.getPaymentSessionObj(
      clickToPaySessionObj.sessionsToken,
      ClickToPay,
    )
    switch clickToPayToken {
    | ClickToPayTokenOptional(optToken) => {
        switch optToken {
        | Some(token) => {
            let clickToPayToken = ClickToPayHelpers.clickToPayTokenItemToObjMapper(token)
            setTimeout(() => {
              let availableCardBrands = ["mastercard", "visa"]
              setClickToPayConfig(prev => {
                ...prev,
                isReady: Some(true),
                availableCardBrands,
                email: clickToPayToken.email,
                dpaName: clickToPayToken.dpaName,
              })
            }, 6000)->ignore
          }
        | None =>
          setClickToPayConfig(prev => {
            ...prev,
            isReady: Some(false),
          })
        }
        ()
      }
    | _ =>
      setClickToPayConfig(prev => {
        ...prev,
        isReady: Some(false),
      })
    }
  }

  let visaScriptOnErrorCallback = () => {
    setClickToPayConfig(prev => {
      ...prev,
      isReady: Some(false),
    })
  }

  let loadVisaScript = async ssn => {
    try {
      ClickToPayHelpers.loadVisaScript(
        () => visaScriptOnLoadCallback(ssn),
        visaScriptOnErrorCallback,
      )
      ClickToPayHelpers.loadClickToPayUIScripts(
        loggerState,
        () => setAreClickToPayUIScriptsLoaded(_ => true),
        () =>
          setClickToPayConfig(prev => {
            ...prev,
            isReady: Some(false),
          }),
      )
    } catch {
    | _ =>
      setClickToPayConfig(prev => {
        ...prev,
        isReady: Some(false),
      })
    }
  }

  let loadMastercardClickToPayScript = ssn => {
    open Promise
    let dict = ssn->getDictFromJson
    let clickToPaySessionObj = SessionsType.itemToObjMapper(dict, ClickToPayObject)
    let clickToPayToken = SessionsType.getPaymentSessionObj(
      clickToPaySessionObj.sessionsToken,
      ClickToPay,
    )

    switch clickToPayToken {
    | ClickToPayTokenOptional(optToken) =>
      switch optToken {
      | Some(token) =>
        let clickToPayToken = ClickToPayHelpers.clickToPayTokenItemToObjMapper(token)
        let isProd = publishableKey->String.startsWith("pk_prd_")
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
          setClickToPayConfig(prev => {
            ...prev,
            isReady: Some(false),
          })
          resolve()
        })
        ->ignore
      | None =>
        setClickToPayConfig(prev => {
          ...prev,
          isReady: Some(false),
        })
      }
    | _ =>
      setClickToPayConfig(prev => {
        ...prev,
        isReady: Some(false),
      })
    }
  }

  React.useEffect(() => {
    if (
      clickToPayConfig.isReady == Some(true) &&
      clickToPayProvider == VISA &&
      areClickToPayUIScriptsLoaded
    ) {
      initVisaUnified(clickToPayConfig.email)->ignore
    }
    None
  }, (clickToPayConfig.isReady, areClickToPayUIScriptsLoaded, clickToPayProvider))

  React.useEffect(() => {
    if clickToPayConfig.email !== "" && consumerIdentity.identityValue === "" {
      setConsumerIdentity(_ => {
        identityType: EMAIL_ADDRESS,
        identityValue: clickToPayConfig.email,
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
        | NONE =>
          setClickToPayConfig(prev => {
            ...prev,
            isReady: Some(false),
          })
        }
      }
    | _ => ()
    }
    None
  }, [sessionsObj])

  (
    getVisaCards,
    visaComponentState,
    otpError,
    setOtpError,
    maskedIdentity,
    consumerIdentity,
    setConsumerIdentity,
  )
}
