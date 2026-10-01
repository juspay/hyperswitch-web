open Promise
open Utils
open SavedPaymentMethodsUtils

type savedMethodsState = {
  savedMethods: array<PaymentType.customerMethods>,
  isGuestCustomer: bool,
  paymentMethodList: PaymentMethodsRecord.paymentMethodList,
  applePayToken: option<ApplePayTypes.headlessApplePayToken>,
  googlePayClient: option<GooglePayType.client>,
  googlePayPaymentDataRequest: JSON.t,
  intentVersion: int,
}

type t = {
  listSavedPaymentMethods: option<JSON.t> => promise<JSON.t>,
  confirmWithSavedPaymentMethod: JSON.t => promise<JSON.t>,
}

let make = (
  ~publishableKey,
  ~endpoint,
  ~customPodUri,
  ~logger: HyperLoggerTypes.loggerMake,
  ~clientSecretRef: ref<string>,
  ~sdkAuthorizationRef: ref<string>,
  ~redirectionFlags,
  ~iframeRef: ref<array<Nullable.t<Dom.element>>>,
  ~isUpdateIntentInProgress: ref<bool>,
  ~intentVersion: ref<int>,
  ~isTestMode,
) => {
  let savedMethodsStateRef = ref(None)
  let isConfirmInProgress = ref(false)
  let applePaySessionRef = ref(Nullable.null)
  let componentName = "headless"

  let getSdkAuthorization = () => Some(sdkAuthorizationRef.contents)->getNonEmptyOption

  let getWalletSessions = async (savedMethods: array<PaymentType.customerMethods>) => {
    let hasPaymentMethodType = paymentMethodType =>
      savedMethods->Array.some(savedMethod =>
        savedMethod.paymentMethodType === Some(paymentMethodType)
      )
    let canMakeApplePayPayments = try {
      switch ApplePayTypes.sessionForApplePay->Nullable.toOption {
      | Some(session) => session.canMakePayments()
      | None => false
      }
    } catch {
    | _ => false
    }
    let isApplePayPresent = hasPaymentMethodType("apple_pay") && canMakeApplePayPayments
    let gPayClient = if hasPaymentMethodType("google_pay") {
      try {
        Some(
          GooglePayType.google(
            {
              "environment": publishableKey->String.startsWith("pk_prd_") ? "PRODUCTION" : "TEST",
            }->Identity.anyTypeToJson,
          ),
        )
      } catch {
      | _ => None
      }
    } else {
      None
    }

    if !isApplePayPresent && gPayClient->Option.isNone {
      (None, None, JSON.Encode.null)
    } else {
      let sessionDetails = await PaymentHelpers.fetchSessions(
        ~clientSecret=clientSecretRef.contents,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~isPaymentSession=true,
        ~sdkAuthorization=getSdkAuthorization(),
      )
      let dict = sessionDetails->getDictFromJson

      let applePayToken = if isApplePayPresent {
        let applePaySessionObj = SessionsType.itemToObjMapper(dict, ApplePayObject)
        switch SessionsType.getPaymentSessionObj(applePaySessionObj.sessionsToken, ApplePay) {
        | ApplePayTokenOptional(Some(token)) =>
          Some({
            ApplePayTypes.paymentRequestData: ApplePayTypes.getPaymentRequestFromSession(
              ~sessionObj=Some(token),
              ~componentName,
            ),
            sessionTokenData: Some(token),
          })
        | _ => None
        }
      } else {
        None
      }

      let sessionObj = SessionsType.itemToObjMapper(dict, Others)
      let (googlePayClient, googlePayPaymentDataRequest) = switch (
        gPayClient,
        SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Gpay),
      ) {
      | (Some(client), OtherTokenOptional(Some(gPayToken))) =>
        let payRequest = GooglePayType.assign(
          Dict.make()->JSON.Encode.object,
          GooglePayType.baseRequest->Identity.anyTypeToJson,
          {
            "allowedPaymentMethods": gPayToken.allowed_payment_methods->arrayJsonToCamelCase,
          }->Identity.anyTypeToJson,
        )
        let isReadyToPay = await try {
          client.isReadyToPay(payRequest)
        } catch {
        | err => Promise.reject(err)
        }
        ->then(response => response->getDictFromJson->getBool("result", false)->resolve)
        ->catch(_ => false->resolve)
        isReadyToPay
          ? (
              Some(client),
              GooglePayType.getPaymentDataFromSession(
                ~sessionObj=Some(gPayToken),
                ~componentName,
              )->Identity.anyTypeToJson,
            )
          : (None, JSON.Encode.null)
      | _ => (None, JSON.Encode.null)
      }

      (applePayToken, googlePayClient, googlePayPaymentDataRequest)
    }
  }

  let getSavedPaymentMethods = async options => {
    let optionsDict = options->getOptionsDict
    let hiddenPaymentMethods = optionsDict->getStrArray("hiddenPaymentMethods")
    let excludeExpiredCards = optionsDict->getBool("excludeExpiredCards", false)
    let currentIntentVersion = intentVersion.contents

    let clientList = await PaymentHelpers.fetchClientList(
      ~clientSecret=clientSecretRef.contents,
      ~publishableKey,
      ~logger,
      ~customPodUri,
      ~endpoint,
      ~isPaymentSession=true,
      ~sdkAuthorization=getSdkAuthorization(),
    )

    switch clientList->JSON.Decode.object {
    | None =>
      handleFailureResponse(
        ~message="Failed to fetch saved payment methods.",
        ~errorType="server_error",
      )
    | Some(clientListDict) =>
      let (savedMethods, isGuestCustomer) =
        clientListDict->PaymentType.itemToCustomerObjMapperFromClientList
      let savedMethods =
        savedMethods
        ->PaymentUtils.filterSavedMethodsByHiddenList(~hiddenPaymentMethods)
        ->Array.filter(savedMethod =>
          savedMethod.paymentToken !== "" && !(excludeExpiredCards && savedMethod->isExpiredCard)
        )

      let (applePayToken, googlePayClient, googlePayPaymentDataRequest) = await getWalletSessions(
        savedMethods,
      )->catch(_ => (None, None, JSON.Encode.null)->resolve)

      let savedMethods =
        savedMethods->PaymentUtils.filterSavedMethodsByWalletReadiness(
          ~isApplePayReady=applePayToken->Option.isSome,
          ~isGooglePayReady=googlePayClient->Option.isSome,
        )
      let lastUsedToken = savedMethods->getLastUsedToken

      savedMethodsStateRef :=
        Some({
          savedMethods,
          isGuestCustomer,
          paymentMethodList: clientListDict->PaymentMethodsRecord.itemToObjMapperFromClientList,
          applePayToken,
          googlePayClient,
          googlePayPaymentDataRequest,
          intentVersion: currentIntentVersion,
        })

      logger.setLogInfo(
        ~value=`Saved payment methods listed: ${savedMethods->Array.length->Int.toString}`,
        ~eventName=SAVED_PAYMENT_METHODS_FLOW,
      )

      [
        (
          "paymentMethods",
          savedMethods->Array.map(savedMethodToJson(_, ~lastUsedToken))->JSON.Encode.array,
        ),
        ("isGuestCustomer", isGuestCustomer->JSON.Encode.bool),
      ]->getJsonFromArrayOfJson
    }
  }

  let listSavedPaymentMethods = options =>
    getSavedPaymentMethods(options)->catch(err => {
      let exceptionMessage = err->formatException->JSON.stringify
      logger.setLogError(~value=exceptionMessage, ~eventName=SAVED_PAYMENT_METHODS_FLOW)
      handleFailureResponse(~message=exceptionMessage, ~errorType="server_error")->resolve
    })

  let confirmPaymentIntent = (~body, ~paymentType, ~confirmPayload) =>
    PaymentHelpers.paymentIntentForPaymentSession(
      ~body,
      ~paymentType,
      ~payload=confirmPayload->getIntentPayload,
      ~publishableKey,
      ~clientSecret=clientSecretRef.contents,
      ~logger,
      ~customPodUri,
      ~redirectionFlags,
      ~sdkAuthorization=getSdkAuthorization(),
    )

  let handleApplePayConfirmPayment = (
    ~state,
    ~applePayToken: ApplePayTypes.headlessApplePayToken,
    ~confirmPayload,
  ) =>
    Promise.make((resolve, _) => {
      let processPayment = (payment: ApplePayTypes.paymentResult) => {
        let body =
          ApplePayHelpers.getApplePayFromResponse(
            ~token=payment.token,
            ~billingContactDict=payment.billingContact->getDictFromJson,
            ~shippingContactDict=payment.shippingContact->getDictFromJson,
            ~connectors=[],
            ~isPaymentSession=true,
          )
          ->PaymentUtils.appendedCustomerAcceptance(
            ~isGuestCustomer=state.isGuestCustomer,
            ~paymentType=state.paymentMethodList.payment_type,
            ~body=_,
          )
          ->addMandateBody(~paymentMethodList=state.paymentMethodList)

        confirmPaymentIntent(~body, ~paymentType=Applepay, ~confirmPayload)
        ->then(response => resolve(response)->Promise.resolve)
        ->catch(err =>
          resolve(
            handleFailureResponse(
              ~message=err->formatException->JSON.stringify,
              ~errorType="server_error",
            ),
          )->Promise.resolve
        )
        ->ignore
      }

      ApplePayHelpers.startApplePaySession(
        ~paymentRequest=applePayToken.paymentRequestData,
        ~applePaySessionRef,
        ~applePayPresent=applePayToken.sessionTokenData,
        ~logger,
        ~callBackFunc=processPayment,
        ~resolvePromise=resolve,
        ~clientSecret=clientSecretRef.contents,
        ~publishableKey,
        ~sdkAuthorization=getSdkAuthorization(),
      )
    })

  let handleGooglePayConfirmPayment = (~state, ~client: GooglePayType.client, ~confirmPayload) =>
    client.loadPaymentData(state.googlePayPaymentDataRequest)
    ->then(json => {
      let body =
        GooglePayHelpers.getGooglePayBodyFromResponse(
          ~gPayResponse=json->Identity.anyTypeToJson,
          ~isGuestCustomer=state.isGuestCustomer,
          ~paymentMethodListValue=state.paymentMethodList,
          ~connectors=[],
          ~isPaymentSession=true,
        )->addMandateBody(~paymentMethodList=state.paymentMethodList)
      confirmPaymentIntent(~body, ~paymentType=Gpay, ~confirmPayload)
    })
    ->catch(err =>
      handleFailureResponse(
        ~message=err->Identity.anyTypeToJson->JSON.stringify,
        ~errorType="google_pay",
      )->resolve
    )

  let handleCvcWidgetConfirmPayment = (~body, ~confirmPayload, ~cvcWidgetIframe) =>
    Promise.make((resolve, _) => {
      let listenerKey = "onSavedPaymentMethodCvcConfirmResponse"
      let resolveAndCleanup = response => {
        EventListenerManager.removeSmartEventListener("message", listenerKey)
        resolve(response)
      }

      let handleCvcWidgetConfirmResponse = (event: Types.event) => {
        let eventDataDict = event.data->Identity.anyTypeToJson->getDictFromJson
        switch (
          eventDataDict->Dict.get("cvcWidgetConfirmResponse"),
          eventDataDict->Dict.get("cvcWidgetConfirmErrorResponse"),
        ) {
        | (Some(responseData), _) =>
          let responseDataDict = responseData->getDictFromJson
          switch responseDataDict->Dict.get("data") {
          | Some(_) if confirmPayload.redirect === "always" =>
            EventListenerManager.removeSmartEventListener("message", listenerKey)
            replaceRootHref(responseDataDict->getString("returnUrl", ""), redirectionFlags)
          | Some(data) => resolveAndCleanup(data)
          | None => resolveAndCleanup(responseData)
          }
        | (None, Some(errorResponseData)) =>
          switch errorResponseData->JSON.Decode.string {
          | Some(message) =>
            resolveAndCleanup(handleFailureResponse(~message, ~errorType="server_error"))
          | None => resolveAndCleanup(errorResponseData)
          }
        | (None, None) => ()
        }
      }

      EventListenerManager.addSmartEventListener(
        "message",
        handleCvcWidgetConfirmResponse,
        listenerKey,
      )

      let confirmParams =
        [
          ("body", body->getJsonFromArrayOfJson),
          ("payload", confirmPayload->getIntentPayload),
          ("paymentType", "card"->JSON.Encode.string),
          ("publishableKey", publishableKey->JSON.Encode.string),
          ("clientSecret", clientSecretRef.contents->JSON.Encode.string),
          ("sdkAuthorization", sdkAuthorizationRef.contents->JSON.Encode.string),
          ("requiresCvv", true->JSON.Encode.bool),
          ("redirect", confirmPayload.redirect->JSON.Encode.string),
        ]->getJsonFromArrayOfJson
      cvcWidgetIframe->Window.iframePostMessage(
        [("requestCVCConfirm", confirmParams)]->Dict.fromArray,
      )
    })

  let confirmWithFlow = (~state, ~savedMethod, ~confirmFlow, ~confirmPayload) => {
    let getBody = (~cvc=None) =>
      savedMethod
      ->getSavedMethodBody(~cvc)
      ->addMandateBody(~paymentMethodList=state.paymentMethodList)

    switch (confirmFlow, state.applePayToken, state.googlePayClient) {
    | (ApplePayFlow, Some(applePayToken), _) =>
      handleApplePayConfirmPayment(~state, ~applePayToken, ~confirmPayload)
    | (GooglePayFlow, _, Some(client)) =>
      handleGooglePayConfirmPayment(~state, ~client, ~confirmPayload)
    | (ApplePayFlow | GooglePayFlow, _, _) =>
      handleFailureResponse(
        ~message="Wallet is not available.",
        ~errorType="wallet_unavailable",
      )->resolve
    | (TokenFlow, _, _) => confirmPaymentIntent(~body=getBody(), ~paymentType=Card, ~confirmPayload)
    | (CardFlow(cvc), _, _) =>
      confirmPaymentIntent(~body=getBody(~cvc), ~paymentType=Card, ~confirmPayload)
    | (CvcWidgetFlow(cvcElementId), _, _) =>
      switch (getWidgetIframe(~iframeRef, ~id=cvcElementId), getSdkAuthorization()) {
      | (None, _) =>
        handleFailureResponse(
          ~message="No mounted CVC widget matches `cvcElementId`. Mount the CVC widget or pass `cvc`.",
          ~errorType="cvc_widget_not_found",
        )->resolve
      | (Some(_), None) =>
        handleFailureResponse(
          ~message="The CVC widget requires a session initialised with `sdkAuthorization`.",
          ~errorType="sdk_authorization_missing",
        )->resolve
      | (Some(cvcWidgetIframe), Some(_)) =>
        handleCvcWidgetConfirmPayment(~body=getBody(), ~confirmPayload, ~cvcWidgetIframe)
      }
    }
  }

  let getConfirmError = (confirmPayload, state) =>
    switch state {
    | _ if isTestMode =>
      Some(("test_mode_bypass", "Confirm called in test mode - API call bypassed"))
    | _ if isUpdateIntentInProgress.contents =>
      Some(("update_intent_error", "Cannot confirm payment while updateIntent is in progress."))
    | None =>
      Some((
        "saved_payment_methods_not_loaded",
        "Call listSavedPaymentMethods() before confirmWithSavedPaymentMethod().",
      ))
    | Some(state) if state.intentVersion !== intentVersion.contents =>
      Some((
        "saved_payment_methods_stale",
        "The payment intent was updated. Call listSavedPaymentMethods() again.",
      ))
    | _ if isConfirmInProgress.contents =>
      Some(("confirm_in_progress", "A confirm call is already in progress."))
    | _ if confirmPayload.paymentMethodId === "" =>
      Some(("invalid_request", "`paymentMethodId` is required."))
    | _ if !(confirmPayload.returnUrl->isValidUrl) =>
      Some(("invalid_request", "`confirmParams.return_url` must be an absolute URL."))
    | Some(_) => None
    }

  let confirmWithSavedPaymentMethod = payload => {
    let confirmPayload = payload->itemToConfirmPayloadMapper
    let state = savedMethodsStateRef.contents

    let confirmResult = switch (confirmPayload->getConfirmError(state), state) {
    | (Some(error), _) => Error(error)
    | (None, None) => Error(("saved_payment_methods_not_loaded", ""))
    | (None, Some(state)) =>
      switch state.savedMethods->Array.find((savedMethod: PaymentType.customerMethods) =>
        savedMethod.paymentToken === confirmPayload.paymentMethodId
      ) {
      | None =>
        Error((
          "payment_method_not_found",
          "No saved payment method matches `paymentMethodId` in the current list.",
        ))
      | Some(savedMethod) =>
        savedMethod
        ->getConfirmFlow(
          confirmPayload,
          ~isApplePayReady=state.applePayToken->Option.isSome,
          ~isGooglePayReady=state.googlePayClient->Option.isSome,
        )
        ->Result.map(confirmFlow => (state, savedMethod, confirmFlow))
      }
    }

    switch confirmResult {
    | Error((errorType, message)) => handleFailureResponse(~message, ~errorType)->resolve
    | Ok((state, savedMethod, confirmFlow)) =>
      isConfirmInProgress := true
      logger.setLogInfo(
        ~value=`Confirm with saved payment method: ${savedMethod.paymentMethod}`,
        ~eventName=SAVED_PAYMENT_METHODS_FLOW,
        ~paymentMethod=savedMethod.paymentMethodType
        ->getNonEmptyOption
        ->Option.getOr(savedMethod.paymentMethod),
      )
      try {
        confirmWithFlow(~state, ~savedMethod, ~confirmFlow, ~confirmPayload)
      } catch {
      | err => Promise.reject(err)
      }
      ->then(response => {
        isConfirmInProgress := false
        response->resolve
      })
      ->catch(err => {
        isConfirmInProgress := false
        let exceptionMessage = err->formatException->JSON.stringify
        logger.setLogError(~value=exceptionMessage, ~eventName=SAVED_PAYMENT_METHODS_FLOW)
        handleFailureResponse(~message=exceptionMessage, ~errorType="server_error")->resolve
      })
    }
  }

  {listSavedPaymentMethods, confirmWithSavedPaymentMethod}
}
