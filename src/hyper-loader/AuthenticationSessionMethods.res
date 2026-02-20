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

  let isCustomerPresent = async (
    ~visaDirectSdk: option<OrcaPaymentPage.ClickToPayHelpers.visaDirect>,
    ~email,
  ) => {
    logger.setLogInfo(
      ~value=`Is customer present method called with email: ${email
        ->Option.isSome
        ->getStringFromBool}`,
      ~eventName=IS_CUSTOMER_PRESENT,
    )
    logger.setLogDebug(
      ~value=`Is customer present method called with email: ${email
        ->Option.isSome
        ->getStringFromBool}`,
      ~eventName=IS_CUSTOMER_PRESENT_INIT,
    )
    switch email {
    | Some(emailVal) => customerEmail := emailVal
    | None => ()
    }

    let consumerIdentity = {
      identityProvider: "SRC",
      identityType: EMAIL_ADDRESS,
      identityValue: customerEmail.contents,
    }

    let isCustomerPresentForMastercard = ref(false)
    let isCustomerPresentForVisa = ref(false)

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
    let visaDirectIdentityLookupPromise = switch visaDirectSdk {
    | Some(sdk) => {
        logger.setLogDebug(~value="Visa Direct Click to Pay found", ~eventName=IS_VISA_DCTP_MOUNTED)
        sdk.identityLookup(consumerIdentity)
      }
    | None => {
        logger.setLogError(
          ~value="Visa Direct Click to Pay not found",
          ~eventName=IS_VISA_DCTP_MOUNTED,
        )
        Promise.resolve(JSON.Encode.null)
      }
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
      | Rejected({reason}) =>
        logger.setLogError(
          ~value=`Error initializing Mastercard Direct Click to Pay identity lookup: ${reason
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=MASTERCARD_DCTP_ID_LOOKUP_RETURNED,
        )
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
      | Rejected({reason}) =>
        logger.setLogError(
          ~value=`Error initializing Visa Direct Click to Pay identity lookup: ${reason
            ->Utils.formatException
            ->JSON.stringify}`,
          ~eventName=VISA_DCTP_ID_LOOKUP_RETURNED,
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

    logger.setLogDebug(
      ~value=isC2pProfilePresent->getStringFromBool,
      ~eventName=IS_CUSTOMER_PRESENT_RETURNED,
    )

    customerPresent
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

    let getUserTypeErrorMessage = "An unknown error occurred while fetching user type."
    try {
      logger.setLogDebug(
        ~value="Initializing Visa Unified Click to Pay getCards method",
        ~eventName=VISA_UCTP_GET_CARDS_INIT,
      )
      let getCardsResponse = await vsdk.getCards(getCardsConfig)

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
        logger.setLogDebug(
          ~value=`Unified Click to Pay Get Cards Returned statusCode: ${statusCode}`,
          ~eventName=VISA_UCTP_GET_CARDS_RETURNED,
        )
        logger.setLogDebug(~value=statusCode, ~eventName=GET_USER_TYPE_RETURNED)
        [("statusCode", statusCode->JSON.Encode.string)]->getJsonFromArrayOfJson
      } else {
        logger.setLogError(
          ~value=`Error while calling getCards method from Visa Unified Click to Pay: ${statusCode}`,
          ~eventName=VISA_UCTP_GET_CARDS_RETURNED,
        )
        logger.setLogError(~value=statusCode, ~eventName=GET_USER_TYPE_RETURNED)
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
          ~value=`Error returned from Visa Unified Click to Pay Get Cards during validation with actionCode: ${validateCustomerAuthenticationResponse.actionCode->getStrFromActionCode} and reason : ${validateCustomerAuthenticationResponse.error
            ->Option.flatMap(err => err.reason)
            ->Option.getOr("UNKNOWN_ERROR")}`,
          ~eventName=VISA_UCTP_GET_CARDS_VALIDATE_RETURNED,
        )
        logger.setLogError(
          ~value=`Error returned from Visa Unified Click to Pay Get Cards during validation with actionCode: ${validateCustomerAuthenticationResponse.actionCode->getStrFromActionCode} and reason : ${validateCustomerAuthenticationResponse.error
            ->Option.flatMap(err => err.reason)
            ->Option.getOr("UNKNOWN_ERROR")}`,
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
              Types.window["visaDirectSdk"] = null
              logger.setLogDebug(
                ~value="Received response from authentication sync call after checkout with card.",
                ~eventName=CHECKOUT_RETURNED,
              )
              authenticationSyncResponse->transformKeysWithoutModifyingValue(CamelCase)
            }
          | _ => {
              let errorReason = if actionCode == "ERROR" {
                checkoutWithCardResponse
                ->Utils.getDictFromJson
                ->Utils.getDictFromDict("error")
                ->Utils.getString("reason", "UNKNOWN_ERROR")
              } else {
                ""
              }
              logger.setLogError(
                ~value=`Visa Unified Click to Pay checkout with card failed with actionCode: ${actionCode} and errorReason: ${errorReason !== ""
                    ? errorReason
                    : "UNKOWN ERROR REASON"}.`,
                ~eventName=VISA_UCTP_CHECKOUT_RESPONSE,
              )
              logger.setLogError(
                ~value=`Visa Unified Click to Pay checkout with card failed with actionCode: ${actionCode} and errorReason: ${errorReason !== ""
                    ? errorReason
                    : "UNKOWN ERROR REASON"}.`,
                ~eventName=CHECKOUT_RETURNED,
              )

              let errorMsg = switch actionCode {
              | "CHANGE_CARD" => "Consumer wishes to select an alternative card."
              | "SWITCH_CONSUMER" => "Consumer wishes to change Click to Pay profile."
              | _ => checkoutWithCardErrorMessage
              }
              if actionCode !== "CHANGE_CARD" && actionCode !== "SWITCH_CONSUMER" {
                Types.window["initializedVSDK"] = false
                Types.window["visaDirectSdk"] = null
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
      | Some(err) => {
          logger.setLogError(
            ~value=`Error unbinding Click to Pay App Instance during sign out: ${err.reason->Option.getOr(
                "Unknown Error",
              )}`,
            ~eventName=VISA_UCTP_UNBIND_APP_INSTANCE_RETURNED,
          )
          logger.setLogError(
            ~value=`Error unbinding Click to Pay App Instance during sign out: ${err.reason->Option.getOr(
                "Unknown Error",
              )}`,
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
          | Some(true) => {
              logger.setLogDebug(
                ~value="Active Click to Pay session found",
                ~eventName=GET_ACTIVE_CLICK_TO_PAY_SESSION_RETURNED,
              )
              resolve(getSessionObject(ClickToPayHelpers.windowVisaDirectSdk->Nullable.toOption))
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
          ClickToPayHelpers.loadVisaUnifiedClickToPayScriptAndDirectSdkScripts(
            logger,
            token,
            () => {
              let initConfig = ClickToPayHelpers.getVisaInitConfig(token, Some(clientSecret))

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
              let visaDirectInitData: visaDirectInitData = {
                srciTransactionId: clientSecret,
                srcInitiatorId: token.dpaId,
                srciDpaId: token.dpaName,
                dpaTransactionOptions: initConfig.dpaTransactionOptions,
              }

              logger.setLogDebug(
                ~value="Initializing Mastercard Direct Click to Pay",
                ~eventName=MASTERCARD_DCTP_INIT,
              )
              let mastercardInitPromise = ClickToPayHelpers.mastercardDirectSdk.init(
                mastercardDirectInitData,
              )
              logger.setLogDebug(
                ~value="Initializing Visa Direct Click to Pay",
                ~eventName=VISA_DCTP_INIT,
              )
              let visaInitPromise = visaDirectSdk.init(visaDirectInitData)

              Promise.allSettled([mastercardInitPromise, visaInitPromise])
              ->then(async promiseResults => {
                switch promiseResults {
                | [mastercardPromiseResponse, visaPromiseResponse] => {
                    switch mastercardPromiseResponse {
                    | Rejected({reason}) =>
                      logger.setLogError(
                        ~value=`Failed to initialize Mastercard Direct Click to Pay ${reason
                          ->Utils.formatException
                          ->JSON.stringify}`,
                        ~eventName=MASTERCARD_DCTP_RETURNED,
                      )
                    | Fulfilled(_) => {
                        logger.setLogDebug(
                          ~value="Successfully initialized Mastercard Direct Click to Pay",
                          ~eventName=MASTERCARD_DCTP_RETURNED,
                        )

                        ()
                      }
                    }

                    switch visaPromiseResponse {
                    | Rejected({reason}) =>
                      logger.setLogError(
                        ~value=`Failed to initialize Visa Direct Click to Pay ${reason
                          ->Utils.formatException
                          ->JSON.stringify}`,
                        ~eventName=VISA_DCTP_RETURNED,
                      )
                    | Fulfilled(_) => {
                        logger.setLogDebug(
                          ~value="Successfully initialized Visa Direct Click to Pay",
                          ~eventName=VISA_DCTP_RETURNED,
                        )

                        ()
                      }
                    }
                  }
                | _ => ()
                }

                Types.window["visaDirectSdk"] = visaDirectSdk

                logger.setLogDebug(
                  ~value="Initializing Visa Unified Click to Pay",
                  ~eventName=VISA_UCTP_INIT,
                )
                ClickToPayHelpers.vsdk.initialize(initConfig)
                ->then(
                  async _ => {
                    logger.setLogDebug(
                      ~value="Successfully initialized Visa Unified Click to Pay",
                      ~eventName=VISA_UCTP_RETURNED,
                    )

                    Types.window["initializedVSDK"] = true
                    resolve(getSessionObject(Some(visaDirectSdk)))
                    logger.setLogDebug(
                      ~value="Successfully completed Click to Pay session initialization",
                      ~eventName=INIT_CLICK_TO_PAY_SESSION_RETURNED,
                    )
                    JSON.Encode.null
                  },
                )
                ->catch(
                  err => {
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
                    let failedErrorResponse = getFailedSubmitResponse(
                      ~errorType="ERROR",
                      ~message="An unknown error occurred while initializing Click to Pay session.",
                    )
                    resolve(failedErrorResponse)

                    Promise.resolve(JSON.Encode.null)
                  },
                )
                ->ignore
              })
              ->ignore
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
