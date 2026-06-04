open Types
open Promise
open Utils
open ClickToPayHelpers

let clickToPayTokenCache = Dict.make()

let setClickToPayTokenWithDebounce = (key, promise) => {
  clickToPayTokenCache->Dict.set(key, promise)
  setTimeout(() => {
    if clickToPayTokenCache->Dict.get(key)->Option.isSome {
      clickToPayTokenCache->Dict.delete(key)
    }
  }, 30000)->ignore
}

let customerEmail = ref("")
let maskedCards = ref([])

// Module-level refs tracking direct SDK load/init state — private to this module,
// not exposed on window. Set during initClickToPaySession, read by isCustomerPresent.
let directSdkLoadStatusRef: ref<option<ClickToPayHelpers.directSdkLoadStatus>> = ref(
  (None: option<ClickToPayHelpers.directSdkLoadStatus>),
)
let mastercardDirectInitFailedRef = ref(false)
let visaDirectInitFailedRef = ref(false)

let isCustomerPresentForMastercard = ref(false)
let isCustomerPresentForVisa = ref(false)
let hadIdentityLookupError = ref(false)

let maskEmail = (email: string): string => {
  let parts = email->String.split("@")
  switch (parts->Array.get(0), parts->Array.get(1)) {
  | (Some(local), Some(domain)) =>
    switch local->String.length {
    | 0 | 1 => email
    | len =>
      let maskCount = len - 2 > 0 ? len - 2 : 0
      local->String.slice(~start=0, ~end=1) ++
      Array.make(~length=maskCount, "*")->Array.join("") ++
      local->String.sliceToEnd(~start=len - 1) ++
      "@" ++
      domain
    }
  | _ => email
  }
}

