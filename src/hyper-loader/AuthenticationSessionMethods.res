open Types
open Promise
open Utils
open ClickToPayHelpers

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
) => {
  let customerEmail = ref("")
  let maskedCards = ref([])

  let data = await PaymentHelpers.fetchEnabledAuthnMethodsToken(
    ~clientSecret,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
    ~isPaymentSession=false,
    ~profileId,
    ~authenticationId,
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
  }

  let getFailedErrorResponse = (
    ~getCardsResponse,
    ~defaultErrorType="ERROR",
    ~defaultErrorMessage,
  ) => {
    switch getCardsResponse.error {
    | Some(errorObj) => {
        let errorType = errorObj.reason->Option.getOr(defaultErrorType)
        let errorMessage = errorObj.message->Option.getOr(defaultErrorMessage)

        getFailedSubmitResponse(~errorType, ~message=errorMessage)
      }
    | None => getFailedSubmitResponse(~errorType=defaultErrorType, ~message=defaultErrorMessage)
    }
  }

  let isCustomerPresent = async (~visaDirectSdk, ~email) => {
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

    try {
      let mastercardDirectIdentityLookup = await ClickToPayHelpers.mastercardDirectSdk.identityLookup({
        consumerIdentity: consumerIdentity,
      })

      isCustomerPresentForMastercard :=
        mastercardDirectIdentityLookup
        ->Utils.getDictFromJson
        ->Utils.getBool("consumerPresent", false)

      clickToPayData->Array.push(("mastercard", mastercardDirectIdentityLookup))
    } catch {
    | err =>
      logger.setLogError(
        ~value=`Direct Mastercard Click to Pay identityLookup failed ${err
          ->Utils.formatException
          ->JSON.stringify}`,
        ~eventName=CLICK_TO_PAY_FLOW,
      )
    }

    try {
      let visaDirectIdentityLookup = await visaDirectSdk.identityLookup(consumerIdentity)

      isCustomerPresentForVisa :=
        visaDirectIdentityLookup->Utils.getDictFromJson->Utils.getBool("consumerPresent", false)

      clickToPayData->Array.push(("visa", visaDirectIdentityLookup))
    } catch {
    | err =>
      logger.setLogError(
        ~value=`Direct Visa Click to Pay identityLookup failed ${err
          ->Utils.formatException
          ->JSON.stringify}`,
        ~eventName=CLICK_TO_PAY_FLOW,
      )
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
      | PENDING_CONSUMER_IDV => "TRIGGERED_CUSTOMER_AUTHENTICATION"
      | SUCCESS => {
          maskedCards := getMaskedCardsListFromResponse(getCardsResponse)

          maskedCards.contents->Array.length > 0 ? "RECOGNIZED_CARDS_PRESENT" : "NO_CARDS_PRESENT"
        }
      | ADD_CARD => "NO_CARDS_PRESENT"
      | _ => "ERROR"
      }

      if statusCode !== "ERROR" {
        [("statusCode", statusCode->JSON.Encode.string)]->getJsonFromArrayOfJson
      } else {
        getFailedErrorResponse(~getCardsResponse, ~defaultErrorMessage=getUserTypeErrorMessage)
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

        maskedCards.contents->Identity.anyTypeToJson
      | _ =>
        getFailedErrorResponse(
          ~getCardsResponse=validateCustomerAuthenticationResponse,
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

  let checkoutWithCard = async (~token, ~srcDigitalCardId, ~rememberMe) => {
    if clickToPayWindowRef.contents->Nullable.toOption->Option.isNone {
      handleOpenClickToPayWindow()
    }

    let checkoutWithCardErrorMessage = "An unknown error occurred during checkout with card."

    try {
      let checkoutWithCardResponse = await handleCheckoutWithCard(
        ~clickToPayProvider=VISA,
        ~srcDigitalCardId,
        ~logger,
        ~fullName="",
        ~email=customerEmail.contents,
        ~phoneNumber="",
        ~countryCode="",
        ~clickToPayToken=Some(token),
        ~isClickToPayRememberMe=rememberMe->Option.getOr(true),
        ~orderId=clientSecret,
        ~request3DSAuthentication=initClickToPaySessionInput.request3DSAuthentication->Option.getOr(
          true,
        ),
      )

      switch checkoutWithCardResponse.status {
      | COMPLETE => {
          let dict = checkoutWithCardResponse.payload->Utils.getDictFromJson

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

          authenticationSyncResponse
        }
      | _ => getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
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

  let defaultInitClickToPaySession = await Promise.make((resolve, _) => {
    switch ctpToken {
    | Some(token) =>
      customerEmail := token.email
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

            try {
              let _ = await ClickToPayHelpers.mastercardDirectSdk.init(mastercardDirectInitData)
            } catch {
            | err =>
              logger.setLogError(
                ~value=`Direct Mastercard Click to Pay SDK initialization failed ${err
                  ->Utils.formatException
                  ->JSON.stringify}`,
                ~eventName=CLICK_TO_PAY_FLOW,
              )
            }

            let visaDirectSdk = ClickToPayHelpers.createVisaDirectSRCIAdapter()
            let visaDirectInitData = {
              srciTransactionId: clientSecret,
              srcInitiatorId: token.dpaId,
              srciDpaId: token.dpaName,
            }

            try {
              let _ = await visaDirectSdk.init(visaDirectInitData)
            } catch {
            | err =>
              logger.setLogError(
                ~value=`Direct Visa Click to Pay SDK initialization failed ${err
                  ->Utils.formatException
                  ->JSON.stringify}`,
                ~eventName=CLICK_TO_PAY_FLOW,
              )
            }

            let defaultInitClickToPaySession = {
              isCustomerPresent: isCustomerPresentInput => {
                let email =
                  isCustomerPresentInput->Option.flatMap(customerInput => Some(customerInput.email))

                isCustomerPresent(~visaDirectSdk, ~email)
              },
              getUserType: () => getUserType(),
              getRecognizedCards,
              validateCustomerAuthentication: otpValue => validateCustomerAuthentication(~otpValue),
              checkoutWithCard: checkoutWithCardInput =>
                checkoutWithCard(
                  ~token,
                  ~srcDigitalCardId=checkoutWithCardInput.srcDigitalCardId,
                  ~rememberMe=checkoutWithCardInput.rememberMe,
                ),
            }->Identity.anyTypeToJson

            resolve(defaultInitClickToPaySession)

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

@val external window: {..} = "window"

window["ClickToPayAuthenticationSession"] = initClickToPaySession
