open Types
open Promise
open Utils
open ClickToPayHelpers
open ClickToPayLogger

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

let makeClickToPaySession = async (
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
) => {
  let key = `${clientSecret}_${authenticationId}`

  let handleApi = () =>
    PaymentHelpers.fetchEnabledAuthnMethodsToken(
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~endpoint,
      ~profileId,
      ~authenticationId,
      ~maxRetry=Some(3),
    )

  let data = await (
    switch clickToPayTokenCache->Dict.get(key) {
    | Some(promise) => {
        logLifecycle(~event=ClickToPay(TokenCacheReused))
        promise
      }
    | None =>
      let promise = handleApi()
      setClickToPayTokenWithDebounce(key, promise)
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

  let getUserType = async () => {
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
      let getCardsResponse = await observeFunction(~event=VisaUctp(GetCards), ~call=() =>
        vsdk.getCards(getCardsConfig)
      )
      let providerError = getCardsResponse.error->Option.map(error => {
        reason: error.reason,
        messagePresent: error.message
        ->Option.map(message => message->String.trim !== "")
        ->Option.getOr(false),
      })
      logLifecycle(
        ~event=VisaUctp(
          UserTypeResult({
            code: switch getCardsResponse.actionCode {
            | SUCCESS => ClickToPayLogger.Success
            | PENDING_CONSUMER_IDV => ClickToPayLogger.PendingConsumerIdv
            | FAILED => ClickToPayLogger.Failed
            | ERROR => ClickToPayLogger.Error
            | ADD_CARD => ClickToPayLogger.AddCard
            },
            providerError,
          }),
        ),
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

        logLifecycle(
          ~event=ClickToPay(
            switch statusCode {
            | "TRIGGERED_CUSTOMER_AUTHENTICATION" =>
              CustomerAuthenticationRequired({
                maskedValidationChannelProvided: getCardsResponse.maskedValidationChannel->Option.isSome,
                supportedValidationChannelCount: getCardsResponse.supportedValidationChannels
                ->Option.map(Array.length)
                ->Option.getOr(0),
              })
            | "RECOGNIZED_CARDS_PRESENT" =>
              let visaCount =
                maskedCards.contents
                ->Array.filter(card =>
                  card.paymentCardDescriptor->String.toLowerCase->String.includes("visa")
                )
                ->Array.length
              let mastercardCount =
                maskedCards.contents
                ->Array.filter(card =>
                  card.paymentCardDescriptor->String.toLowerCase->String.includes("mastercard")
                )
                ->Array.length
              RecognizedCardsPresent({
                visaCount,
                mastercardCount,
                totalCount: maskedCards.contents->Array.length,
              })
            | _ => NoCardsPresent
            },
          ),
        )
        responseJson
      } else {
        getClickToPayErrorResponse(
          ~error=getCardsResponse.error,
          ~defaultErrorMessage=getUserTypeErrorMessage,
        )
      }
    } catch {
    | _ => getFailedSubmitResponse(~errorType="ERROR", ~message=getUserTypeErrorMessage)
    }
  }

  let getRecognizedCards = async () => maskedCards.contents->Identity.anyTypeToJson

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
      let validateCustomerAuthenticationResponse = await observeFunction(
        ~event=VisaUctp(GetCards),
        ~call=() => vsdk.getCards(getCardsConfig),
      )
      let providerError = validateCustomerAuthenticationResponse.error->Option.map(error => {
        reason: error.reason,
        messagePresent: error.message
        ->Option.map(message => message->String.trim !== "")
        ->Option.getOr(false),
      })
      logLifecycle(
        ~event=VisaUctp(
          CustomerAuthenticationResult({
            code: switch validateCustomerAuthenticationResponse.actionCode {
            | SUCCESS => ClickToPayLogger.Success
            | PENDING_CONSUMER_IDV => ClickToPayLogger.PendingConsumerIdv
            | FAILED => ClickToPayLogger.Failed
            | ERROR => ClickToPayLogger.Error
            | ADD_CARD => ClickToPayLogger.AddCard
            },
            providerError,
          }),
        ),
      )

      switch validateCustomerAuthenticationResponse.actionCode {
      | SUCCESS =>
        maskedCards := getMaskedCardsListFromResponse(validateCustomerAuthenticationResponse)

        let visaCount =
          maskedCards.contents
          ->Array.filter(card =>
            card.paymentCardDescriptor->String.toLowerCase->String.includes("visa")
          )
          ->Array.length
        let mastercardCount =
          maskedCards.contents
          ->Array.filter(card =>
            card.paymentCardDescriptor->String.toLowerCase->String.includes("mastercard")
          )
          ->Array.length
        logLifecycle(
          ~event=ClickToPay(
            RecognizedCardsPresent({
              visaCount,
              mastercardCount,
              totalCount: maskedCards.contents->Array.length,
            }),
          ),
        )
        maskedCards.contents->Identity.anyTypeToJson
      | _ =>
        getClickToPayErrorResponse(
          ~error=validateCustomerAuthenticationResponse.error,
          ~defaultErrorMessage=validateCustomerAuthenticationErrorMessage,
        )
      }
    } catch {
    | _ =>
      getFailedSubmitResponse(
        ~errorType="ERROR",
        ~message=validateCustomerAuthenticationErrorMessage,
      )
    }
  }

  let checkoutWithCard = async (~token, ~srcDigitalCardId, ~rememberMe, ~windowRef) => {
    let checkoutWithCardErrorMessage = "An unknown error occurred during checkout with card."

    try {
      let windowSource = switch windowRef->Nullable.toOption {
      | Some(_) => Provided
      | None => Created
      }
      let clickToPayWindow = switch windowRef->Nullable.toOption {
      | Some(window) => Some(window)
      | None => {
          if clickToPayWindowRef.contents->Nullable.toOption->Option.isNone {
            handleOpenClickToPayWindowWithCallbacks(
              ~onTimeout=() =>
                logState(
                  ~event=CheckoutWindowTimedOut({
                    timeoutMs: LoggerCommonHelpers.defaultOperationTimeoutMs,
                  }),
                ),
              ~onNavigated=() => logState(~event=CheckoutWindowNavigated),
            )
          }
          clickToPayWindowRef.contents->Nullable.toOption
        }
      }

      switch clickToPayWindow {
      | Some(window) => {
          let consumer: consumer = {
            fullName: "",
            emailAddress: customerEmail.contents,
            mobileNumber: {
              phoneNumber: "",
              countryCode: "",
            },
          }

          let matchedCard =
            maskedCards.contents->Array.find(card => card.srcDigitalCardId === srcDigitalCardId)
          switch matchedCard {
          | Some(_) => ()
          | None =>
            logLifecycle(
              ~event=ClickToPay(
                CheckoutCardNotFound({totalCardsCount: maskedCards.contents->Array.length}),
              ),
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
          logLifecycle(
            ~event=VisaUctp(
              switch actionCode {
              | "SUCCESS" => ClickToPayLogger.CheckoutSucceeded({code: actionCode})
              | "CHANGE_CARD" => ClickToPayLogger.CheckoutChangeCard({code: actionCode})
              | "SWITCH_CONSUMER" => ClickToPayLogger.CheckoutSwitchConsumer({code: actionCode})
              | _ => ClickToPayLogger.CheckoutRejected({code: actionCode})
              },
            ),
          )

          handleCloseClickToPayWindow()

          switch actionCode {
          | "SUCCESS" => {
              let dict = checkoutWithCardResponse->Utils.getDictFromJson
              let visaClickToPayBodyArr = PaymentBody.visaClickToPayAuthenticationBody(
                ~encryptedPayload=dict->Utils.getString("checkoutResponse", ""),
              )

              let authenticationSyncResponse = await PaymentHelpers.fetchAuthenticationSync(
                ~clientSecret,
                ~publishableKey,
                ~customPodUri,
                ~endpoint,
                ~profileId,
                ~authenticationId,
                ~merchantId,
                ~bodyArr=visaClickToPayBodyArr,
                ~maxRetry=Some(3),
              )
              Types.window["initializedVSDK"] = false
              authenticationSyncResponse->transformKeysWithoutModifyingValue(CamelCase)
            }
          | _ => {
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
          logLifecycle(~event=ClickToPay(CheckoutWindowUnavailable({source: windowSource})))
          getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
        }
      }
    } catch {
    | err => {
        let errorMessage = switch err {
        | WindowTimeoutError(message) => message
        | _ => checkoutWithCardErrorMessage
        }

        handleCloseClickToPayWindow()
        Types.window["initializedVSDK"] = false
        getFailedSubmitResponse(~errorType="ERROR", ~message=errorMessage)
      }
    }
  }

  let signOut = async () => {
    let unbindAppInstanceErrorMessage = "Failed to sign out customer."
    try {
      let unbindAppInstanceResponse = await observeFunction(
        ~event=VisaUctp(UnbindAppInstance),
        ~call=() => vsdk.unbindAppInstance(),
      )
      let providerError = unbindAppInstanceResponse.error->Option.map(error => {
        reason: error.reason,
        messagePresent: error.message
        ->Option.map(message => message->String.trim !== "")
        ->Option.getOr(false),
      })
      logLifecycle(
        ~event=VisaUctp(
          switch providerError {
          | Some(error) => UnbindAppInstanceRejected(error)
          | None => UnbindAppInstanceSucceeded
          },
        ),
      )
      switch unbindAppInstanceResponse.error {
      | Some(_err) =>
        getClickToPayErrorResponse(
          ~error=unbindAppInstanceResponse.error,
          ~defaultErrorMessage=unbindAppInstanceErrorMessage,
        )
      | None => {
          let customerSignedOut = [("recognized", false->JSON.Encode.bool)]->getJsonFromArrayOfJson

          maskedCards := []

          customerSignedOut
        }
      }
    } catch {
    | _ => getFailedSubmitResponse(~errorType="ERROR", ~message=unbindAppInstanceErrorMessage)
    }
  }

  let defaultInitClickToPaySession = await Promise.make((resolve, _) => {
    switch ctpToken {
    | Some(token) => {
        customerEmail := token.email

        let getSessionObject = () => {
          {
            getUserType: () => observeMerchant(~event=GetUserType, ~call=getUserType),
            getRecognizedCards: () =>
              observeMerchant(~event=GetRecognizedCards, ~call=getRecognizedCards),
            validateCustomerAuthentication: input =>
              observeMerchant(~event=ValidateCustomerAuthentication, ~call=() =>
                validateCustomerAuthentication(~otpValue=input)
              ),
            checkoutWithCard: input => {
              let cardSelection = switch maskedCards.contents->Array.find(card =>
                card.srcDigitalCardId === input.srcDigitalCardId
              ) {
              | Some(card) => {
                  let descriptor = card.paymentCardDescriptor->String.toLowerCase
                  if descriptor->String.includes("visa") {
                    Visa
                  } else if descriptor->String.includes("mastercard") {
                    Mastercard
                  } else {
                    Other
                  }
                }
              | None => NotFound
              }
              observeMerchant(
                ~event=CheckoutWithCard({
                  rememberMe: input.rememberMe->Option.getOr(false),
                  windowProvided: input.windowRef->Nullable.toOption->Option.isSome,
                  cardSelection,
                  totalCardsCount: maskedCards.contents->Array.length,
                }),
                ~call=() =>
                  checkoutWithCard(
                    ~token,
                    ~srcDigitalCardId=input.srcDigitalCardId,
                    ~rememberMe=input.rememberMe,
                    ~windowRef=input.windowRef,
                  ),
              )
            },
            signOut: () => observeMerchant(~event=SignOut, ~call=signOut),
            token: token->Identity.anyTypeToJson,
          }->Identity.anyTypeToJson
        }

        ClickToPayHelpers.loadVisaScript(
          token,
          () => {
            // Wrap the entire callback in try/catch to prevent unresolved Promise.make
            try {
              let initConfig = ClickToPayHelpers.getVisaInitConfig(token, Some(clientSecret))

              observeFunction(~event=VisaUctp(Initialize), ~call=() =>
                ClickToPayHelpers.vsdk.initialize(initConfig)
              )
              ->then(async _ => {
                // Diagnostic marker for merchant-side debugging; not used for internal control flow
                Types.window["initializedVSDK"] = true
                resolve(getSessionObject())
                JSON.Encode.null
              })
              ->catch(_ => {
                // Diagnostic marker for merchant-side debugging; not used for internal control flow
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
            | _ => {
                // Diagnostic marker for merchant-side debugging; not used for internal control flow
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
            // Diagnostic marker for merchant-side debugging; not used for internal control flow
            Types.window["initializedVSDK"] = false
            let failedErrorResponse = getFailedSubmitResponse(
              ~errorType="ERROR",
              ~message="Failed to load Click to Pay script.",
            )

            resolve(failedErrorResponse)
          },
        )
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

let initClickToPaySession = (
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
) => {
  LoggerContext.setSessionData(
    ~authenticationId,
    ~paymentId=authenticationId,
    ~merchantId,
    ~profileId,
    (),
  )
  observeMerchant(~event=InitClickToPaySession, ~call=() =>
    makeClickToPaySession(
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~endpoint,
      ~profileId,
      ~authenticationId,
      ~merchantId,
      ~initClickToPaySessionInput,
    )
  )
}

let getActiveClickToPaySession = (
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
) => {
  LoggerContext.setSessionData(
    ~authenticationId,
    ~paymentId=authenticationId,
    ~merchantId,
    ~profileId,
    (),
  )
  observeMerchant(~event=GetActiveClickToPaySession, ~call=() =>
    makeClickToPaySession(
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~endpoint,
      ~profileId,
      ~authenticationId,
      ~merchantId,
      ~initClickToPaySessionInput,
    )
  )
}

let makeClickToPayDCTPSession = async (
  ~params: JSON.t,
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

  // Step 2 — Extract token from params wrapper
  // Expected shape: { "token": <clickToPayToken JSON> }
  // This wrapper allows future callers to pass additional parameters without a signature change.
  let token = params->Utils.getDictFromJson->Dict.get("token")->Option.getOr(JSON.Encode.null)
  if token === JSON.Encode.null {
    getFailedSubmitResponse(
      ~errorType="INVALID_INPUT",
      ~message="Missing token parameter in params",
    )
  } else {
    let ctpToken = ClickToPayHelpers.clickToPayTokenFromCamelCaseMapper(token)
    customerEmail := ctpToken.email

    // Step 3 — Local isCustomerPresent closure
    let isCustomerPresent = async (~email) => {
      switch email {
      | Some(emailVal) => customerEmail := emailVal
      | None => ()
      }

      let directSdkLoadStatus = directSdkLoadStatusRef.contents
      let mastercardInitFailed = mastercardDirectInitFailedRef.contents
      let visaInitFailed = visaDirectInitFailedRef.contents

      let (visaReadiness, mastercardReadiness) = switch directSdkLoadStatus {
      | None => (LoadStatusMissing, LoadStatusMissing)
      | Some(status) => {
          let visaReadiness = if !status.visaDirectLoaded {
            ScriptUnavailable
          } else if visaInitFailed {
            InitializationFailed
          } else if ClickToPayHelpers.windowVisaDirectSdk->Nullable.toOption->Option.isNone {
            AdapterUnavailable
          } else {
            Ready
          }
          let mastercardReadiness = if !status.mastercardDirectLoaded {
            ScriptUnavailable
          } else if mastercardInitFailed {
            InitializationFailed
          } else {
            Ready
          }
          (visaReadiness, mastercardReadiness)
        }
      }
      let anyDirectSdkUnavailable = switch (visaReadiness, mastercardReadiness) {
      | (Ready, Ready) => false
      | _ => true
      }

      if anyDirectSdkUnavailable {
        logLifecycle(
          ~event=ClickToPay(
            CustomerPresenceDegraded({
              visaPresent: false,
              mastercardPresent: false,
              visaReadiness,
              mastercardReadiness,
              degradationReason: Some(DirectSdkUnavailable),
            }),
          ),
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
          ~customPodUri,
          ~endpoint,
          ~profileId,
          ~authenticationId,
          ~bodyArr=eligibilityCheckBodyArr,
          ~maxRetry=Some(3),
        )

        [("customerPresent", false->JSON.Encode.bool)]->getJsonFromArrayOfJson
      } else {
        let consumerIdentity = {
          identityProvider: "SRC",
          identityType: EMAIL_ADDRESS,
          identityValue: customerEmail.contents,
        }

        let clickToPayData = []

        let mastercardDirectIdentityLookupPromise = observeFunction(
          ~event=MastercardDirect(IdentityLookup),
          ~call=() => mastercardDirectSdk.identityLookup({consumerIdentity: consumerIdentity}),
        )
        let visaDirectIdentityLookupPromise = switch ClickToPayHelpers.windowVisaDirectSdk->Nullable.toOption {
        | Some(sdk) =>
          observeFunction(~event=VisaDirect(IdentityLookup), ~call=() =>
            sdk.identityLookup(consumerIdentity)
          )
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
              clickToPayData->Array.push(("mastercard", value))
            }
          | Rejected(_) => {
              hadIdentityLookupError := true
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
              clickToPayData->Array.push(("visa", value))
            }
          | Rejected(_) => {
              hadIdentityLookupError := true
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
          ~customPodUri,
          ~endpoint,
          ~profileId,
          ~authenticationId,
          ~bodyArr=eligibilityCheckBodyArr,
          ~maxRetry=Some(3),
        )

        let isC2pProfilePresent = if hadIdentityLookupError.contents {
          false
        } else {
          isCustomerPresentForMastercard.contents || isCustomerPresentForVisa.contents
        }

        let customerPresent =
          [("customerPresent", isC2pProfilePresent->JSON.Encode.bool)]->getJsonFromArrayOfJson

        let presenceDetails = {
          visaPresent: isCustomerPresentForVisa.contents,
          mastercardPresent: isCustomerPresentForMastercard.contents,
          visaReadiness,
          mastercardReadiness,
          degradationReason: hadIdentityLookupError.contents ? Some(IdentityLookupFailed) : None,
        }
        let presenceEvent = switch (hadIdentityLookupError.contents, isC2pProfilePresent) {
        | (true, _) => CustomerPresenceDegraded(presenceDetails)
        | (false, true) => CustomerPresent(presenceDetails)
        | (false, false) => CustomerNotPresent(presenceDetails)
        }
        logLifecycle(~event=ClickToPay(presenceEvent))
        customerPresent
      }
    }

    // Step 4 — Load direct SDK scripts and init
    await Promise.make((resolve, _) => {
      ClickToPayHelpers.loadDirectSdkScripts(
        directSdkLoadStatus => {
          let scriptDetails = {
            visaLoaded: directSdkLoadStatus.visaDirectLoaded,
            mastercardLoaded: directSdkLoadStatus.mastercardDirectLoaded,
          }
          switch (scriptDetails.visaLoaded, scriptDetails.mastercardLoaded) {
          | (true, true) => ()
          | (true, false)
          | (false, true) =>
            logLifecycle(~event=ClickToPay(DirectSdkScriptsDegraded(scriptDetails)))
          | (false, false) =>
            logLifecycle(~event=ClickToPay(DirectSdkScriptsUnavailable(scriptDetails)))
          }
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
              try {
                let adapter = ClickToPayHelpers.createVisaDirectSRCIAdapter()
                Some(adapter)
              } catch {
              | error => {
                  logLifecycle(~event=VisaDirect(SrciAdapterCreationFailed))
                  raise(error)
                }
              }
            } else {
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
              observeFunction(~event=MastercardDirect(Init), ~call=() =>
                ClickToPayHelpers.mastercardDirectSdk.init(mastercardDirectInitData)
              )
            } else {
              mastercardDirectInitFailedRef := true
              Promise.resolve(%raw("{}"))
            }

            let visaInitPromise = switch visaDirectSdkOpt {
            | Some(sdk) =>
              observeFunction(~event=VisaDirect(Init), ~call=() => sdk.init(visaDirectInitData))
            | None => Promise.resolve(%raw("{}"))
            }

            Promise.allSettled([mastercardInitPromise, visaInitPromise])
            ->then(async promiseResults => {
              switch promiseResults {
              | [mastercardPromiseResponse, visaPromiseResponse] => {
                  switch mastercardPromiseResponse {
                  | Rejected(_) => mastercardDirectInitFailedRef := true
                  | Fulfilled(_) => ()
                  }

                  switch visaPromiseResponse {
                  | Rejected(_) => visaDirectInitFailedRef := true
                  | Fulfilled(_) => ()
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
                isCustomerPresent: input =>
                  observeMerchant(
                    ~event=IsCustomerPresent({emailProvided: input->Option.isSome}),
                    ~call=() => {
                      let email = input->Option.flatMap(input => Some(input.email))
                      isCustomerPresent(~email)
                    },
                  ),
              }
              let visaReadiness = !directSdkLoadStatus.visaDirectLoaded
                ? ScriptUnavailable
                : visaDirectInitFailedRef.contents
                ? InitializationFailed
                : Ready
              let mastercardReadiness = !directSdkLoadStatus.mastercardDirectLoaded
                ? ScriptUnavailable
                : mastercardDirectInitFailedRef.contents
                ? InitializationFailed
                : Ready
              let readinessDetails = {visaReadiness, mastercardReadiness}
              switch (visaReadiness, mastercardReadiness) {
              | (Ready, Ready) => ()
              | (Ready, _)
              | (_, Ready) =>
                logLifecycle(~event=ClickToPay(DirectSdksDegraded(readinessDetails)))
              | _ => logLifecycle(~event=ClickToPay(DirectSdksUnavailable(readinessDetails)))
              }
              resolve(sessionObj->Identity.anyTypeToJson)
              JSON.Encode.null
            })
            ->catch(_ => {
              let failedResponse = getFailedSubmitResponse(
                ~errorType="ERROR",
                ~message="An unexpected error occurred during DCTP session initialization.",
              )
              resolve(failedResponse)
              Promise.resolve(JSON.Encode.null)
            })
            ->ignore
          } catch {
          | _ => {
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

let initClickToPayDCTPSession = (
  ~params: JSON.t,
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
) => {
  LoggerContext.setSessionData(~authenticationId, ~paymentId=authenticationId, ~profileId, ())
  observeMerchant(~event=InitClickToPayDCTPSession, ~call=() =>
    makeClickToPayDCTPSession(
      ~params,
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~endpoint,
      ~profileId,
      ~authenticationId,
    )
  )
}

Types.window["ClickToPayAuthenticationSession"] = initClickToPaySession
Types.window["ClickToPayDCTPAuthenticationSession"] = initClickToPayDCTPSession
