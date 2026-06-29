open Utils
open Identity
open PaymentHelpersTypes
open LoggerUtils
open URLModule

let intentCall = (
  ~fetchApi: (
    string,
    ~bodyStr: string=?,
    ~headers: Dict.t<string>=?,
    ~method: Fetch.method,
    ~customPodUri: option<string>=?,
    ~publishableKey: option<string>=?,
    ~sdkAuthorization: option<string>=?,
    ~signal: Fetch.AbortSignal.t=?,
  ) => promise<Fetch.Response.t>,
  ~uri,
  ~headers,
  ~bodyStr,
  ~confirmParam: ConfirmType.confirmParams,
  ~optLogger,
  ~handleUserError,
  ~paymentType,
  ~fetchMethod,
  ~customPodUri,
  ~sdkHandleOneClickConfirmPayment,
  ~isPaymentSession=false,
  ~isCallbackUsedVal=?,
  ~redirectionFlags,
) => {
  open Promise
  let isConfirm = uri->String.includes("/confirm")
  let eventName: HyperLoggerTypes.eventName =
    uri->String.includes("update-saved-payment-method")
      ? PAYMENT_MANAGEMENT_UPDATE_CALL
      : PAYMENT_MANAGEMENT_CONFIRM_CALL
  let handleOpenUrl = url => {
    if isPaymentSession {
      Utils.replaceRootHref(url, redirectionFlags)
    } else {
      openUrl(url)
    }
  }
  let handleFailedResponse = data => {
    let url = makeUrl(confirmParam.return_url)
    url.searchParams.set("status", "failed")
    messageParentWindow([("confirmParams", confirmParam->anyTypeToJson)])

    Promise.make((resolve, _) => {
      let dict = data->getDictFromJson
      let errorObj = PaymentError.itemToObjMapper(dict)
      if isConfirm {
        let paymentMethod = switch paymentType {
        | Card => "CARD"
        | _ =>
          bodyStr
          ->safeParse
          ->getDictFromJson
          ->getString("payment_method_type", "")
        }
        handleLogging(
          ~optLogger,
          ~value=`Payment failed: ${errorObj.error.type_}`,
          ~eventName=PAYMENT_FAILED,
          ~paymentMethod,
          ~logType=ERROR,
          ~logCategory=USER_ERROR,
        )
      }
      if !isPaymentSession {
        closePaymentLoaderIfAny()
        postFailedSubmitResponse(~errortype=errorObj.error.type_, ~message=errorObj.error.message)
      }
      if handleUserError {
        handleOpenUrl(url.href)
      } else {
        let failedSubmitResponse = getFailedSubmitResponse(
          ~errorType=errorObj.error.type_,
          ~message=errorObj.error.message,
        )
        resolve(failedSubmitResponse)
      }
    })
  }

  let handleSuccessResponse = data =>
    Promise.make((resolve, _) => {
      let intent = PaymentConfirmTypesV2.itemToPMMConfirmMapper(data->getDictFromJson)
      let paymentMethod = switch paymentType {
      | Card => "CARD"
      | _ => "CARD"
      }

      let url = makeUrl(confirmParam.return_url)
      url.searchParams.set("status", intent.authenticationDetails.status)

      let handleProcessingStatus = (paymentType, sdkHandleOneClickConfirmPayment) => {
        switch (paymentType, sdkHandleOneClickConfirmPayment) {
        | (Card, _)
        | (Gpay, false)
        | (Applepay, false)
        | (Paypal, false) =>
          if !isPaymentSession {
            if isCallbackUsedVal->Option.getOr(false) {
              handleOnCompleteDoThisMessage()
            } else {
              closePaymentLoaderIfAny()
            }

            postSubmitResponse(~jsonData=data, ~url=url.href)
          } else if confirmParam.redirect === Some("always") {
            if isCallbackUsedVal->Option.getOr(false) {
              handleOnCompleteDoThisMessage()
            } else {
              handleOpenUrl(url.href)
            }
          } else {
            resolve(data)
          }
        | _ =>
          if isCallbackUsedVal->Option.getOr(false) {
            closePaymentLoaderIfAny()
            handleOnCompleteDoThisMessage()
          } else {
            handleOpenUrl(url.href)
          }
        }
      }

      if intent.authenticationDetails.status == "requires_customer_action" {
        if intent.nextAction.type_ == "redirect_to_url" {
          handleLogging(
            ~optLogger,
            ~value="",
            // ~internalMetadata=intent.nextAction.redirectToUrl,
            ~eventName=REDIRECTING_USER,
            ~paymentMethod,
          )
          handleOpenUrl(intent.nextAction.redirectToUrl)
        } else {
          handleLogging(
            ~optLogger,
            ~value=`Unsupported next action for payment management confirm: ${intent.nextAction.type_}`,
            ~eventName=PAYMENT_MANAGEMENT_CONFIRM_CALL,
            ~paymentMethod,
            ~logType=ERROR,
            ~logCategory=USER_ERROR,
          )
          if !isPaymentSession {
            postFailedSubmitResponse(
              ~errortype="confirm_payment_failed",
              ~message="Payment failed. Try again!",
            )
          }
          if uri->String.includes("force_sync=true") {
            handleOpenUrl(url.href)
          } else {
            let failedSubmitResponse = getFailedSubmitResponse(
              ~errorType="confirm_payment_failed",
              ~message="Payment failed. Try again!",
            )
            resolve(failedSubmitResponse)
          }
        }
      } else if intent.authenticationDetails.status != "" {
        if intent.authenticationDetails.status === "succeeded" {
          handleLogging(
            ~optLogger,
            ~value=intent.authenticationDetails.status,
            ~eventName=PAYMENT_SUCCESS,
            ~paymentMethod,
          )
        } else if intent.authenticationDetails.status === "failed" {
          handleLogging(
            ~optLogger,
            ~value=intent.authenticationDetails.status,
            ~eventName=PAYMENT_FAILED,
            ~paymentMethod,
          )
        }
        handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
      } else {
        handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
        handleLogging(~optLogger, ~value="succeeded", ~eventName=PAYMENT_SUCCESS, ~paymentMethod)
        url.searchParams.set("status", "succeeded")
      }
    })

  let handleException = _err =>
    Promise.make((resolve, _) => {
      try {
        let url = makeUrl(confirmParam.return_url)
        url.searchParams.set("status", "failed")

        if !isPaymentSession {
          closePaymentLoaderIfAny()
          postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
        }
        if handleUserError {
          handleOpenUrl(url.href)
        } else {
          let failedSubmitResponse = getFailedSubmitResponse(
            ~errorType="server_error",
            ~message="Something went wrong",
          )
          resolve(failedSubmitResponse)
        }
      } catch {
      | _ =>
        handleLogging(
          ~optLogger,
          ~value="Failed to build payment management confirm failure response",
          ~eventName=PAYMENT_MANAGEMENT_CONFIRM_CALL,
          ~paymentMethod="CARD",
          ~logType=ERROR,
          ~logCategory=USER_ERROR,
        )
        if !isPaymentSession {
          postFailedSubmitResponse(~errortype="error", ~message="Something went wrong")
        }
        let failedSubmitResponse = getFailedSubmitResponse(
          ~errorType="server_error",
          ~message="Something went wrong",
        )
        resolve(failedSubmitResponse)
      }
    })

  switch optLogger {
  | Some(logger) =>
    fetchApiWithLogging(
      uri,
      ~eventName,
      ~logger,
      ~onSuccess=handleSuccessResponse,
      ~onFailure=handleFailedResponse,
      ~onCatchCallback=Some(handleException),
      ~method=fetchMethod,
      ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
      ~bodyStr,
      ~customPodUri=Some(customPodUri),
      ~isPaymentSession,
    )->then(result => result)
  | None =>
    fetchApi(
      uri,
      ~method=fetchMethod,
      ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
      ~bodyStr,
    )
    ->then(res => {
      if !(res->Fetch.Response.ok) {
        res
        ->Fetch.Response.json
        ->then(handleFailedResponse)
        ->catch(err => {
          let exceptionMessage = err->formatException
          handleException(exceptionMessage)
        })
      } else {
        res->Fetch.Response.json->then(handleSuccessResponse)
      }
    })
    ->catch(err => {
      let exceptionMessage = err->formatException
      handleException(exceptionMessage)
    })
  }
}

