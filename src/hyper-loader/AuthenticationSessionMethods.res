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
      //   setClickToPayConfig(prev => {
      //     ...prev,
      //     clickToPayToken: ClickToPayHelpers.clickToPayTokenItemToObjMapper(token),
      //   })
      Some(ClickToPayHelpers.clickToPayTokenItemToObjMapper(token))
    | _ =>
      // setClickToPayNotReady()
      None
    }
  }

  let ctpToken = getClickToPayToken(data)

  Console.log2("===> Click to Pay Token: ", ctpToken)

  let getMaskedCardsListFromResponse = authenticationResponse => {
    authenticationResponse.profiles
    ->Option.flatMap(profiles => Some(profiles->Array.flatMap(profile => profile.maskedCards)))
    ->Option.getOr([])
  }

  let isCustomerPresent = async (~token, ~visaDirectSdk, ~email) => {
    switch email {
    | Some(emailVal) => customerEmail := emailVal
    | None => ()
    }

    let consumerIdentity = {
      identityProvider: "SRC",
      identityType: EMAIL_ADDRESS,
      identityValue: customerEmail.contents,
    }

    let mastercardDirectIdentityLookup = await ClickToPayHelpers.mastercardDirectSdk.identityLookup({
      consumerIdentity: consumerIdentity,
    })

    let visaDirectIdentityLookup = await visaDirectSdk.identityLookup(consumerIdentity)

    Console.log2("===> Visa Direct Identity Lookup Response: ", visaDirectIdentityLookup)

    let isC2pProfilePresent =
      mastercardDirectIdentityLookup
      ->Utils.getDictFromJson
      ->Utils.getBool("consumerPresent", false) ||
        visaDirectIdentityLookup->Utils.getDictFromJson->Utils.getBool("consumerPresent", false)

    let customerPresent =
      [("customerPresent", isC2pProfilePresent->JSON.Encode.bool)]->getJsonFromArrayOfJson

    let eligibilityCheckData = [
      ("mastercard", mastercardDirectIdentityLookup),
      // ("visa", visaDirectIdentityLookup),
    ]

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

    customerPresent
  }

  let getUserType = async token => {
    let getCardsConfig = {
      consumerIdentity: {
        identityProvider: "SRC",
        identityType: EMAIL_ADDRESS,
        identityValue: customerEmail.contents,
      },
    }

    let getCardsResponse = await vsdk.getCards(getCardsConfig)

    Console.log2("===> Get Cards Response: ", getCardsResponse)

    let statusCode = switch getCardsResponse.actionCode {
    | PENDING_CONSUMER_IDV => "TRIGGERED_CUSTOMER_AUTHENTICATION"
    | SUCCESS => {
        maskedCards := getMaskedCardsListFromResponse(getCardsResponse)

        maskedCards.contents->Array.length > 0 ? "RECOGNIZED_CARDS_PRESENT" : "NO_CARDS_PRESENT"
      }
    | ADD_CARD => "NO_CARDS_PRESENT"
    | _ => "ERROR"
    }

    [("statusCode", statusCode->JSON.Encode.string)]->getJsonFromArrayOfJson
  }

  let getRecognizedCards = async () => {
    maskedCards.contents->Obj.magic
  }

  let validateCustomerAuthentication = async (
    ~token,
    ~otpValue: Types.validateCustomerAuthenticationInput,
  ) => {
    let value = otpValue.value

    Console.log2("===> OTP Value: ", value)

    let getCardsConfig = {
      consumerIdentity: {
        identityProvider: "SRC",
        identityType: EMAIL_ADDRESS,
        identityValue: customerEmail.contents,
      },
      validationData: value,
    }

    let validateCustomerAuthenticationResponse = await vsdk.getCards(getCardsConfig)

    Console.log2(
      "===> Validate Customer Authentication Response: ",
      validateCustomerAuthenticationResponse,
    )

    switch validateCustomerAuthenticationResponse.actionCode {
    | SUCCESS =>
      maskedCards := getMaskedCardsListFromResponse(validateCustomerAuthenticationResponse)

      maskedCards.contents->Obj.magic
    // [("statusCode", "RECOGNIZED_CARDS_PRESENT")->JSON.Encode.string]->getJsonFromArrayOfJson
    // | ADD_CARD =>
    //   [("statusCode", "NO_CARDS_PRESENT")->JSON.Encode.string]->getJsonFromArrayOfJson
    // | PENDING_CONSUMER_IDV =>
    //   [("statusCode", "TRIGGERED_CUSTOMER_AUTHENTICATION")->JSON.Encode.string]->getJsonFromArrayOfJson
    | _ => validateCustomerAuthenticationResponse->Obj.magic
    }
  }

  let checkoutWithCard = async (~token, ~srcDigitalCardId, ~rememberMe) => {
    if clickToPayWindowRef.contents->Nullable.toOption->Option.isNone {
      handleOpenClickToPayWindow()
    }

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

    Console.log2("===> Checkout with Card Response: ", checkoutWithCardResponse)

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
    | _ => JSON.Encode.null
    }
  }

  let defaultInitClickToPaySession = await Promise.make((resolve, _) => {
    switch ctpToken {
    | Some(token) =>
      customerEmail := token.email
      ClickToPayHelpers.loadVisaScript(
        token,
        () => {
          // visaScriptOnLoadCallback(ctpToken)
          Console.log("===> Visa Click to Pay script loaded successfully")

          let initConfig = ClickToPayHelpers.getVisaInitConfig(token, Some(clientSecret))

          // setClickToPayConfig(prev => {
          //   ...prev,
          //   visaComponentState: CARDS_LOADING,
          // })
          ClickToPayHelpers.vsdk.initialize(initConfig)
          ->then(async _ => {
            Console.log("===> Visa Click to Pay SDK initialized successfully")
            let mastercardDirectInitData = {
              srciTransactionId: clientSecret,
              srcInitiatorId: GlobalVars.isProd
                ? "78fbc211-73e1-4c3a-bc5c-60a7921afb97"
                : "544ef81a-dae0-4f26-9511-bfbdba3d62b5",
              srciDpaId: token.dpaId,
              dpaTransactionOptions: {
                dpaLocale: token.locale,
              },
            }

            let _ = await ClickToPayHelpers.mastercardDirectSdk.init(mastercardDirectInitData)

            let visaDirectSdk = ClickToPayHelpers.createVisaDirectSRCIAdapter()
            let visaDirectInitData = {
              srciTransactionId: clientSecret,
              srcInitiatorId: token.dpaId,
              srciDpaId: "8EWRS53Z0FZV8VNIXED621YSlZOGraeTx3g7yQaSV2-s3SuVw",
            }

            let _ = await visaDirectSdk.init(visaDirectInitData)

            let defaultInitClickToPaySession = {
              isCustomerPresent: isCustomerPresentInput => {
                let email =
                  isCustomerPresentInput->Option.flatMap(customerInput => Some(customerInput.email))

                isCustomerPresent(~token, ~visaDirectSdk, ~email)
              },
              getUserType: () => getUserType(token),
              getRecognizedCards,
              validateCustomerAuthentication: otpValue =>
                validateCustomerAuthentication(~token, ~otpValue),
              checkoutWithCard: checkoutWithCardInput =>
                checkoutWithCard(
                  ~token,
                  ~srcDigitalCardId=checkoutWithCardInput.srcDigitalCardId,
                  ~rememberMe=checkoutWithCardInput.rememberMe,
                ),
            }->Obj.magic

            resolve(defaultInitClickToPaySession)

            Promise.resolve(JSON.Encode.null)
          })
          ->ignore
        },
        () => {
          Console.log("===> Visa Click to Pay script failed to load")
          // setClickToPayNotReady()
          // loggerState.setLogError(
          //   ~value={
          //     "message": "CTP UI script loading failed",
          //     "scheme": clickToPayProvider,
          //   }
          //   ->JSON.stringifyAny
          //   ->Option.getOr(""),
          //   ~eventName=CLICK_TO_PAY_FLOW,
          // )
        },
      )
    | None => ()
    }
  })

  Console.log2("===> Fetched Enabled Authn Methods Token: ", data)

  defaultInitClickToPaySession
}

@val external window: {..} = "window"

window["ClickToPayAuthenticationSession"] = initClickToPaySession
