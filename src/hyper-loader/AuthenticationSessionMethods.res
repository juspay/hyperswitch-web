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

let makeClickToPaySession = async (
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
  ~shouldLoadScripts,
) => {
  let customerEmail = ref("")
  let maskedCards = ref([])

  let key = `${clientSecret}_${authenticationId}`

  let handleApi = () =>
    PaymentHelpers.fetchEnabledAuthnMethodsToken(
      ~clientSecret,
      ~publishableKey,
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

    let consumerPresentDetails = value => [
      (
        "consumer_present",
        value->Utils.getDictFromJson->Utils.getBool("consumerPresent", false)->JSON.Encode.bool,
      ),
    ]

    let mastercardDirectIdentityLookupPromise = ClickToPayLogger.observeFunction(
      ~event=MastercardDirect(IdentityLookup),
      ~resultDetails=consumerPresentDetails,
      ~call=() =>
        mastercardDirectSdk.identityLookup({
          consumerIdentity: consumerIdentity,
        }),
    )
    let visaDirectIdentityLookupPromise = switch visaDirectSdk {
    | Some(sdk) =>
      ClickToPayLogger.observeFunction(
        ~event=VisaDirect(IdentityLookup),
        ~resultDetails=consumerPresentDetails,
        ~call=() => sdk.identityLookup(consumerIdentity),
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
      | Rejected(_) => ()
      }

      switch visaDirectIdentityLookup {
      | Fulfilled({value}) => {
          let present = value->Utils.getDictFromJson->Utils.getBool("consumerPresent", false)
          isCustomerPresentForVisa := present

          clickToPayData->Array.push(("visa", value))
        }
      | Rejected(_) => ()
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
      let getCardsResponse = await ClickToPayLogger.observeFunction(
        ~event=VisaUctp(GetCards),
        ~call=() => vsdk.getCards(getCardsConfig),
      )

      let statusCode = switch getCardsResponse.actionCode {
      | PENDING_CONSUMER_IDV => {
          ClickToPayLogger.logLifecycle(
            ~event=AuthenticationCompleted,
            ~message="GET_USER_TYPE | PENDING_AUTH | User requires authentication",
          )
          "TRIGGERED_CUSTOMER_AUTHENTICATION"
        }
      | SUCCESS => {
          maskedCards := getMaskedCardsListFromResponse(getCardsResponse)

          let areMaskedCardsPresent = maskedCards.contents->Array.length > 0

          if areMaskedCardsPresent {
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

            ClickToPayLogger.logLifecycle(
              ~event=CardsFetched,
              ~message=`GET_USER_TYPE | SUCCESS | visa: ${visaCount->Int.toString} | mastercard: ${mastercardCount->Int.toString}`,
            )
            "RECOGNIZED_CARDS_PRESENT"
          } else {
            ClickToPayLogger.logLifecycle(
              ~event=CardsFetched,
              ~message="GET_USER_TYPE | NO_RECOGNIZED_CARDS | Successfully Called getCards but no recognized cards are present for the customer.",
            )
            "NO_CARDS_PRESENT"
          }
        }
      | ADD_CARD => {
          ClickToPayLogger.logLifecycle(
            ~event=CardsFetched,
            ~message="GET_USER_TYPE | NO_CARDS | No recognized cards are present for the customer.",
          )
          "NO_CARDS_PRESENT"
        }
      | _ => {
          ClickToPayLogger.logLifecycle(
            ~event=CheckoutFailed,
            ~message=`GET_USER_TYPE | actionCode: ${getCardsResponse.actionCode->getStrFromActionCode} | reason : ${getCardsResponse.error
              ->Option.flatMap(err => err.reason)
              ->Option.getOr("UNKNOWN_ERROR")}`,
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
        ClickToPayLogger.logLifecycle(
          ~event=CheckoutFailed,
          ~message=`Get Cards failed ${err->Utils.formatException->JSON.stringify}`,
        )
        getFailedSubmitResponse(~errorType="ERROR", ~message=getUserTypeErrorMessage)
      }
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
      let validateCustomerAuthenticationResponse = await ClickToPayLogger.observeFunction(
        ~event=VisaUctp(GetCards),
        ~call=() => vsdk.getCards(getCardsConfig),
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

        ClickToPayLogger.logLifecycle(
          ~event=CardsFetched,
          ~message=`AUTH_VALIDATION | SUCCESS | visa : ${visaCount->Int.toString} | mastercard : ${mastercardCount->Int.toString}`,
        )

        maskedCards.contents->Identity.anyTypeToJson
      | _ =>
        ClickToPayLogger.logLifecycle(
          ~event=CheckoutFailed,
          ~message=`AUTH_VALIDATION | Validate Customer Authentication returned error action code ${validateCustomerAuthenticationResponse.actionCode->getStrFromActionCode} | reason : ${validateCustomerAuthenticationResponse.error
            ->Option.flatMap(err => err.reason)
            ->Option.getOr("UNKNOWN_ERROR")}`,
        )
        getClickToPayErrorResponse(
          ~error=validateCustomerAuthenticationResponse.error,
          ~defaultErrorMessage=validateCustomerAuthenticationErrorMessage,
        )
      }
    } catch {
    | err => {
        ClickToPayLogger.logLifecycle(
          ~event=CheckoutFailed,
          ~message=`AUTH_VALIDATION | Validate Customer Authentication failed ${err
            ->Utils.formatException
            ->JSON.stringify}`,
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
      | Some(window) => Some(window)
      | None => {
          if clickToPayWindowRef.contents->Nullable.toOption->Option.isNone {
            handleOpenClickToPayWindow()
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
              ClickToPayLogger.logLifecycle(
                ~event=CheckoutSucceeded,
                ~message="CHECKOUT | Checkout successful",
              )

              let dict = checkoutWithCardResponse->Utils.getDictFromJson
              let visaClickToPayBodyArr = PaymentBody.visaClickToPayAuthenticationBody(
                ~encryptedPayload=dict->Utils.getString("checkoutResponse", ""),
              )

              let authenticationSyncResponse = await PaymentHelpers.fetchAuthenticationSync(
                ~clientSecret,
                ~publishableKey,
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
              ClickToPayLogger.logLifecycle(
                ~event=CheckoutFailed,
                ~message=`CHECKOUT | FAILED | code: ${actionCode} ${errorReason !== ""
                    ? "| reason: " ++ errorReason
                    : ""}`,
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
          ClickToPayLogger.logLifecycle(
            ~event=WindowReferenceMissing,
            ~message="CHECKOUT | Error trying to open window for Click to Pay checkout flow.",
          )
          getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
        }
      }
    } catch {
    | err => {
        ClickToPayLogger.logLifecycle(
          ~event=CheckoutFailed,
          ~message=`CHECKOUT | Checkout with Card failed ${err
            ->Utils.formatException
            ->JSON.stringify}`,
        )
        handleCloseClickToPayWindow()
        getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
      }
    }
  }

  let signOut = async () => {
    let unbindAppInstanceErrorMessage = "Failed to sign out customer."
    try {
      let unbindAppInstanceResponse = await ClickToPayLogger.observeFunction(
        ~event=VisaUctp(UnbindAppInstance),
        ~call=() => vsdk.unbindAppInstance(),
      )
      switch unbindAppInstanceResponse.error {
      | Some(err) => {
          ClickToPayLogger.logLifecycle(
            ~event=CheckoutFailed,
            ~message=`SIGNOUT | Failed to sign out Customer ${err.reason->Option.getOr(
                "Unknown Error",
              )}`,
          )
          getClickToPayErrorResponse(
            ~error=unbindAppInstanceResponse.error,
            ~defaultErrorMessage=unbindAppInstanceErrorMessage,
          )
        }
      | None => {
          let customerSignedOut = [("recognized", false->JSON.Encode.bool)]->getJsonFromArrayOfJson

          maskedCards := []

          customerSignedOut
        }
      }
    } catch {
    | err =>
      ClickToPayLogger.logLifecycle(
        ~event=CheckoutFailed,
        ~message=`SIGNOUT | Failed to sign out Customer ${err
          ->Utils.formatException
          ->JSON.stringify}`,
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

              let emailProvided = switch email {
              | Some(emailVal) => emailVal->String.trim->String.length > 0
              | None => false
              }

              ClickToPayLogger.observeMerchant(
                ~event=IsCustomerPresent({emailProvided: emailProvided}),
                ~call=() => isCustomerPresent(~visaDirectSdk, ~email),
              )
            },
            getUserType: () =>
              ClickToPayLogger.observeMerchant(~event=GetUserType, ~call=() => getUserType()),
            getRecognizedCards: () =>
              ClickToPayLogger.observeMerchant(~event=GetRecognizedCards, ~call=() =>
                getRecognizedCards()
              ),
            validateCustomerAuthentication: otpValue =>
              ClickToPayLogger.observeMerchant(~event=ValidateCustomerAuthentication, ~call=() =>
                validateCustomerAuthentication(~otpValue)
              ),
            checkoutWithCard: checkoutWithCardInput => {
              let cardSelection: ClickToPayLogger.checkoutCardSelection =
                maskedCards.contents
                ->Array.find(card =>
                  card.srcDigitalCardId === checkoutWithCardInput.srcDigitalCardId
                )
                ->Option.map(card =>
                  switch card.paymentCardDescriptor->String.toLowerCase {
                  | descriptor if descriptor->String.includes("visa") => ClickToPayLogger.Visa
                  | descriptor if descriptor->String.includes("mastercard") =>
                    ClickToPayLogger.Mastercard
                  | _ => ClickToPayLogger.Other
                  }
                )
                ->Option.getOr(NotFound)

              ClickToPayLogger.observeMerchant(
                ~event=CheckoutWithCard({
                  rememberMe: checkoutWithCardInput.rememberMe->Option.getOr(false),
                  windowProvided: checkoutWithCardInput.windowRef
                  ->Nullable.toOption
                  ->Option.isSome,
                  cardSelection,
                  totalCardsCount: maskedCards.contents->Array.length,
                }),
                ~call=() =>
                  checkoutWithCard(
                    ~token,
                    ~srcDigitalCardId=checkoutWithCardInput.srcDigitalCardId,
                    ~rememberMe=checkoutWithCardInput.rememberMe,
                    ~windowRef=checkoutWithCardInput.windowRef,
                  ),
              )
            },
            signOut: () => ClickToPayLogger.observeMerchant(~event=SignOut, ~call=() => signOut()),
          }->Identity.anyTypeToJson
        }

        switch shouldLoadScripts {
        | false =>
          switch ClickToPayHelpers.initializedVSDK->Nullable.toOption {
          | Some(true) =>
            resolve(getSessionObject(ClickToPayHelpers.windowVisaDirectSdk->Nullable.toOption))
          | _ => {
              let failedErrorResponse = getFailedSubmitResponse(
                ~errorType="SESSION_NOT_FOUND",
                ~message="No Active Click to Pay session found.",
              )
              resolve(failedErrorResponse)
            }
          }
        | true =>
          ClickToPayHelpers.loadVisaScript(
            token,
            () => {
              let initConfig = ClickToPayHelpers.getVisaInitConfig(token, Some(clientSecret))

              ClickToPayLogger.observeFunction(~event=VisaUctp(Initialize), ~call=() =>
                ClickToPayHelpers.vsdk.initialize(initConfig)
              )
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

                let mastercardInitPromise = ClickToPayLogger.observeFunction(
                  ~event=MastercardDirect(Init),
                  ~call=() => ClickToPayHelpers.mastercardDirectSdk.init(mastercardDirectInitData),
                )
                let visaInitPromise = ClickToPayLogger.observeFunction(
                  ~event=VisaDirect(Init),
                  ~call=() => visaDirectSdk.init(visaDirectInitData),
                )

                let _ = await Promise.allSettled([mastercardInitPromise, visaInitPromise])

                Types.window["initializedVSDK"] = true
                Types.window["visaDirectSdk"] = visaDirectSdk
                resolve(getSessionObject(Some(visaDirectSdk)))
                JSON.Encode.null
              })
              ->catch(_ => {
                ClickToPayLogger.logLifecycle(
                  ~event=CheckoutFailed,
                  ~message="C2P | INIT | Failed to load Click to Pay script and init VSDK.",
                )
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
        ClickToPayLogger.logLifecycle(
          ~event=CheckoutFailed,
          ~message="C2P | INIT | An error occured while trying to fetch Click to Pay Details",
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

let initClickToPaySession = (
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
  ~initClickToPaySessionInput: Types.initClickToPaySessionInput,
  ~shouldLoadScripts=true,
) =>
  ClickToPayLogger.observeMerchant(~event=InitClickToPaySession, ~call=() =>
    makeClickToPaySession(
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~endpoint,
      ~profileId,
      ~authenticationId,
      ~merchantId,
      ~initClickToPaySessionInput,
      ~shouldLoadScripts,
    )
  )

let getActiveClickToPaySession = (
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
) =>
  ClickToPayLogger.observeMerchant(~event=GetActiveClickToPaySession, ~call=() =>
    makeClickToPaySession(
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~endpoint,
      ~profileId,
      ~authenticationId,
      ~merchantId,
      ~initClickToPaySessionInput={request3DSAuthentication: None},
      ~shouldLoadScripts=false,
    )
  )

Types.window["ClickToPayAuthenticationSession"] = initClickToPaySession