let fetchPaymentManagementList = (
  ~pmSessionId,
  ~endpoint,
  ~optLogger,
  ~customPodUri,
  ~sdkAuthorization,
) => {
  open Promise
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/list-payment-methods`

  let onSuccess = data => data
  let onFailure = _err => {
    Console.error("Payment management list failed")
    JSON.Encode.null
  }

  switch optLogger {
  | Some(logger) =>
    fetchApiWithLogging(
      uri,
      ~eventName=PAYMENT_MANAGEMENT_LIST_CALL,
      ~logger,
      ~onSuccess,
      ~onFailure,
      ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
      ~method=#GET,
      ~customPodUri=Some(customPodUri),
      ~isPaymentSession=true,
    )
  | None =>
    fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
    ->then(res => {
      if !(res->Fetch.Response.ok) {
        res
        ->Fetch.Response.json
        ->then(_ => {
          JSON.Encode.null->resolve
        })
      } else {
        res->Fetch.Response.json
      }
    })
    ->catch(err => {
      let _exceptionMessage = err->formatException
      Console.error("Payment management list request failed")
      JSON.Encode.null->resolve
    })
  }
}

let deletePaymentMethodV2 = (
  ~paymentMethodToken,
  ~pmSessionId,
  ~logger,
  ~customPodUri,
  ~sdkAuthorization,
) => {
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}`
  let bodyStr =
    [("payment_method_token", paymentMethodToken->JSON.Encode.string)]
    ->getJsonFromArrayOfJson
    ->JSON.stringify
  let onSuccess = data => data
  let onFailure = _err => {
    Console.error("Payment management delete failed")
    JSON.Encode.null
  }

  fetchApiWithLogging(
    uri,
    ~eventName=PAYMENT_MANAGEMENT_DELETE_CALL,
    ~logger,
    ~onSuccess,
    ~onFailure,
    ~method=#DELETE,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~bodyStr,
    ~customPodUri=Some(customPodUri),
    ~isPaymentSession=true,
  )
}

