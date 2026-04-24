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

    // Early return: if any direct SDK script failed to load or init failed,
    // return false immediately — do not attempt identity lookups on unavailable SDKs.
    let directSdkLoadStatus = directSdkLoadStatusRef.contents
    let mastercardInitFailed = mastercardDirectInitFailedRef.contents
    let visaInitFailed = visaDirectInitFailedRef.contents

    let anyDirectSdkUnavailable =
      switch directSdkLoadStatus {
      | None => true // directSdkLoadStatus not set means init was never completed
      | Some(status) => !status.mastercardDirectLoaded || !status.visaDirectLoaded
      } ||
      mastercardInitFailed ||
      visaInitFailed ||
      visaDirectSdk->Option.isNone

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
        unavailableReasons->Array.push("Mastercard Direct SDK script failed to load or init failed")
      }
      if visaDirectSdk->Option.isNone {
        unavailableReasons->Array.push("Visa Direct SDK not available")
      }
      logger.setLogError(
        ~value=`One or more direct SDKs unavailable, returning customerPresent: false. Reasons: ${unavailableReasons->Array.join(
            "; ",
          )}`,
        ~eventName=IS_CUSTOMER_PRESENT_RETURNED,
      )

      let eligibilityCheckData = [("click_to_pay", []->Utils.getJsonFromArrayOfJson)]
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
      // visaDirectSdk is guaranteed Some here — anyDirectSdkUnavailable already returns
      // early if visaDirectSdk is None, so this None arm is unreachable.
      let visaDirectIdentityLookupPromise = switch visaDirectSdk {
      | Some(sdk) => {
          logger.setLogDebug(
            ~value="Visa Direct Click to Pay found",
            ~eventName=IS_VISA_DCTP_MOUNTED,
          )
          sdk.identityLookup(consumerIdentity)
        }
      | None => Promise.resolve(JSON.Encode.null) // unreachable: guarded above
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

      // If any identity lookup threw an error, return false regardless of other results
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

        enrichedFields->getJsonFromArrayOfJson
      } else {
        logger.setLogError(
          ~value=`Error while calling getCards method from Visa Unified Click to Pay: ${getCardsResponse
            ->Identity.anyTypeToJson
            ->JSON.stringify}`,
          ~eventName=VISA_UCTP_GET_CARDS_RETURNED,
        )
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
              Types.window["visaDirectSdk"] = null
              directSdkLoadStatusRef := (None: option<ClickToPayHelpers.directSdkLoadStatus>)
              mastercardDirectInitFailedRef := false
              visaDirectInitFailedRef := false
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
                Types.window["visaDirectSdk"] = null
                directSdkLoadStatusRef := (None: option<ClickToPayHelpers.directSdkLoadStatus>)
                mastercardDirectInitFailedRef := false
                visaDirectInitFailedRef := false
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
        Types.window["visaDirectSdk"] = null
        directSdkLoadStatusRef := (None: option<ClickToPayHelpers.directSdkLoadStatus>)
        mastercardDirectInitFailedRef := false
        visaDirectInitFailedRef := false
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
            directSdkLoadStatus => {
              // Wrap the entire callback in try/catch: createVisaDirectSRCIAdapter() can throw
              // synchronously if window.vAdapters.VisaSRCI is undefined despite the script loading,
              // which would otherwise leave the Promise.make in initClickToPaySession unresolved forever.
              try {
                // Store load status in module-level ref so isCustomerPresent can read it
                directSdkLoadStatusRef := Some(directSdkLoadStatus)

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

                // Guard: only create Visa Direct SDK adapter if the script loaded
                let visaDirectSdkOpt = if directSdkLoadStatus.visaDirectLoaded {
                  logger.setLogDebug(
                    ~value="Visa Direct script loaded, creating SRCI adapter",
                    ~eventName=VISA_DCTP_LOAD_SCRIPT_RETURNED,
                  )
                  Some(ClickToPayHelpers.createVisaDirectSRCIAdapter())
                } else {
                  logger.setLogError(
                    ~value="Visa Direct script did not load, skipping SRCI adapter creation",
                    ~eventName=VISA_DCTP_LOAD_SCRIPT_RETURNED,
                  )
                  Types.window["visaDirectSdk"] = null
                  visaDirectInitFailedRef := true
                  None
                }

                let visaDirectInitData: visaDirectInitData = {
                  srciTransactionId: clientSecret,
                  srcInitiatorId: token.dpaId,
                  srciDpaId: token.dpaName,
                  dpaTransactionOptions: initConfig.dpaTransactionOptions,
                }

                // Guard: only init Mastercard Direct SDK if the script loaded.
                // Use a resolved dummy promise to keep the 2-element allSettled array intact.
                let mastercardInitPromise = if directSdkLoadStatus.mastercardDirectLoaded {
                  logger.setLogDebug(
                    ~value="Initializing Mastercard Direct Click to Pay",
                    ~eventName=MASTERCARD_DCTP_INIT,
                  )
                  ClickToPayHelpers.mastercardDirectSdk.init(mastercardDirectInitData)
                } else {
                  logger.setLogError(
                    ~value="Mastercard Direct script did not load, skipping init",
                    ~eventName=MASTERCARD_DCTP_INIT,
                  )
                  mastercardDirectInitFailedRef := true
                  Promise.resolve(%raw("{}"))
                }

                // Guard: only init Visa Direct SDK if adapter was created.
                // Use a resolved dummy promise to keep the 2-element allSettled array intact.
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

                  logger.setLogDebug(
                    ~value="Initializing Visa Unified Click to Pay",
                    ~eventName=VISA_UCTP_INIT,
                  )
                  // vsdk.initialize runs unconditionally — session always resolves
                  ClickToPayHelpers.vsdk.initialize(initConfig)
                  ->then(
                    async _ => {
                      logger.setLogDebug(
                        ~value="Successfully initialized Visa Unified Click to Pay",
                        ~eventName=VISA_UCTP_RETURNED,
                      )

                      Types.window["initializedVSDK"] = true
                      resolve(getSessionObject(visaDirectSdkOpt))
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
                      // Reset globals on UCTP init failure to prevent stale state
                      Types.window["initializedVSDK"] = false
                      Types.window["visaDirectSdk"] = null
                      directSdkLoadStatusRef :=
                        (None: option<ClickToPayHelpers.directSdkLoadStatus>)
                      mastercardDirectInitFailedRef := false
                      visaDirectInitFailedRef := false
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
                ->catch(_ => Promise.resolve())
                ->ignore
              } catch {
              | err => {
                  logger.setLogError(
                    ~value=`Unexpected error during Click to Pay session initialization: ${err
                      ->Utils.formatException
                      ->JSON.stringify}`,
                    ~eventName=INIT_CLICK_TO_PAY_SESSION_RETURNED,
                  )
                  // Reset globals to prevent stale state
                  Types.window["initializedVSDK"] = false
                  Types.window["visaDirectSdk"] = null
                  directSdkLoadStatusRef := (None: option<ClickToPayHelpers.directSdkLoadStatus>)
                  mastercardDirectInitFailedRef := false
                  visaDirectInitFailedRef := false
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
              // Reset all session globals to prevent stale state
              Types.window["initializedVSDK"] = false
              Types.window["visaDirectSdk"] = null
              directSdkLoadStatusRef := (None: option<ClickToPayHelpers.directSdkLoadStatus>)
              mastercardDirectInitFailedRef := false
              visaDirectInitFailedRef := false
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
