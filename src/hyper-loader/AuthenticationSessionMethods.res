open Types
open Promise
open Utils
open ClickToPayHelpers

let clickToPayTokenCache = Dict.make()

let initClickToPaySession = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
  ~shouldLoadScripts=true,
) => {
  let customerEmail = ref("")
  let maskedCards = ref([])

  ClickToPayConsoleSuppress.initialize()

  let key = `${clientSecret}_${authenticationId}`

  let data = await (
    switch clickToPayTokenCache->Dict.get(key) {
    | Some(promise) => promise
    | None =>
      let promise = PaymentHelpers.fetchEnabledAuthnMethodsToken(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~isPaymentSession=false,
        ~profileId,
        ~authenticationId,
      )

      // only cache the promise for first time if we are not loading scripts
      if !shouldLoadScripts {
        clickToPayTokenCache->Dict.set(key, promise)
      }
      promise
    }
  )

  let getClickToPayToken = ssn => {
    let dict = ssn->getDictFromJson
    let clickToPaySessionObj = SessionsType.itemToObjMapper(dict, ClickToPayObject)
    switch SessionsType.getPaymentSessionObj(clickToPaySessionObj.sessionsToken, ClickToPay) {
    | ClickToPayTokenOptional(Some(token)) =>
      Some(ClickToPayHelpers.clickToPayTokenItemToObjMapper(token))
    | _ => None
    }
  }

  let ctpToken = getClickToPayToken(data)

  let getMaskedCardsListFromResponse = authenticationResponse => {
    authenticationResponse.profiles
    ->Option.flatMap(profiles => Some(profiles->Array.flatMap(profile => profile.maskedCards)))
    ->Option.getOr([])
    ->Array.map(card => {
      ...card,
      paymentCardDescriptor: card.paymentCardDescriptor->String.toUpperCase,
    })
  }

  let getClickToPayErrorResponse = (
    ~error: option<errorObj>,
    ~defaultErrorType="ERROR",
    ~defaultErrorMessage,
  ) => {
    switch error {
    | Some(errorObj) => {
        let errorType = errorObj.reason->Option.getOr(defaultErrorType)
        let getCardsErrorMessage = errorObj.message->Option.getOr("")

        let errorMessage =
          getCardsErrorMessage->String.trim->String.length > 0
            ? getCardsErrorMessage
            : defaultErrorMessage

        getFailedSubmitResponse(~errorType, ~message=errorMessage)
      }
    | None => getFailedSubmitResponse(~errorType=defaultErrorType, ~message=defaultErrorMessage)
    }
  }

  let isCustomerPresent = async (
    ~visaDirectSdk: option<OrcaPaymentPage.ClickToPayHelpers.visaDirect>,
    ~email,
  ) => {
    switch email {
    | Some(emailVal) => customerEmail := emailVal
    | None =>
      logger.setLogInfo(
        ~value="No email is passed directly to isCustomerPresent method.",
        ~eventName=CLICK_TO_PAY_FLOW,
      )
    }

    let consumerIdentity = {
      identityProvider: "SRC",
      identityType: EMAIL_ADDRESS,
      identityValue: customerEmail.contents,
    }

    let isCustomerPresentForMastercard = ref(false)
    let isCustomerPresentForVisa = ref(false)

    let clickToPayData = []

    let mastercardDirectIdentityLookupPromise = mastercardDirectSdk.identityLookup({
      consumerIdentity: consumerIdentity,
    })
    let visaDirectIdentityLookupPromise = switch visaDirectSdk {
    | Some(sdk) => sdk.identityLookup(consumerIdentity)
    | None => Promise.resolve(JSON.Encode.null)
    }

    let identityLookupPromiseResults = await Promise.allSettled([
      mastercardDirectIdentityLookupPromise,
      visaDirectIdentityLookupPromise,
    ])

    switch identityLookupPromiseResults {
    | [mastercardDirectIdentityLookup, visaDirectIdentityLookup] =>
      switch mastercardDirectIdentityLookup {
      | Fulfilled({value}) => {
          isCustomerPresentForMastercard :=
            value
            ->Utils.getDictFromJson
            ->Utils.getBool("consumerPresent", false)

          clickToPayData->Array.push(("mastercard", value))
        }
      | Rejected({reason}) =>
        logger.setLogError(
          ~value=`Direct Mastercard Click to Pay identityLookup failed ${reason
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=CLICK_TO_PAY_FLOW,
        )
      }

      switch visaDirectIdentityLookup {
      | Fulfilled({value}) => {
          isCustomerPresentForVisa :=
            value->Utils.getDictFromJson->Utils.getBool("consumerPresent", false)

          clickToPayData->Array.push(("visa", value))
        }
      | Rejected({reason}) =>
        logger.setLogError(
          ~value=`Direct Visa Click to Pay identityLookup failed ${reason
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=CLICK_TO_PAY_FLOW,
        )
      }
    | _ => ()
    }

    let eligibilityCheckData = [("click_to_pay", clickToPayData->Utils.getJsonFromArrayOfJson)]

    let eligibilityCheckBodyArr = [
      ("eligibility_check_data", eligibilityCheckData->Utils.getJsonFromArrayOfJson),
    ]

    let _ = await PaymentHelpers.fetchEligibilityCheck(
      ~clientSecret,
      ~publishableKey,
      ~logger,
      ~customPodUri,
      ~endpoint,
      ~isPaymentSession=false,
      ~profileId,
      ~authenticationId,
      ~bodyArr=eligibilityCheckBodyArr,
    )

    let isC2pProfilePresent =
      isCustomerPresentForMastercard.contents || isCustomerPresentForVisa.contents

    let customerPresent =
      [("customerPresent", isC2pProfilePresent->JSON.Encode.bool)]->getJsonFromArrayOfJson

    customerPresent
  }

  let getUserType = async () => {
    let getCardsConfig = {
      consumerIdentity: {
        identityProvider: "SRC",
        identityType: EMAIL_ADDRESS,
        identityValue: customerEmail.contents,
      },
    }

    let getUserTypeErrorMessage = "An unknown error occurred while fetching user type."

    try {
      let getCardsResponse = await vsdk.getCards(getCardsConfig)

      let statusCode = switch getCardsResponse.actionCode {
      | PENDING_CONSUMER_IDV => {
          logger.setLogInfo(
            ~value="Triggering customer authentication as part of getUserType flow.",
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          "TRIGGERED_CUSTOMER_AUTHENTICATION"
        }
      | SUCCESS => {
          maskedCards := getMaskedCardsListFromResponse(getCardsResponse)

          let areMaskedCardsPresent = maskedCards.contents->Array.length > 0

          if areMaskedCardsPresent {
            logger.setLogInfo(
              ~value="Recognized cards are present for the customer.",
              ~eventName=CLICK_TO_PAY_FLOW,
            )
            "RECOGNIZED_CARDS_PRESENT"
          } else {
            logger.setLogInfo(
              ~value="Successfully Called getCards but no recognized cards are present for the customer.",
              ~eventName=CLICK_TO_PAY_FLOW,
            )
            "NO_CARDS_PRESENT"
          }
        }
      | ADD_CARD => {
          logger.setLogInfo(
            ~value="No recognized cards are present for the customer.",
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          "NO_CARDS_PRESENT"
        }
      | _ => {
          logger.setLogError(
            ~value=`Get Cards returned error action code ${getCardsResponse.actionCode->getStrFromActionCode}`,
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          "ERROR"
        }
      }

      if statusCode !== "ERROR" {
        [("statusCode", statusCode->JSON.Encode.string)]->getJsonFromArrayOfJson
      } else {
        getClickToPayErrorResponse(
          ~error=getCardsResponse.error,
          ~defaultErrorMessage=getUserTypeErrorMessage,
        )
      }
    } catch {
    | err => {
        logger.setLogError(
          ~value=`Get Cards failed ${err->Utils.formatException->JSON.stringify}`,
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        getFailedSubmitResponse(~errorType="ERROR", ~message=getUserTypeErrorMessage)
      }
    }
  }

  let getRecognizedCards = async () => {
    logger.setLogInfo(
      ~value="Fetching recognized cards for the customer.",
      ~eventName=CLICK_TO_PAY_FLOW,
    )
    maskedCards.contents->Identity.anyTypeToJson
  }

  let validateCustomerAuthentication = async (
    ~otpValue: Types.validateCustomerAuthenticationInput,
  ) => {
    let value = otpValue.value

    let getCardsConfig = {
      consumerIdentity: {
        identityProvider: "SRC",
        identityType: EMAIL_ADDRESS,
        identityValue: customerEmail.contents,
      },
      validationData: value,
    }

    let validateCustomerAuthenticationErrorMessage = "An unknown error occurred during customer authentication validation."

    try {
      let validateCustomerAuthenticationResponse = await vsdk.getCards(getCardsConfig)

      switch validateCustomerAuthenticationResponse.actionCode {
      | SUCCESS =>
        maskedCards := getMaskedCardsListFromResponse(validateCustomerAuthenticationResponse)

        logger.setLogInfo(
          ~value="Customer authentication validated successfully.",
          ~eventName=CLICK_TO_PAY_FLOW,
        )

        maskedCards.contents->Identity.anyTypeToJson
      | _ =>
        logger.setLogError(
          ~value=`Validate Customer Authentication returned error action code ${validateCustomerAuthenticationResponse.actionCode->getStrFromActionCode}`,
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        getClickToPayErrorResponse(
          ~error=validateCustomerAuthenticationResponse.error,
          ~defaultErrorMessage=validateCustomerAuthenticationErrorMessage,
        )
      }
    } catch {
    | err => {
        logger.setLogError(
          ~value=`Validate Customer Authentication failed ${err
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        getFailedSubmitResponse(
          ~errorType="ERROR",
          ~message=validateCustomerAuthenticationErrorMessage,
        )
      }
    }
  }

  let checkoutWithCard = async (~token, ~srcDigitalCardId, ~rememberMe, ~windowRef) => {
    let checkoutWithCardErrorMessage = "An unknown error occurred during checkout with card."

    try {
      let clickToPayWindow = switch windowRef->Nullable.toOption {
      | Some(window) => {
          logger.setLogInfo(
            ~value="Using provided window reference for Click to Pay checkout flow.",
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          Some(window)
        }
      | None => {
          logger.setLogInfo(
            ~value="No window reference provided. Opening new window for Click to Pay checkout flow.",
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          if clickToPayWindowRef.contents->Nullable.toOption->Option.isNone {
            handleOpenClickToPayWindow()
          }

          clickToPayWindowRef.contents->Nullable.toOption
        }
      }

      switch clickToPayWindow {
      | Some(window) => {
          let clickToPayProvider = VISA

          let consumer: consumer = {
            fullName: "",
            emailAddress: customerEmail.contents,
            mobileNumber: {
              phoneNumber: "",
              countryCode: "",
            },
          }

          let checkoutWithCardResponse = await checkoutVisaUnified(
            ~srcDigitalCardId,
            ~clickToPayToken=token,
            ~windowRef=window,
            ~rememberMe=rememberMe->Option.getOr(false),
            ~orderId=clientSecret,
            ~consumer,
            ~request3DSAuthentication=initClickToPaySessionInput.request3DSAuthentication->Option.getOr(
              true,
            ),
          )

          handleCloseClickToPayWindow()

          let actionCode =
            checkoutWithCardResponse->Utils.getDictFromJson->Utils.getString("actionCode", "")
          switch actionCode {
          | "SUCCESS" => {
              logger.setLogInfo(
                ~value={
                  "message": "Checkout successful",
                  "scheme": clickToPayProvider,
                }
                ->JSON.stringifyAny
                ->Option.getOr("Failed to stringify successful checkout message"),
                ~eventName=CLICK_TO_PAY_FLOW,
              )

              let dict = checkoutWithCardResponse->Utils.getDictFromJson

              let visaClickToPayBodyArr = PaymentBody.visaClickToPayAuthenticationBody(
                ~encryptedPayload=dict->Utils.getString("checkoutResponse", ""),
              )

              let authenticationSyncResponse = await PaymentHelpers.fetchAuthenticationSync(
                ~clientSecret,
                ~publishableKey,
                ~logger,
                ~customPodUri,
                ~endpoint,
                ~isPaymentSession=false,
                ~profileId,
                ~authenticationId,
                ~merchantId,
                ~bodyArr=visaClickToPayBodyArr,
              )

              authenticationSyncResponse->transformKeysWithoutModifyingValue(CamelCase)
            }
          | _ => {
              logger.setLogError(
                ~value={
                  "message": `Visa checkout failed with card, Action Code -> ${actionCode}`,
                  "scheme": clickToPayProvider,
                }
                ->JSON.stringifyAny
                ->Option.getOr("Failed to stringify failed checkout message"),
                ~eventName=CLICK_TO_PAY_FLOW,
              )

              let errorMsg = switch actionCode {
              | "CHANGE_CARD" => "Consumer wishes to select an alternative card."
              | "SWITCH_CONSUMER" => "Consumer wishes to change Click to Pay profile."
              | _ => checkoutWithCardErrorMessage
              }

              getFailedSubmitResponse(~errorType=actionCode, ~message=errorMsg)
            }
          }
        }
      | None => {
          logger.setLogError(
            ~value="Error trying to open window for Click to Pay checkout flow.",
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
        }
      }
    } catch {
    | err => {
        logger.setLogError(
          ~value=`Checkout with Card failed ${err->Utils.formatException->JSON.stringify}`,
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        handleCloseClickToPayWindow()
        getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
      }
    }
  }

  let signOut = async () => {
    let unbindAppInstanceErrorMessage = "Failed to sign out customer."
    try {
      let unbindAppInstanceResponse = await vsdk.unbindAppInstance()
      switch unbindAppInstanceResponse.error {
      | Some(err) => {
          logger.setLogError(
            ~value=`Failed to sign out Customer ${err.reason->Option.getOr("Unknown Error")}`,
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          getClickToPayErrorResponse(
            ~error=unbindAppInstanceResponse.error,
            ~defaultErrorMessage=unbindAppInstanceErrorMessage,
          )
        }
      | None => {
          logger.setLogInfo(
            ~value="Customer signed out successfully from Click to Pay.",
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          let customerSignedOut = [("recognized", false->JSON.Encode.bool)]->getJsonFromArrayOfJson

          maskedCards := []

          customerSignedOut
        }
      }
    } catch {
    | err =>
      logger.setLogError(
        ~value=`Failed to sign out Customer ${err->Utils.formatException->JSON.stringify}`,
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      getFailedSubmitResponse(~errorType="ERROR", ~message=unbindAppInstanceErrorMessage)
    }
  }

  let defaultInitClickToPaySession = await Promise.make((resolve, _) => {
    switch ctpToken {
    | Some(token) => {
        customerEmail := token.email

        let getSessionObject = (
          visaDirectSdk: option<OrcaPaymentPage.ClickToPayHelpers.visaDirect>,
        ) => {
          {
            isCustomerPresent: isCustomerPresentInput => {
              let email =
                isCustomerPresentInput->Option.flatMap(customerInput => Some(customerInput.email))

              isCustomerPresent(~visaDirectSdk, ~email)
            },
            getUserType: () => getUserType(),
            getRecognizedCards: () => getRecognizedCards(),
            validateCustomerAuthentication: otpValue => validateCustomerAuthentication(~otpValue),
            checkoutWithCard: checkoutWithCardInput =>
              checkoutWithCard(
                ~token,
                ~srcDigitalCardId=checkoutWithCardInput.srcDigitalCardId,
                ~rememberMe=checkoutWithCardInput.rememberMe,
                ~windowRef=checkoutWithCardInput.windowRef,
              ),
            signOut: () => signOut(),
          }->Identity.anyTypeToJson
        }

        switch shouldLoadScripts {
        | false =>
          switch ClickToPayHelpers.initializedVSDK->Nullable.toOption {
          | Some(true) =>
            resolve(getSessionObject(ClickToPayHelpers.windowVisaDirectSdk->Nullable.toOption))
          | _ =>
            let failedErrorResponse = getFailedSubmitResponse(
              ~errorType="SESSION_NOT_FOUND",
              ~message="No Active Click to Pay session found.",
            )
            resolve(failedErrorResponse)
          }
        | true =>
          ClickToPayHelpers.loadVisaScript(
            token,
            () => {
              let initConfig = ClickToPayHelpers.getVisaInitConfig(token, Some(clientSecret))

              ClickToPayHelpers.vsdk.initialize(initConfig)
              ->then(async _ => {
                let mastercardDirectInitData = {
                  srciTransactionId: clientSecret,
                  srcInitiatorId: GlobalVars.isProd
                    ? "78fbc211-73e1-4c3a-bc5c-60a7921afb97"
                    : "544ef81a-dae0-4f26-9511-bfbdba3d62b5",
                  srciDpaId: GlobalVars.isProd
                    ? "d693c074-8945-4ec7-aa7d-a0a85e636a62"
                    : "b6e06cc6-3018-4c4c-bbf5-9fb232615090",
                  dpaTransactionOptions: {
                    dpaLocale: token.locale,
                  },
                }

                let visaDirectSdk = ClickToPayHelpers.createVisaDirectSRCIAdapter()
                let visaDirectInitData = {
                  srciTransactionId: clientSecret,
                  srcInitiatorId: token.dpaId,
                  srciDpaId: token.dpaName,
                }

                let mastercardInitPromise = ClickToPayHelpers.mastercardDirectSdk.init(
                  mastercardDirectInitData,
                )
                let visaInitPromise = visaDirectSdk.init(visaDirectInitData)

                let promiseResults = await Promise.allSettled([
                  mastercardInitPromise,
                  visaInitPromise,
                ])

                switch promiseResults {
                | [mastercardPromiseResponse, visaPromiseResponse] => {
                    switch mastercardPromiseResponse {
                    | Rejected({reason}) =>
                      logger.setLogError(
                        ~value=`Direct Mastercard Click to Pay SDK initialization failed ${reason
                          ->Utils.formatException
                          ->JSON.stringify}`,
                        ~eventName=CLICK_TO_PAY_FLOW,
                      )
                    | Fulfilled(_) => ()
                    }

                    switch visaPromiseResponse {
                    | Rejected({reason}) =>
                      logger.setLogError(
                        ~value=`Direct Visa Click to Pay SDK initialization failed ${reason
                          ->Utils.formatException
                          ->JSON.stringify}`,
                        ~eventName=CLICK_TO_PAY_FLOW,
                      )
                    | Fulfilled(_) => ()
                    }
                  }
                | _ => ()
                }

                Types.window["initializedVSDK"] = true
                Types.window["visaDirectSdk"] = visaDirectSdk
                resolve(getSessionObject(Some(visaDirectSdk)))
                JSON.Encode.null
              })
              ->catch(_ => {
                let failedErrorResponse = getFailedSubmitResponse(
                  ~errorType="ERROR",
                  ~message="An unknown error occurred while initializing Click to Pay session.",
                )

                resolve(failedErrorResponse)

                Promise.resolve(JSON.Encode.null)
              })
              ->ignore
            },
            () => {
              let failedErrorResponse = getFailedSubmitResponse(
                ~errorType="ERROR",
                ~message="Failed to load Click to Pay script.",
              )

              resolve(failedErrorResponse)
            },
          )
        }
      }
    | None => {
        let failedErrorResponse = getFailedSubmitResponse(
          ~errorType="ERROR",
          ~message="An error occured while trying to fetch Click to Pay Details",
        )

        resolve(failedErrorResponse)
      }
    }
  })

  defaultInitClickToPaySession
}

let getActiveClickToPaySession = async (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
) => {
  await initClickToPaySession(
    ~clientSecret,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
    ~profileId,
    ~authenticationId,
    ~merchantId,
    ~initClickToPaySessionInput={request3DSAuthentication: None},
    ~shouldLoadScripts=false,
  )
}

Types.window["ClickToPayAuthenticationSession"] = initClickToPaySession