let updatePaymentMethod = (~bodyArr, ~pmSessionId, ~logger, ~customPodUri, ~sdkAuthorization) => {
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/update-saved-payment-method`
  let bodyStr = bodyArr->getJsonFromArrayOfJson->JSON.stringify
  let onSuccess = data => data
  let onFailure = _err => {
    Console.error("Payment management update failed")
    JSON.Encode.null
  }

  fetchApiWithLogging(
    uri,
    ~eventName=PAYMENT_MANAGEMENT_UPDATE_CALL,
    ~logger,
    ~onSuccess,
    ~onFailure,
    ~method=#PUT,
    ~bodyStr,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~customPodUri=Some(customPodUri),
    ~isPaymentSession=true,
  )
}

let useSaveCard = (optLogger: option<HyperLoggerTypes.loggerMake>, paymentType: payment) => {
  open RecoilAtoms
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let {sdkAuthorization} = keys
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
  ) => {
    switch keys.pmSessionId {
    | Some(pmSessionId) =>
      let headers = [("Authorization", sdkAuthorization->Option.getOr(""))]
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/confirm`

      let browserInfo = BrowserSpec.broswerInfo
      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let bodyStr =
        bodyArr
        ->Array.concatMany([browserInfo(), returnUrlArr])
        ->getJsonFromArrayOfJson
        ->JSON.stringify

      let saveCard = () => {
        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr,
          ~confirmParam: ConfirmType.confirmParams,
          ~optLogger,
          ~handleUserError,
          ~paymentType,
          ~fetchMethod=#POST,
          ~customPodUri,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~isCallbackUsedVal,
          ~redirectionFlags,
        )->ignore
      }

      switch paymentManagementList {
      | LoadedV2(_) => saveCard()
      | _ => ()
      }
    | None => {
        handleLogging(
          ~optLogger,
          ~value="pmSessionId missing for save card",
          ~eventName=PAYMENT_MANAGEMENT_CONFIRM_CALL,
          ~paymentMethod="CARD",
          ~logType=ERROR,
          ~logCategory=USER_ERROR,
        )
        postFailedSubmitResponse(
          ~errortype="confirm_payment_failed",
          ~message="Payment failed. Try again!",
        )
      }
    }
  }
}

let useUpdateCard = (optLogger: option<HyperLoggerTypes.loggerMake>, paymentType: payment) => {
  open RecoilAtoms
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let {sdkAuthorization} = keys
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
  ) => {
    switch keys.pmSessionId {
    | Some(pmSessionId) =>
      let headers = [("Authorization", sdkAuthorization->Option.getOr(""))]
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/update-saved-payment-method`

      let browserInfo = BrowserSpec.broswerInfo
      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let bodyStr =
        bodyArr
        ->Array.concatMany([browserInfo(), returnUrlArr])
        ->getJsonFromArrayOfJson
        ->JSON.stringify

      let updateCard = () => {
        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr,
          ~confirmParam: ConfirmType.confirmParams,
          ~optLogger,
          ~handleUserError,
          ~paymentType,
          ~fetchMethod=#PUT,
          ~customPodUri,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~isCallbackUsedVal,
          ~redirectionFlags,
        )->ignore
      }

      switch paymentManagementList {
      | LoadedV2(_) => updateCard()
      | _ => ()
      }
    | None => {
        handleLogging(
          ~optLogger,
          ~value="pmSessionId missing for update card",
          ~eventName=PAYMENT_MANAGEMENT_UPDATE_CALL,
          ~paymentMethod="CARD",
          ~logType=ERROR,
          ~logCategory=USER_ERROR,
        )
        postFailedSubmitResponse(
          ~errortype="confirm_payment_failed",
          ~message="Payment failed. Try again!",
        )
      }
    }
  }
}

let savePaymentMethod = (~bodyArr, ~pmSessionId, ~sdkAuthorization, ~logger) => {
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/confirm`
  let bodyStr = bodyArr->getJsonFromArrayOfJson->JSON.stringify
  let onSuccess = data => data
  let onFailure = _err => {
    Console.error("Payment management confirm failed")
    JSON.Encode.null
  }

  fetchApiWithLogging(
    uri,
    ~eventName=PAYMENT_MANAGEMENT_CONFIRM_CALL,
    ~logger,
    ~onSuccess,
    ~onFailure,
    ~method=#POST,
    ~bodyStr,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri=""),
    ~customPodUri=Some(""),
    ~isPaymentSession=true,
  )
}
