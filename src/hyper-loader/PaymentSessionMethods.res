open Promise
open Types
open Utils

let getCustomerSavedPaymentMethods = (
  ~clientSecret,
  ~publishableKey,
  ~endpoint,
  ~logger,
  ~customPodUri,
  ~redirectionFlags,
) => {
  open ApplePayTypes
  open GooglePayType
  let applePaySessionRef = ref(Nullable.null)

  PaymentHelpers.fetchCustomerPaymentMethodList(
    ~clientSecret,
    ~publishableKey,
    ~endpoint,
    ~customPodUri,
    ~logger,
    ~isPaymentSession=true,
  )
  ->then(customerDetails => {
    let gPayClient = google(
      {
        "environment": publishableKey->String.startsWith("pk_prd_") ? "PRODUCTION" : "TEST",
      }->Identity.anyTypeToJson,
    )

    let customerDetailsDict = customerDetails->JSON.Decode.object->Option.getOr(Dict.make())
    let customerPaymentMethods = customerDetailsDict->PaymentType.itemToCustomerObjMapper

    customerPaymentMethods->Array.sort((a, b) => compareLogic(a.lastUsedAt, b.lastUsedAt))

    let customerPaymentMethodsRef = ref(customerPaymentMethods)
    let applePayTokenRef = ref(defaultHeadlessApplePayToken)
    let googlePayTokenRef = ref(JSON.Encode.null)

    let isApplePayPresent =
      customerPaymentMethods
      ->Array.find(customerPaymentMethod =>
        customerPaymentMethod.paymentMethodType === Some("apple_pay")
      )
      ->Option.isSome

    let isGooglePayPresent =
      customerPaymentMethods
      ->Array.find(customerPaymentMethod =>
        customerPaymentMethod.paymentMethodType === Some("google_pay")
      )
      ->Option.isSome

    let canMakePayments = try {
      switch sessionForApplePay->Nullable.toOption {
      | Some(session) => session.canMakePayments()
      | _ => false
      }
    } catch {
    | _ => false
    }

    let customerDefaultPaymentMethod =
      customerPaymentMethods
      ->Array.filter(customerPaymentMethod => {
        customerPaymentMethod.defaultPaymentMethodSet
      })
      ->Array.get(0)

    let getCustomerDefaultSavedPaymentMethodData = () => {
      switch customerDefaultPaymentMethod {
      | Some(defaultPaymentMethod) => defaultPaymentMethod->Identity.anyTypeToJson
      | None =>
        handleFailureResponse(
          ~message="There is no default saved payment method data for this customer.",
          ~errorType="no_data",
        )
      }
    }

    let getCustomerLastUsedPaymentMethodData = () => {
      switch customerPaymentMethodsRef.contents->Array.get(0) {
      | Some(lastUsedPaymentMethod) => lastUsedPaymentMethod->Identity.anyTypeToJson
      | None =>
        handleFailureResponse(
          ~message="No recent payments found for this customer.",
          ~errorType="no_data",
        )
      }
    }

    let confirmWithCustomerDefaultPaymentMethod = payload => {
      switch customerDefaultPaymentMethod {
      | Some(defaultPaymentMethod) => {
          let paymentToken = defaultPaymentMethod.paymentToken
          let paymentMethod = defaultPaymentMethod.paymentMethod
          let paymentMethodType = defaultPaymentMethod.paymentMethodType->Option.getOr("")
          let paymentType = paymentMethodType->PaymentHelpers.getPaymentType

          let body = [
            ("payment_method", paymentMethod->JSON.Encode.string),
            ("payment_token", paymentToken->JSON.Encode.string),
          ]

          if paymentMethodType !== "" {
            body->Array.push(("payment_method_type", paymentMethodType->JSON.Encode.string))->ignore
          }

          PaymentHelpers.paymentIntentForPaymentSession(
            ~body,
            ~paymentType,
            ~payload,
            ~publishableKey,
            ~clientSecret,
            ~logger,
            ~customPodUri,
            ~redirectionFlags,
          )
        }
      | None =>
        handleFailureResponse(
          ~message="There is no default saved payment method data for this customer.",
          ~errorType="no_data",
        )->resolve
      }
    }

    let handleApplePayConfirmPayment = (
      lastUsedPaymentMethod: PaymentType.customerMethods,
      payload,
      resolvePromise,
    ) => {
      let processPayment = (payment: ApplePayTypes.paymentResult) => {
        let token = payment.token

        let billingContactDict = payment.billingContact->Utils.getDictFromJson
        let shippingContactDict = payment.shippingContact->Utils.getDictFromJson

        let completeApplePayPayment = () => {
          let applePayBody = ApplePayHelpers.getApplePayFromResponse(
            ~token,
            ~billingContactDict,
            ~shippingContactDict,
            ~connectors=[],
            ~isPaymentSession=true,
          )

          let requestBody = PaymentUtils.appendedCustomerAcceptance(
            ~paymentType=NONE,
            ~body=applePayBody,
          )

          let paymentMethodType = lastUsedPaymentMethod.paymentMethodType->Option.getOr("")
          let paymentType = paymentMethodType->PaymentHelpers.getPaymentType

          PaymentHelpers.paymentIntentForPaymentSession(
            ~body=requestBody,
            ~paymentType,
            ~payload,
            ~publishableKey,
            ~clientSecret,
            ~logger,
            ~customPodUri,
            ~redirectionFlags,
          )->then(val => {
            val->resolvePromise
            resolve()
          })
        }

        completeApplePayPayment()->ignore
      }

      ApplePayHelpers.startApplePaySession(
        ~paymentRequest=applePayTokenRef.contents.paymentRequestData,
        ~applePaySessionRef,
        ~applePayPresent=applePayTokenRef.contents.sessionTokenData,
        ~logger,
        ~callBackFunc=processPayment,
        ~clientSecret,
        ~publishableKey,
        ~resolvePromise,
      )
    }

    let handleGooglePayConfirmPayment = (
      lastUsedPaymentMethod: PaymentType.customerMethods,
      payload,
    ) => {
      let paymentDataRequest = googlePayTokenRef.contents

      gPayClient.loadPaymentData(paymentDataRequest)
      ->then(json => {
        let metadata = json->Identity.anyTypeToJson

        let value = "Payment Data Filled: New Payment Method"
        logger.setLogInfo(~value, ~eventName=PAYMENT_DATA_FILLED, ~paymentMethod="GOOGLE_PAY")

        let completeGooglePayPayment = () => {
          let body = GooglePayHelpers.getGooglePayBodyFromResponse(
            ~gPayResponse=metadata,
            ~connectors=[],
            ~isPaymentSession=true,
          )

          let paymentMethodType = lastUsedPaymentMethod.paymentMethodType->Option.getOr("")
          let paymentType = paymentMethodType->PaymentHelpers.getPaymentType

          PaymentHelpers.paymentIntentForPaymentSession(
            ~body,
            ~paymentType,
            ~payload,
            ~publishableKey,
            ~clientSecret,
            ~logger,
            ~customPodUri,
            ~redirectionFlags,
          )
        }

        completeGooglePayPayment()
      })
      ->catch(err => {
        logger.setLogInfo(
          ~value=err->Identity.anyTypeToJson->JSON.stringify,
          ~eventName=GOOGLE_PAY_FLOW,
          ~paymentMethod="GOOGLE_PAY",
          ~logType=DEBUG,
        )

        handleFailureResponse(
          ~message=err->Identity.anyTypeToJson->JSON.stringify,
          ~errorType="google_pay",
        )->resolve
      })
    }

    let confirmWithLastUsedPaymentMethod = payload => {
      switch customerPaymentMethodsRef.contents->Array.get(0) {
      | Some(lastUsedPaymentMethod) =>
        if lastUsedPaymentMethod.paymentMethodType === Some("apple_pay") {
          Promise.make((resolve, _) => {
            handleApplePayConfirmPayment(lastUsedPaymentMethod, payload, resolve)
          })
        } else if lastUsedPaymentMethod.paymentMethodType === Some("google_pay") {
          handleGooglePayConfirmPayment(lastUsedPaymentMethod, payload)
        } else {
          let paymentToken = lastUsedPaymentMethod.paymentToken
          let paymentMethod = lastUsedPaymentMethod.paymentMethod
          let paymentMethodType = lastUsedPaymentMethod.paymentMethodType->Option.getOr("")
          let paymentType = paymentMethodType->PaymentHelpers.getPaymentType
          let isCustomerAcceptanceRequired = lastUsedPaymentMethod.recurringEnabled->not

          let body = [
            ("payment_method", paymentMethod->JSON.Encode.string),
            ("payment_token", paymentToken->JSON.Encode.string),
          ]

          if isCustomerAcceptanceRequired {
            body->Array.push(("customer_acceptance", PaymentBody.customerAcceptanceBody))->ignore
          }

          if paymentMethodType !== "" {
            body->Array.push(("payment_method_type", paymentMethodType->JSON.Encode.string))->ignore
          }

          PaymentHelpers.paymentIntentForPaymentSession(
            ~body,
            ~paymentType,
            ~payload,
            ~publishableKey,
            ~clientSecret,
            ~logger,
            ~customPodUri,
            ~redirectionFlags,
          )
        }
      | None =>
        handleFailureResponse(
          ~message="No recent payments found for this customer.",
          ~errorType="no_data",
        )->resolve
      }
    }

    let updateCustomerPaymentMethodsRef = (~isFilterApplePay=false, ~isFilterGooglePay=false) => {
      let filterArray = []
      if isFilterApplePay {
        filterArray->Array.push("apple_pay")
      }
      if isFilterGooglePay {
        filterArray->Array.push("google_pay")
      }
      let updatedCustomerDetails =
        customerPaymentMethodsRef.contents->Array.filter(customerPaymentMethod => {
          filterArray
          ->Array.includes(customerPaymentMethod.paymentMethodType->Option.getOr(""))
          ->not
        })

      customerPaymentMethodsRef := updatedCustomerDetails
    }

    if (isApplePayPresent && canMakePayments) || isGooglePayPresent {
      PaymentHelpers.fetchSessions(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
      )
      ->then(sessionDetails => {
        let componentName = "headless"
        let dict = sessionDetails->Utils.getDictFromJson
        let sessionObj = SessionsType.itemToObjMapper(dict, Others)

        let applePaySessionObj = SessionsType.itemToObjMapper(dict, ApplePayObject)
        let applePayToken = SessionsType.getPaymentSessionObj(
          applePaySessionObj.sessionsToken,
          ApplePay,
        )

        let gPayToken = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Gpay)

        let gPayTokenObj = switch gPayToken {
        | OtherTokenOptional(optToken) => optToken
        | _ => Some(SessionsType.defaultToken)
        }

        let gPayobj = switch gPayTokenObj {
        | Some(val) => val
        | _ => SessionsType.defaultToken
        }

        let payRequest = assign(
          Dict.make()->JSON.Encode.object,
          baseRequest->Identity.anyTypeToJson,
          {
            "allowedPaymentMethods": gPayobj.allowed_payment_methods->arrayJsonToCamelCase,
          }->Identity.anyTypeToJson,
        )

        let isGooglePayReadyPromise = try {
          gPayClient.isReadyToPay(payRequest)
          ->then(
            res => {
              let dict = res->getDictFromJson
              getBool(dict, "result", false)->resolve
            },
          )
          ->catch(
            err => {
              logger.setLogInfo(
                ~value=err->Identity.anyTypeToJson->JSON.stringify,
                ~eventName=GOOGLE_PAY_FLOW,
                ~paymentMethod="GOOGLE_PAY",
                ~logType=DEBUG,
              )
              false->resolve
            },
          )
        } catch {
        | exn => {
            logger.setLogInfo(
              ~value=exn->Identity.anyTypeToJson->JSON.stringify,
              ~eventName=GOOGLE_PAY_FLOW,
              ~paymentMethod="GOOGLE_PAY",
              ~logType=DEBUG,
            )
            false->resolve
          }
        }

        isGooglePayReadyPromise
        ->then(
          isGooglePayReady => {
            if isGooglePayReady {
              let paymentDataRequest = getPaymentDataFromSession(
                ~sessionObj=gPayTokenObj,
                ~componentName,
              )
              googlePayTokenRef := paymentDataRequest->Identity.anyTypeToJson
            } else {
              updateCustomerPaymentMethodsRef(~isFilterGooglePay=true)
            }
            resolve()
          },
        )
        ->catch(
          err => {
            logger.setLogInfo(
              ~value=err->Identity.anyTypeToJson->JSON.stringify,
              ~eventName=GOOGLE_PAY_FLOW,
              ~paymentMethod="GOOGLE_PAY",
              ~logType=DEBUG,
            )
            resolve()
          },
        )
        ->ignore

        switch applePayToken {
        | ApplePayTokenOptional(optToken) => {
            let paymentRequest = ApplePayTypes.getPaymentRequestFromSession(
              ~sessionObj=optToken,
              ~componentName,
            )
            applePayTokenRef := {
                paymentRequestData: paymentRequest,
                sessionTokenData: optToken,
              }
          }
        | _ => updateCustomerPaymentMethodsRef(~isFilterApplePay=true)
        }

        {
          getCustomerDefaultSavedPaymentMethodData,
          getCustomerLastUsedPaymentMethodData,
          confirmWithCustomerDefaultPaymentMethod,
          confirmWithLastUsedPaymentMethod,
        }
        ->Identity.anyTypeToJson
        ->resolve
      })
      ->catch(_ => {
        updateCustomerPaymentMethodsRef(~isFilterApplePay=true, ~isFilterGooglePay=true)

        {
          getCustomerDefaultSavedPaymentMethodData,
          getCustomerLastUsedPaymentMethodData,
          confirmWithCustomerDefaultPaymentMethod,
          confirmWithLastUsedPaymentMethod,
        }
        ->Identity.anyTypeToJson
        ->resolve
      })
    } else {
      updateCustomerPaymentMethodsRef(~isFilterApplePay=true, ~isFilterGooglePay=true)

      {
        getCustomerDefaultSavedPaymentMethodData,
        getCustomerLastUsedPaymentMethodData,
        confirmWithCustomerDefaultPaymentMethod,
        confirmWithLastUsedPaymentMethod,
      }
      ->Identity.anyTypeToJson
      ->resolve
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException->JSON.stringify
    handleFailureResponse(~message=exceptionMessage, ~errorType="server_error")->resolve
  })
}

let getPaymentManagementMethods = (~ephemeralKey, ~logger, ~customPodUri, ~endpoint) => {
  let getSavedPaymentManagementMethodsList = _ => {
    PaymentHelpers.fetchSavedPaymentMethodList(~ephemeralKey, ~logger, ~customPodUri, ~endpoint)
    ->then(response => {
      response->resolve
    })
    ->catch(err => {
      let exceptionMessage = err->formatException->JSON.stringify
      handleFailureResponse(~message=exceptionMessage, ~errorType="server_error")->resolve
    })
  }

  let deleteSavedPaymentMethod = paymentMethodId => {
    PaymentHelpers.deletePaymentMethod(
      ~ephemeralKey,
      ~paymentMethodId={paymentMethodId->JSON.Decode.string->Option.getOr("")},
      ~logger,
      ~customPodUri,
    )
    ->then(response => {
      response->resolve
    })
    ->catch(err => {
      let exceptionMessage = err->formatException->JSON.stringify
      handleFailureResponse(~message=exceptionMessage, ~errorType="server_error")->resolve
    })
  }

  {
    getSavedPaymentManagementMethodsList,
    deleteSavedPaymentMethod,
  }
  ->Identity.anyTypeToJson
  ->resolve
}
