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

  let countBrands = cards => {
    let countBrand = brand =>
      cards
      ->Array.filter(card => card.paymentCardDescriptor->String.toLowerCase->String.includes(brand))
      ->Array.length
    ("visa"->countBrand, "mastercard"->countBrand)
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

    let mastercardDirectIdentityLookupPromise = (() =>
        mastercardDirectSdk.identityLookup({
          consumerIdentity: consumerIdentity,
        }))()
    let visaDirectIdentityLookupPromise = switch visaDirectSdk {
    | Some(sdk) =>
      (() => sdk.identityLookup(consumerIdentity))()
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
      let getCardsResponse = await (() => vsdk.getCards(getCardsConfig))()

      let statusCode = switch getCardsResponse.actionCode {
      | PENDING_CONSUMER_IDV => {
          "TRIGGERED_CUSTOMER_AUTHENTICATION"
        }
      | (SUCCESS | ADD_CARD) as listedActionCode => {
          if listedActionCode === SUCCESS {
            maskedCards := getMaskedCardsListFromResponse(getCardsResponse)
          }
          let listedCards = listedActionCode === SUCCESS ? maskedCards.contents : []
          let (visa, mastercard) = listedCards->countBrands

          listedCards->Array.length > 0 ? "RECOGNIZED_CARDS_PRESENT" : "NO_CARDS_PRESENT"
        }
      | _ => {
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
      let validateCustomerAuthenticationResponse = await (() => vsdk.getCards(getCardsConfig))()

      switch validateCustomerAuthenticationResponse.actionCode {
      | SUCCESS =>
        maskedCards := getMaskedCardsListFromResponse(validateCustomerAuthenticationResponse)

        let (visa, mastercard) = maskedCards.contents->countBrands


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
              let isConsumerNavigation =
                actionCode === "CHANGE_CARD" || actionCode === "SWITCH_CONSUMER"

              let errorMsg = switch actionCode {
              | "CHANGE_CARD" => "Consumer wishes to select an alternative card."
              | "SWITCH_CONSUMER" => "Consumer wishes to change Click to Pay profile."
              | _ => checkoutWithCardErrorMessage
              }
              if !isConsumerNavigation {
                Types.window["initializedVSDK"] = false
                Types.window["visaDirectSdk"] = null
              }

              getFailedSubmitResponse(~errorType=actionCode, ~message=errorMsg)
            }
          }
        }
      | None => {
          getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
        }
      }
    } catch {
    | err => {
        handleCloseClickToPayWindow()
        getFailedSubmitResponse(~errorType="ERROR", ~message=checkoutWithCardErrorMessage)
      }
    }
  }

  let signOut = async () => {
    let unbindAppInstanceErrorMessage = "Failed to sign out customer."
    try {
      let unbindAppInstanceResponse = await (() => vsdk.unbindAppInstance())()
      switch unbindAppInstanceResponse.error {
      | Some(_) =>
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
    | exn =>
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

              (() => isCustomerPresent(~visaDirectSdk, ~email))()
            },
            getUserType: () =>
              (() => getUserType())(),
            getRecognizedCards: () =>
              (() =>
                getRecognizedCards())(),
            validateCustomerAuthentication: otpValue =>
              (() =>
                validateCustomerAuthentication(~otpValue))(),
            checkoutWithCard: checkoutWithCardInput => {
              (() =>
                  checkoutWithCard(
                    ~token,
                    ~srcDigitalCardId=checkoutWithCardInput.srcDigitalCardId,
                    ~rememberMe=checkoutWithCardInput.rememberMe,
                    ~windowRef=checkoutWithCardInput.windowRef,
                  ))()
            },
            signOut: () =>
              (() => signOut())(),
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

              (() =>
                ClickToPayHelpers.vsdk.initialize(initConfig))()
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

                let mastercardInitPromise = (() => ClickToPayHelpers.mastercardDirectSdk.init(mastercardDirectInitData))()
                let visaInitPromise = (() => visaDirectSdk.init(visaDirectInitData))()

                let _ = await Promise.allSettled([mastercardInitPromise, visaInitPromise])

                Types.window["initializedVSDK"] = true
                Types.window["visaDirectSdk"] = visaDirectSdk
                resolve(getSessionObject(Some(visaDirectSdk)))
                JSON.Encode.null
              })
              ->catch(error => {
                let message = "An unknown error occurred while initializing Click to Pay session."
                let failedErrorResponse = getFailedSubmitResponse(~errorType="ERROR", ~message)
                resolve(failedErrorResponse)

                Promise.resolve(JSON.Encode.null)
              })
              ->ignore
            },
            () => {
              let message = "Failed to load Click to Pay script."
              let failedErrorResponse = getFailedSubmitResponse(~errorType="ERROR", ~message)

              resolve(failedErrorResponse)
            },
          )
        }
      }
    | None => {
        let message = "An error occured while trying to fetch Click to Pay Details"
        let failedErrorResponse = getFailedSubmitResponse(~errorType="ERROR", ~message)

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
) =>
  (() =>
    makeClickToPaySession(
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~endpoint,
      ~profileId,
      ~authenticationId,
      ~merchantId,
      ~initClickToPaySessionInput,
      ~shouldLoadScripts=true,
    ))()

let getActiveClickToPaySession = (
  ~clientSecret,
  ~publishableKey,
  ~customPodUri,
  ~endpoint,
  ~profileId,
  ~authenticationId,
  ~merchantId,
) =>
  (() =>
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
    ))()

Types.window["ClickToPayAuthenticationSession"] = initClickToPaySession