let initClickToPaySession = async (
  ~clientSecret,
  ~publishableKey,
  ~logger: HyperLoggerTypes.loggerMake,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
  ~shouldLoadScripts=true,
) => {
  if shouldLoadScripts {
    logger.setLogInfo(
      ~value="Initializing Click to Pay Session",
      ~eventName=INIT_CLICK_TO_PAY_SESSION,
    )
    logger.setLogDebug(
      ~value="Initializing Click to Pay Session",
      ~eventName=INIT_CLICK_TO_PAY_SESSION_INIT,
    )
  }

  let key = `${clientSecret}_${authenticationId}`

  let handleApi = () =>
    PaymentHelpers.fetchEnabledAuthnMethodsToken(
      ~clientSecret,
      ~publishableKey,
      ~logger,
      ~customPodUri,
      ~endpoint,
      ~isPaymentSession=false,
      ~profileId,
      ~authenticationId,
    )

  let data = await (
    if shouldLoadScripts {
      handleApi()
    } else {
      logger.setLogDebug(
        ~value="Fetching existing click to pay token without loading scripts",
        ~eventName=GET_EXISTING_CLICK_TO_PAY_TOKEN,
      )
      switch clickToPayTokenCache->Dict.get(key) {
      | Some(promise) => promise
      | None =>
        let promise = handleApi()
        setClickToPayTokenWithDebounce(key, promise)
        promise
      }
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

  let getUserType = async () => {
    logger.setLogInfo(~value="Initializing getUserType method", ~eventName=GET_USER_TYPE)
    logger.setLogDebug(~value="Initializing getUserType method", ~eventName=GET_USER_TYPE_INIT)
    let getCardsConfig = {
      consumerIdentity: {
        identityProvider: "SRC",
        identityType: EMAIL_ADDRESS,
        identityValue: customerEmail.contents,
      },
    }

    let parseMaskedValidationChannel = (raw: string) => {
      if raw->String.length == 0 {
        []->getJsonFromArrayOfJson
      } else {
        let parts = raw->String.split(",")
        let email = parts->Array.find(p => p->String.includes("@"))
        let phone = parts->Array.find(p => !(p->String.includes("@")))
        let withEmail = switch email {
        | Some(e) => [("email", e->JSON.Encode.string)]
        | None => []
        }
        let withPhone = switch phone {
        | Some(p) => withEmail->Array.concat([("phoneNumber", p->JSON.Encode.string)])
        | None => withEmail
        }
        withPhone->getJsonFromArrayOfJson
      }
    }

    let getUserTypeErrorMessage = "An unknown error occurred while fetching user type."
    try {
      logger.setLogDebug(
        ~value="Initializing Visa Unified Click to Pay getCards method",
        ~eventName=VISA_UCTP_GET_CARDS_INIT,
      )
      let getCardsResponse = await vsdk.getCards(getCardsConfig)
      logger.setLogDebug(
        ~value=`Unified Click to Pay Get Cards Response: ${getCardsResponse
          ->Identity.anyTypeToJson
          ->JSON.stringify}`,
        ~eventName=VISA_UCTP_GET_CARDS_RETURNED,
      )

      let statusCode = switch getCardsResponse.actionCode {
      | PENDING_CONSUMER_IDV => "TRIGGERED_CUSTOMER_AUTHENTICATION"
      | SUCCESS => {
          maskedCards := getMaskedCardsListFromResponse(getCardsResponse)

          let areMaskedCardsPresent = maskedCards.contents->Array.length > 0

          if areMaskedCardsPresent {
            "RECOGNIZED_CARDS_PRESENT"
          } else {
            "NO_CARDS_PRESENT"
          }
        }
      | ADD_CARD => "NO_CARDS_PRESENT"
      | _ => "ERROR"
      }

      if statusCode !== "ERROR" {
        let baseFields = [("statusCode", statusCode->JSON.Encode.string)]

        let enrichedFields = switch getCardsResponse.actionCode {
        | PENDING_CONSUMER_IDV => {
            let channelFields =
              getCardsResponse.maskedValidationChannel
              ->Option.map(parseMaskedValidationChannel)
              ->Option.map(parsed => [("maskedValidationChannel", parsed)])
              ->Option.getOr([])

            // ReScript records compile to JS objects at runtime, so Identity.anyTypeToJson serializes them as-is
            let svchFields =
              getCardsResponse.supportedValidationChannels
              ->Option.map(channels => [
                ("supportedValidationChannels", channels->Identity.anyTypeToJson),
              ])
              ->Option.getOr([])

            baseFields->Array.concat(channelFields)->Array.concat(svchFields)
          }
        | _ => baseFields
        }

        let responseJson = enrichedFields->getJsonFromArrayOfJson

        logger.setLogDebug(
          ~value=`getUserType returned: ${responseJson->JSON.stringify}`,
          ~eventName=GET_USER_TYPE_RETURNED,
        )
        responseJson
      } else {
        logger.setLogError(
          ~value=`Error while calling getCards method from Visa Unified Click to Pay: ${getCardsResponse
            ->Identity.anyTypeToJson
            ->JSON.stringify}`,
          ~eventName=GET_USER_TYPE_RETURNED,
        )
        getClickToPayErrorResponse(
          ~error=getCardsResponse.error,
          ~defaultErrorMessage=getUserTypeErrorMessage,
        )
      }
    } catch {
    | err => {
        logger.setLogError(
          ~value=`Error while calling getCards method from Visa Unified Click to Pay: ${err
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=VISA_UCTP_GET_CARDS_RETURNED,
        )
        logger.setLogError(
          ~value=`Error while calling getCards method from Visa Unified Click to Pay: ${err
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=GET_USER_TYPE_RETURNED,
        )
        getFailedSubmitResponse(~errorType="ERROR", ~message=getUserTypeErrorMessage)
      }
    }
  }

  let getRecognizedCards = async () => {
    logger.setLogInfo(
      ~value="Initializing getRecognizedCards method",
      ~eventName=GET_RECOGNISED_CARDS,
    )
    logger.setLogDebug(
      ~value="Initializing getRecognizedCards method",
      ~eventName=GET_RECOGNISED_CARDS_INIT,
    )

    let visaCount =
      maskedCards.contents
      ->Array.filter(card =>
        card.paymentCardDescriptor->String.toLowerCase->String.includes("visa")
      )
      ->Array.length
    logger.setLogDebug(~value=visaCount->Int.toString, ~eventName=RECOGNISED_VISA_CARDS_COUNT)

    let mastercardCount =
      maskedCards.contents
      ->Array.filter(card =>
        card.paymentCardDescriptor->String.toLowerCase->String.includes("mastercard")
      )
      ->Array.length
    logger.setLogDebug(
      ~value=mastercardCount->Int.toString,
      ~eventName=RECOGNISED_MASTERCARD_CARDS_COUNT,
    )

    logger.setLogDebug(
      ~value=maskedCards.contents->Array.length->Int.toString,
      ~eventName=GET_RECOGNISED_CARDS_RETURNED,
    )
    maskedCards.contents->Identity.anyTypeToJson
  }

  let validateCustomerAuthentication = async (
    ~otpValue: Types.validateCustomerAuthenticationInput,
  ) => {
    logger.setLogInfo(
      ~value="Initializing validateCustomerAuthentication method",
      ~eventName=VALIDATE_CUSTOMER_AUTHENTICATION,
    )
    logger.setLogDebug(
      ~value="Initializing validateCustomerAuthentication method",
      ~eventName=VALIDATE_CUSTOMER_AUTHENTICATION_INIT,
    )
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
      logger.setLogDebug(
        ~value="Initializing Visa Unified Click to Pay getCards method for customer authentication validation",
        ~eventName=VISA_UCTP_GET_CARDS_VALIDATE_INIT,
      )
      let validateCustomerAuthenticationResponse = await vsdk.getCards(getCardsConfig)

      switch validateCustomerAuthenticationResponse.actionCode {
      | SUCCESS =>
        maskedCards := getMaskedCardsListFromResponse(validateCustomerAuthenticationResponse)

        let visaCount =
          maskedCards.contents
          ->Array.filter(card =>
            card.paymentCardDescriptor->String.toLowerCase->String.includes("visa")
          )
          ->Array.length
        logger.setLogDebug(~value=visaCount->Int.toString, ~eventName=RECOGNISED_VISA_CARDS_COUNT)
        let mastercardCount =
          maskedCards.contents
          ->Array.filter(card =>
            card.paymentCardDescriptor->String.toLowerCase->String.includes("mastercard")
          )
          ->Array.length
        logger.setLogDebug(
          ~value=mastercardCount->Int.toString,
          ~eventName=RECOGNISED_MASTERCARD_CARDS_COUNT,
        )

        logger.setLogDebug(
          ~value=maskedCards.contents->Array.length->Int.toString,
          ~eventName=VISA_UCTP_GET_CARDS_VALIDATE_RETURNED,
        )
        logger.setLogDebug(
          ~value=maskedCards.contents->Array.length->Int.toString,
          ~eventName=VALIDATE_CUSTOMER_AUTHENTICATION_RETURNED,
        )

        maskedCards.contents->Identity.anyTypeToJson
      | _ =>
        logger.setLogError(
          ~value=`Error returned from Visa Unified Click to Pay Get Cards during validation: ${validateCustomerAuthenticationResponse
            ->Identity.anyTypeToJson
            ->JSON.stringify}`,
          ~eventName=VISA_UCTP_GET_CARDS_VALIDATE_RETURNED,
        )
        logger.setLogError(
          ~value=`Error returned from Visa Unified Click to Pay Get Cards during validation: ${validateCustomerAuthenticationResponse
            ->Identity.anyTypeToJson
            ->JSON.stringify}`,
          ~eventName=VALIDATE_CUSTOMER_AUTHENTICATION_RETURNED,
        )
        getClickToPayErrorResponse(
          ~error=validateCustomerAuthenticationResponse.error,
          ~defaultErrorMessage=validateCustomerAuthenticationErrorMessage,
        )
      }
    } catch {
    | err => {
        logger.setLogError(
          ~value=`Validate Customer Authentication Failed: ${err
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=VISA_UCTP_GET_CARDS_VALIDATE_RETURNED,
        )
        logger.setLogError(
          ~value=`Validate Customer Authentication Failed: ${err
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=VALIDATE_CUSTOMER_AUTHENTICATION_RETURNED,
        )
        getFailedSubmitResponse(
          ~errorType="ERROR",
          ~message=validateCustomerAuthenticationErrorMessage,
        )
      }
    }
  }

  let checkoutWithCard = async (~token, ~srcDigitalCardId, ~rememberMe, ~windowRef) => {
    logger.setLogInfo(
      ~value=`Initializing checkoutWithCard method with rememberMe as: ${rememberMe
        ->Option.getOr(false)
        ->getStringFromBool}`,
      ~eventName=CHECKOUT,
    )
    logger.setLogDebug(
      ~value=`Initializing checkoutWithCard method with rememberMe as: ${rememberMe
        ->Option.getOr(false)
        ->getStringFromBool}`,
      ~eventName=CHECKOUT_INIT,
    )

    let checkoutWithCardErrorMessage = "An unknown error occurred during checkout with card."

    try {
      logger.setLogDebug(
        ~value=`Checking if window reference is provided for Click to Pay checkout flow.`,
        ~eventName=CHECK_WINDOW_INIT,
      )
      let clickToPayWindow = switch windowRef->Nullable.toOption {
      | Some(window) => {
          logger.setLogDebug(
            ~value="Using provided window reference for Click to Pay checkout flow.",
            ~eventName=CHECK_WINDOW_RETURNED,
          )
          Some(window)
        }
      | None => {
          logger.setLogDebug(
            ~value="No window reference provided for Click to Pay checkout flow. Opening new window.",
            ~eventName=CREATE_WINDOW,
          )
          if clickToPayWindowRef.contents->Nullable.toOption->Option.isNone {
            handleOpenClickToPayWindow(~logger)
          }

          logger.setLogDebug(
            ~value="Using window reference which we created.",
            ~eventName=CHECK_WINDOW_RETURNED,
          )
          clickToPayWindowRef.contents->Nullable.toOption
        }
      }

      logger.setLogDebug(
        ~value="Rechecking if window reference is available for Click to Pay checkout flow after attempting to open window if it was not provided.",
        ~eventName=RECHECK_WINDOW_INIT,
      )
      switch clickToPayWindow {
      | Some(window) => {
          logger.setLogDebug(
            ~value="Window reference is available for Click to Pay checkout flow. Proceeding with checkout.",
            ~eventName=RECHECK_WINDOW_RETURNED,
          )

          let consumer: consumer = {
            fullName: "",
            emailAddress: customerEmail.contents,
            mobileNumber: {
              phoneNumber: "",
              countryCode: "",
            },
          }

          logger.setLogDebug(
            ~value="Initiating Visa Unified Click to Pay checkout with card",
            ~eventName=VISA_UCTP_CHECKOUT_INIT,
          )

          let matchedCard =
            maskedCards.contents->Array.find(card => card.srcDigitalCardId === srcDigitalCardId)
          switch matchedCard {
          | Some(card) =>
            logger.setLogDebug(
              ~value=`srcDigitalCardId ${srcDigitalCardId} found in maskedCards list. Card brand: ${card.digitalCardData.descriptorName}`,
              ~eventName=VISA_UCTP_CHECKOUT_CARD_MATCH,
            )
          | None =>
            logger.setLogDebug(
              ~value=`srcDigitalCardId ${srcDigitalCardId} not found in maskedCards list.`,
              ~eventName=VISA_UCTP_CHECKOUT_CARD_MATCH,
            )
          }

          // Create the timeout promise that will reject if window doesn't navigate within 30 seconds
          let timeoutPromise = createWindowTimeoutPromise()

          // Race the checkout against the timeout to ensure we don't hang indefinitely
          let checkoutWithCardResponse = await Promise.race([
            checkoutVisaUnified(
              ~srcDigitalCardId,
              ~clickToPayToken=token,
              ~windowRef=window,
              ~rememberMe=rememberMe->Option.getOr(false),
              ~orderId=clientSecret,
              ~consumer,
              ~request3DSAuthentication=initClickToPaySessionInput.request3DSAuthentication->Option.getOr(
                true,
              ),
            ),
            timeoutPromise,
          ])
          let actionCode =
            checkoutWithCardResponse->Utils.getDictFromJson->Utils.getString("actionCode", "")
          logger.setLogDebug(
            ~value=`Visa Unified Click to Pay Checkout Returned with actionCode: ${actionCode}`,
            ~eventName=VISA_UCTP_CHECKOUT_RETURNED,
          )

          logger.setLogDebug(
            ~value="Closing Click to Pay window after checkout response is received.",
            ~eventName=CLOSE_WINDOW,
          )
          handleCloseClickToPayWindow()

          switch actionCode {
          | "SUCCESS" => {
              logger.setLogDebug(
                ~value=`Visa Unified Click to Pay Checkout Returned with Successful action code.`,
                ~eventName=VISA_UCTP_CHECKOUT_RESPONSE,
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
              Types.window["initializedVSDK"] = false
              logger.setLogDebug(
                ~value="Received response from authentication sync call after checkout with card.",
                ~eventName=CHECKOUT_RETURNED,
              )
              authenticationSyncResponse->transformKeysWithoutModifyingValue(CamelCase)
            }
          | _ => {
              logger.setLogError(
                ~value=`Visa Unified Click to Pay checkout with card failed: ${checkoutWithCardResponse
                  ->Identity.anyTypeToJson
                  ->JSON.stringify}`,
                ~eventName=VISA_UCTP_CHECKOUT_RESPONSE,
              )
              logger.setLogError(
                ~value=`Visa Unified Click to Pay checkout with card failed: ${checkoutWithCardResponse
                  ->Identity.anyTypeToJson
                  ->JSON.stringify}`,
                ~eventName=CHECKOUT_RETURNED,
              )

              let errorMsg = switch actionCode {
              | "CHANGE_CARD" => "Consumer wishes to select an alternative card."
              | "SWITCH_CONSUMER" => "Consumer wishes to change Click to Pay profile."
              | _ => checkoutWithCardErrorMessage
              }
              if actionCode !== "CHANGE_CARD" && actionCode !== "SWITCH_CONSUMER" {
                Types.window["initializedVSDK"] = false
              }

              getFailedSubmitResponse(~errorType=actionCode, ~message=errorMsg)
            }
          }
        }
      | None => {
          logger.setLogError(
            ~value="Error trying to open window for Click to Pay checkout flow. No window reference is available.",
            ~eventName=RECHECK_WINDOW_RETURNED,
          )
          logger.setLogError(
            ~value=`Error trying to open window for Click to Pay checkout flow. No window reference is available.`,
            ~eventName=CHECKOUT_RETURNED,
          )
          getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
        }
      }
    } catch {
    | err => {
        let (closeWindowLogValue, checkoutReturnedLogValue, errorMessage) = switch err {
        | WindowTimeoutError(message) => (
            "Closing window after timeout during checkoutWithCard",
            "Click to Pay checkout failed due to window timeout.",
            message,
          )
        | _ => (
            `Closing window if present after error during checkoutWithCard: ${err
              ->Utils.formatException
              ->JSON.stringify}`,
            `Error during checkout with card in Visa Unified Click to Pay: ${err
              ->Utils.formatException
              ->JSON.stringify}`,
            checkoutWithCardErrorMessage,
          )
        }

        logger.setLogError(~value=closeWindowLogValue, ~eventName=CLOSE_WINDOW)
        handleCloseClickToPayWindow()
        logger.setLogError(~value=checkoutReturnedLogValue, ~eventName=CHECKOUT_RETURNED)
        Types.window["initializedVSDK"] = false
        getFailedSubmitResponse(~errorType="ERROR", ~message=errorMessage)
      }
    }
  }

  let signOut = async () => {
    logger.setLogInfo(~value="Initializing signOut method", ~eventName=SIGN_OUT)
    logger.setLogDebug(~value="Initializing signOut method", ~eventName=SIGN_OUT_INIT)
    let unbindAppInstanceErrorMessage = "Failed to sign out customer."
    try {
      logger.setLogDebug(
        ~value="Unbinding Click to Pay App Instance for sign out",
        ~eventName=VISA_UCTP_UNBIND_APP_INSTANCE_INIT,
      )
      let unbindAppInstanceResponse = await vsdk.unbindAppInstance()
      switch unbindAppInstanceResponse.error {
      | Some(_err) => {
          logger.setLogError(
            ~value=`Error unbinding Click to Pay App Instance during sign out: ${unbindAppInstanceResponse
              ->Identity.anyTypeToJson
              ->JSON.stringify}`,
            ~eventName=VISA_UCTP_UNBIND_APP_INSTANCE_RETURNED,
          )
          logger.setLogError(
            ~value=`Error unbinding Click to Pay App Instance during sign out: ${unbindAppInstanceResponse
              ->Identity.anyTypeToJson
              ->JSON.stringify}`,
            ~eventName=SIGN_OUT_RETURNED,
          )
          getClickToPayErrorResponse(
            ~error=unbindAppInstanceResponse.error,
            ~defaultErrorMessage=unbindAppInstanceErrorMessage,
          )
        }
      | None => {
          logger.setLogDebug(
            ~value="Successfully unbound Click to Pay App Instance for sign out",
            ~eventName=VISA_UCTP_UNBIND_APP_INSTANCE_RETURNED,
          )
          logger.setLogDebug(
            ~value="Successfully unbound Click to Pay App Instance for sign out",
            ~eventName=SIGN_OUT_RETURNED,
          )
          let customerSignedOut = [("recognized", false->JSON.Encode.bool)]->getJsonFromArrayOfJson

          maskedCards := []

          customerSignedOut
        }
      }
    } catch {
    | err =>
      logger.setLogError(
        ~value=`Failed to sign out Customer: ${err
          ->Utils.formatException
          ->JSON.stringify}`,
        ~eventName=VISA_UCTP_UNBIND_APP_INSTANCE_RETURNED,
      )
      logger.setLogError(
        ~value=`Failed to sign out Customer: ${err
          ->Utils.formatException
          ->JSON.stringify}`,
        ~eventName=SIGN_OUT_RETURNED,
      )
      getFailedSubmitResponse(~errorType="ERROR", ~message=unbindAppInstanceErrorMessage)
    }
  }

  let defaultInitClickToPaySession = await Promise.make((resolve, _) => {
    switch ctpToken {
    | Some(token) => {
        customerEmail := token.email

        let getSessionObject = () => {
          {
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
            token: token->Identity.anyTypeToJson,
          }->Identity.anyTypeToJson
        }

        switch shouldLoadScripts {
        | false =>
          switch ClickToPayHelpers.initializedVSDK->Nullable.toOption {
          | Some(true) => {
              logger.setLogDebug(
                ~value="Active Click to Pay session found",
                ~eventName=GET_ACTIVE_CLICK_TO_PAY_SESSION_RETURNED,
              )
              resolve(getSessionObject())
            }
          | _ => {
              logger.setLogError(
                ~value="No active Click to Pay session found",
                ~eventName=GET_ACTIVE_CLICK_TO_PAY_SESSION_RETURNED,
              )
              let failedErrorResponse = getFailedSubmitResponse(
                ~errorType="SESSION_NOT_FOUND",
                ~message="No Active Click to Pay session found.",
              )
              resolve(failedErrorResponse)
            }
          }
        | true =>
          logger.setLogDebug(
            ~value="Loading Visa Unified Click to Pay script",
            ~eventName=VISA_UCTP_LOAD_SCRIPT_INIT,
          )
          ClickToPayHelpers.loadVisaScript(
            token,
            () => {
              // Wrap the entire callback in try/catch to prevent unresolved Promise.make
              logger.setLogDebug(
                ~value="Successfully loaded Visa Unified Click to Pay script",
                ~eventName=VISA_UCTP_LOAD_SCRIPT_RETURNED,
              )
              try {
                let initConfig = ClickToPayHelpers.getVisaInitConfig(token, Some(clientSecret))

                logger.setLogDebug(
                  ~value="Initializing Visa Unified Click to Pay",
                  ~eventName=VISA_UCTP_INIT,
                )
                ClickToPayHelpers.vsdk.initialize(initConfig)
                ->then(async _ => {
                  logger.setLogDebug(
                    ~value="Successfully initialized Visa Unified Click to Pay",
                    ~eventName=VISA_UCTP_RETURNED,
                  )

                  logger.setLogDebug(
                    ~value="Successfully completed Click to Pay session initialization",
                    ~eventName=INIT_CLICK_TO_PAY_SESSION_RETURNED,
                  )
                  Types.window["initializedVSDK"] = true
                  resolve(getSessionObject())
                  JSON.Encode.null
                })
                ->catch(err => {
                  logger.setLogError(
                    ~value=`Failed to initialize Visa Unified Click to Pay: ${err
                      ->Utils.formatException
                      ->JSON.stringify}`,
                    ~eventName=VISA_UCTP_RETURNED,
                  )
                  logger.setLogError(
                    ~value=`Failed to initialize Visa Unified Click to Pay: ${err
                      ->Utils.formatException
                      ->JSON.stringify}`,
                    ~eventName=INIT_CLICK_TO_PAY_SESSION_RETURNED,
                  )
                  // Reset UCTP session global
                  Types.window["initializedVSDK"] = false
                  let failedErrorResponse = getFailedSubmitResponse(
                    ~errorType="ERROR",
                    ~message="An unknown error occurred while initializing Click to Pay session.",
                  )
                  resolve(failedErrorResponse)

                  Promise.resolve(JSON.Encode.null)
                })
                ->ignore
              } catch {
              | err => {
                  logger.setLogError(
                    ~value=`Unexpected error during Click to Pay session initialization: ${err
                      ->Utils.formatException
                      ->JSON.stringify}`,
                    ~eventName=INIT_CLICK_TO_PAY_SESSION_RETURNED,
                  )
                  // Reset UCTP session global
                  Types.window["initializedVSDK"] = false
                  let failedErrorResponse = getFailedSubmitResponse(
                    ~errorType="ERROR",
                    ~message="An unexpected error occurred while initializing Click to Pay session.",
                  )
                  resolve(failedErrorResponse)
                }
              }
            },
            () => {
              logger.setLogError(
                ~value="Failed to load Visa Unified Click to Pay Script",
                ~eventName=VISA_UCTP_LOAD_SCRIPT_RETURNED,
              )
              logger.setLogError(
                ~value="Failed to load Visa Unified Click to Pay Script",
                ~eventName=INIT_CLICK_TO_PAY_SESSION_RETURNED,
              )
              // Reset UCTP session global
              Types.window["initializedVSDK"] = false
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
        logger.setLogError(
          ~value="An error occured while trying to fetch Click to Pay Details",
          ~eventName=INIT_CLICK_TO_PAY_SESSION_RETURNED,
        )
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
  ~logger: HyperLoggerTypes.loggerMake,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
) => {
  logger.setLogInfo(
    ~value="Getting Active Click to Pay Session",
    ~eventName=GET_ACTIVE_CLICK_TO_PAY_SESSION,
  )
  logger.setLogDebug(
    ~value="Getting Active Click to Pay Session",
    ~eventName=GET_ACTIVE_CLICK_TO_PAY_SESSION_INIT,
  )
  await initClickToPaySession(
    ~clientSecret,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
    ~profileId,
    ~authenticationId,
    ~merchantId,
    ~initClickToPaySessionInput,
    ~shouldLoadScripts=false,
  )
}

Types.window["ClickToPayAuthenticationSession"] = initClickToPaySession

let initClickToPayDCTPSession = async (
  ~params: JSON.t,
  ~logger: HyperLoggerTypes.loggerMake,
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
) => {
  // Step 1 — Reset module-level refs
  directSdkLoadStatusRef := (None: option<ClickToPayHelpers.directSdkLoadStatus>)
  mastercardDirectInitFailedRef := false
  visaDirectInitFailedRef := false
  isCustomerPresentForMastercard := false
  isCustomerPresentForVisa := false
  hadIdentityLookupError := false

  logger.setLogInfo(
    ~value="Initializing Click to Pay DCTP Session",
    ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION,
  )
  logger.setLogDebug(
    ~value="Initializing Click to Pay DCTP Session",
    ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION_INIT,
  )

  // Step 2 — Extract token from params wrapper
  // Expected shape: { "token": <clickToPayToken JSON> }
  // This wrapper allows future callers to pass additional parameters without a signature change.
  let token = params->Utils.getDictFromJson->Dict.get("token")->Option.getOr(JSON.Encode.null)
  if token === JSON.Encode.null {
    logger.setLogError(
      ~value="Missing token in initClickToPayDCTPSession params",
      ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION_RETURNED,
    )
    getFailedSubmitResponse(
      ~errorType="INVALID_INPUT",
      ~message="Missing token parameter in params",
    )
  } else {
    let ctpToken = ClickToPayHelpers.clickToPayTokenFromCamelCaseMapper(token)
    customerEmail := ctpToken.email

    // Step 3 — Local isCustomerPresent closure
    let isCustomerPresent = async (~email) => {
      logger.setLogInfo(
        ~value=`Is customer present method called with email: ${email
          ->Option.isSome
          ->getStringFromBool}`,
        ~eventName=IS_CUSTOMER_PRESENT,
      )
      switch email {
      | Some(emailVal) =>
        logger.setLogDebug(
          ~value=`Is customer present method called with email: ${maskEmail(emailVal)}`,
          ~eventName=IS_CUSTOMER_PRESENT_INIT,
        )
        customerEmail := emailVal
      | None =>
        logger.setLogDebug(
          ~value=`Is customer present method called without email`,
          ~eventName=IS_CUSTOMER_PRESENT_INIT,
        )
      }

      let directSdkLoadStatus = directSdkLoadStatusRef.contents
      let mastercardInitFailed = mastercardDirectInitFailedRef.contents
      let visaInitFailed = visaDirectInitFailedRef.contents

      let anyDirectSdkUnavailable =
        switch directSdkLoadStatus {
        | None => true
        | Some(status) => !status.mastercardDirectLoaded || !status.visaDirectLoaded
        } ||
        mastercardInitFailed ||
        visaInitFailed ||
        ClickToPayHelpers.windowVisaDirectSdk->Nullable.toOption->Option.isNone

      if anyDirectSdkUnavailable {
        let unavailableReasons = []
        switch directSdkLoadStatus {
        | None =>
          unavailableReasons->Array.push(
            "directSdkLoadStatus not set — SDK scripts may not have been loaded",
          )
        | Some(status) => {
            if !status.visaDirectLoaded {
              unavailableReasons->Array.push("Visa Direct SDK script failed to load")
            }
            if !status.mastercardDirectLoaded {
              unavailableReasons->Array.push("Mastercard Direct SDK script failed to load")
            }
          }
        }
        if visaInitFailed {
          unavailableReasons->Array.push("Visa Direct SDK script failed to load or init failed")
        }
        if mastercardInitFailed {
          unavailableReasons->Array.push(
            "Mastercard Direct SDK script failed to load or init failed",
          )
        }
        if ClickToPayHelpers.windowVisaDirectSdk->Nullable.toOption->Option.isNone {
          unavailableReasons->Array.push("Visa Direct SDK not available")
        }
        logger.setLogError(
          ~value=`One or more direct SDKs unavailable, returning customerPresent: false. Reasons: ${unavailableReasons->Array.join(
              "; ",
            )}`,
          ~eventName=IS_CUSTOMER_PRESENT_RETURNED,
        )

        let mastercardData = [("consumerPresent", false->JSON.Encode.bool)]->getJsonFromArrayOfJson
        let visaData = [("consumerPresent", false->JSON.Encode.bool)]->getJsonFromArrayOfJson
        let clickToPayData =
          [("mastercard", mastercardData), ("visa", visaData)]->getJsonFromArrayOfJson
        let eligibilityCheckData = [("click_to_pay", clickToPayData)]
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

        [("customerPresent", false->JSON.Encode.bool)]->getJsonFromArrayOfJson
      } else {
        let consumerIdentity = {
          identityProvider: "SRC",
          identityType: EMAIL_ADDRESS,
          identityValue: customerEmail.contents,
        }

        let clickToPayData = []

        logger.setLogDebug(
          ~value="Mastercard Direct Click to Pay identity lookup initiated",
          ~eventName=MASTERCARD_DCTP_ID_LOOKUP_INIT,
        )
        let mastercardDirectIdentityLookupPromise = mastercardDirectSdk.identityLookup({
          consumerIdentity: consumerIdentity,
        })
        logger.setLogDebug(
          ~value="Visa Direct Click to Pay identity lookup initiated",
          ~eventName=VISA_DCTP_ID_LOOKUP_INIT,
        )
        let visaDirectIdentityLookupPromise = switch ClickToPayHelpers.windowVisaDirectSdk->Nullable.toOption {
        | Some(sdk) => {
            logger.setLogDebug(
              ~value="Visa Direct Click to Pay found",
              ~eventName=IS_VISA_DCTP_MOUNTED,
            )
            sdk.identityLookup(consumerIdentity)
          }
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
              let present = value->Utils.getDictFromJson->Utils.getBool("consumerPresent", false)
              isCustomerPresentForMastercard := present

              logger.setLogDebug(
                ~value=`Mastercard Direct Click to Pay Identity Lookup returned: ${present
                    ? "present"
                    : "not present"}`,
                ~eventName=MASTERCARD_DCTP_ID_LOOKUP_RETURNED,
              )

              clickToPayData->Array.push(("mastercard", value))
            }
          | Rejected({reason}) => {
              hadIdentityLookupError := true
              logger.setLogError(
                ~value=`Error initializing Mastercard Direct Click to Pay identity lookup: ${reason
                  ->Utils.formatException
                  ->JSON.stringify}`,
                ~eventName=MASTERCARD_DCTP_ID_LOOKUP_RETURNED,
              )
              clickToPayData->Array.push((
                "mastercard",
                [("consumerPresent", false->JSON.Encode.bool)]->getJsonFromArrayOfJson,
              ))
            }
          }

          switch visaDirectIdentityLookup {
          | Fulfilled({value}) => {
              let present = value->Utils.getDictFromJson->Utils.getBool("consumerPresent", false)
              isCustomerPresentForVisa := present

              logger.setLogDebug(
                ~value=`Visa Direct Click to Pay Identity Lookup returned: ${present
                    ? "present"
                    : "not present"}`,
                ~eventName=VISA_DCTP_ID_LOOKUP_RETURNED,
              )

              clickToPayData->Array.push(("visa", value))
            }
          | Rejected({reason}) => {
              hadIdentityLookupError := true
              logger.setLogError(
                ~value=`Error initializing Visa Direct Click to Pay identity lookup: ${reason
                  ->Utils.formatException
                  ->JSON.stringify}`,
                ~eventName=VISA_DCTP_ID_LOOKUP_RETURNED,
              )
              clickToPayData->Array.push((
                "visa",
                [("consumerPresent", false->JSON.Encode.bool)]->getJsonFromArrayOfJson,
              ))
            }
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

        let isC2pProfilePresent = if hadIdentityLookupError.contents {
          false
        } else {
          isCustomerPresentForMastercard.contents || isCustomerPresentForVisa.contents
        }

        let customerPresent =
          [("customerPresent", isC2pProfilePresent->JSON.Encode.bool)]->getJsonFromArrayOfJson

        logger.setLogDebug(
          ~value=isC2pProfilePresent->getStringFromBool,
          ~eventName=IS_CUSTOMER_PRESENT_RETURNED,
        )

        customerPresent
      }
    }

    // Step 4 — Load direct SDK scripts and init
    await Promise.make((resolve, _) => {
      ClickToPayHelpers.loadDirectSdkScripts(
        logger,
        directSdkLoadStatus => {
          logger.setLogDebug(
            ~value="Direct SDK scripts loaded, proceeding with SDK initialization",
            ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION,
          )
          try {
            directSdkLoadStatusRef := Some(directSdkLoadStatus)

            let initConfig = ClickToPayHelpers.getVisaInitConfig(ctpToken, Some(clientSecret))

            let mastercardDirectInitData = {
              srciTransactionId: clientSecret,
              srcInitiatorId: GlobalVars.isProd
                ? "78fbc211-73e1-4c3a-bc5c-60a7921afb97"
                : "544ef81a-dae0-4f26-9511-bfbdba3d62b5",
              srciDpaId: GlobalVars.isProd
                ? "d693c074-8945-4ec7-aa7d-a0a85e636a62"
                : "b6e06cc6-3018-4c4c-bbf5-9fb232615090",
              dpaTransactionOptions: {
                dpaLocale: ctpToken.locale,
              },
            }

            let visaDirectSdkOpt = if directSdkLoadStatus.visaDirectLoaded {
              logger.setLogDebug(
                ~value="Visa Direct script loaded, creating SRCI adapter",
                ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION,
              )
              Some(ClickToPayHelpers.createVisaDirectSRCIAdapter())
            } else {
              logger.setLogError(
                ~value="Visa Direct script did not load, skipping SRCI adapter creation",
                ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION,
              )
              Types.window["visaDirectSdk"] = null
              visaDirectInitFailedRef := true
              None
            }

            let visaDirectInitData: visaDirectInitData = {
              srciTransactionId: clientSecret,
              srcInitiatorId: ctpToken.dpaId,
              srciDpaId: ctpToken.dpaName,
              dpaTransactionOptions: initConfig.dpaTransactionOptions,
            }

            let mastercardInitPromise = if directSdkLoadStatus.mastercardDirectLoaded {
              logger.setLogDebug(
                ~value="Initializing Mastercard Direct Click to Pay",
                ~eventName=MASTERCARD_DCTP_INIT,
              )
              ClickToPayHelpers.mastercardDirectSdk.init(mastercardDirectInitData)
            } else {
              logger.setLogError(
                ~value="Mastercard Direct script did not load, skipping init",
                ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION,
              )
              mastercardDirectInitFailedRef := true
              Promise.resolve(%raw("{}"))
            }

            let visaInitPromise = switch visaDirectSdkOpt {
            | Some(sdk) => {
                logger.setLogDebug(
                  ~value="Initializing Visa Direct Click to Pay",
                  ~eventName=VISA_DCTP_INIT,
                )
                sdk.init(visaDirectInitData)
              }
            | None => Promise.resolve(%raw("{}"))
            }

            Promise.allSettled([mastercardInitPromise, visaInitPromise])
            ->then(async promiseResults => {
              switch promiseResults {
              | [mastercardPromiseResponse, visaPromiseResponse] => {
                  switch mastercardPromiseResponse {
                  | Rejected({reason}) => {
                      logger.setLogError(
                        ~value=`Failed to initialize Mastercard Direct Click to Pay ${reason
                          ->Utils.formatException
                          ->JSON.stringify}`,
                        ~eventName=MASTERCARD_DCTP_RETURNED,
                      )
                      mastercardDirectInitFailedRef := true
                    }
                  | Fulfilled(_) =>
                    if directSdkLoadStatus.mastercardDirectLoaded {
                      logger.setLogDebug(
                        ~value="Successfully initialized Mastercard Direct Click to Pay",
                        ~eventName=MASTERCARD_DCTP_RETURNED,
                      )
                    }
                  }

                  switch visaPromiseResponse {
                  | Rejected({reason}) => {
                      logger.setLogError(
                        ~value=`Failed to initialize Visa Direct Click to Pay ${reason
                          ->Utils.formatException
                          ->JSON.stringify}`,
                        ~eventName=VISA_DCTP_RETURNED,
                      )
                      visaDirectInitFailedRef := true
                    }
                  | Fulfilled(_) =>
                    if directSdkLoadStatus.visaDirectLoaded {
                      logger.setLogDebug(
                        ~value="Successfully initialized Visa Direct Click to Pay",
                        ~eventName=VISA_DCTP_RETURNED,
                      )
                    }
                  }
                }
              | _ => ()
              }

              // Only set window.visaDirectSdk if adapter was created
              switch visaDirectSdkOpt {
              | Some(sdk) => Types.window["visaDirectSdk"] = sdk
              | None => ()
              }

              let sessionObj: Types.clickToPayDCTPSession = {
                isCustomerPresent: isCustomerPresentInput => {
                  let email = isCustomerPresentInput->Option.flatMap(input => Some(input.email))
                  isCustomerPresent(~email)
                },
              }
              logger.setLogDebug(
                ~value="Successfully completed Click to Pay DCTP session initialization",
                ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION_RETURNED,
              )
              resolve(sessionObj->Identity.anyTypeToJson)
              JSON.Encode.null
            })
            ->catch(err => {
              let errMsg = `Unexpected error in DCTP init Promise chain: ${err->Js.String.make}`
              logger.setLogError(~value=errMsg, ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION_RETURNED)
              let failedResponse = getFailedSubmitResponse(
                ~errorType="ERROR",
                ~message="An unexpected error occurred during DCTP session initialization.",
              )
              resolve(failedResponse)
              Promise.resolve(JSON.Encode.null)
            })
            ->ignore
          } catch {
          | err => {
              logger.setLogError(
                ~value=`Unexpected error during DCTP session initialization: ${err
                  ->Utils.formatException
                  ->JSON.stringify}`,
                ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION_RETURNED,
              )
              directSdkLoadStatusRef := (None: option<ClickToPayHelpers.directSdkLoadStatus>)
              mastercardDirectInitFailedRef := false
              visaDirectInitFailedRef := false
              let failedErrorResponse = getFailedSubmitResponse(
                ~errorType="ERROR",
                ~message="An unexpected error occurred while initializing DCTP session.",
              )
              resolve(failedErrorResponse)
            }
          }
        },
        () => {
          logger.setLogError(
            ~value="Failed to load Direct SDK scripts",
            ~eventName=INIT_CLICK_TO_PAY_DCTP_SESSION_RETURNED,
          )
          directSdkLoadStatusRef := (None: option<ClickToPayHelpers.directSdkLoadStatus>)
          mastercardDirectInitFailedRef := false
          visaDirectInitFailedRef := false
          let failedErrorResponse = getFailedSubmitResponse(
            ~errorType="ERROR",
            ~message="Failed to load Direct SDK scripts.",
          )
          resolve(failedErrorResponse)
        },
      )
    })
  } // end else (token present)
}

Types.window["ClickToPayDCTPAuthenticationSession"] = initClickToPayDCTPSession
