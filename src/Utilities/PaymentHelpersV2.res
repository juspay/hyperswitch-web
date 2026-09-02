open Utils
open Identity
open PaymentHelpersTypes
open URLModule
open LoggerCommonHelpers

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
  let handleOpenUrl = url => {
    if isPaymentSession {
      Utils.replaceRootHref(url, redirectionFlags)
    } else {
      openUrl(url)
    }
  }
  fetchApi(
    uri,
    ~method=fetchMethod,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~bodyStr,
  )
  ->then(res => {
    let url = makeUrl(confirmParam.return_url)
    url.searchParams.set("status", "failed")
    messageParentWindow([("confirmParams", confirmParam->anyTypeToJson)])

    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        Promise.make(
          (resolve, _) => {
            if isConfirm {
              let paymentMethod = switch paymentType {
              | Card => "CARD"
              | _ =>
                bodyStr
                ->safeParse
                ->getDictFromJson
                ->getString("payment_method_type", "")
              }
              CorePaymentLogger.logLifecycle(
                ~event=PaymentFailed,
                ~message=data->JSON.stringify,
                ~paymentMethod,
              )
            }
            let dict = data->getDictFromJson
            let errorObj = PaymentError.itemToObjMapper(dict)
            if !isPaymentSession {
              closePaymentLoaderIfAny()
              postFailedSubmitResponse(
                ~errortype=errorObj.error.type_,
                ~message=errorObj.error.message,
              )
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
          },
        )->then(resolve)
      })
      ->catch(err => {
        Promise.make(
          (resolve, _) => {
            let _exceptionMessage = err->formatException
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
          },
        )->then(resolve)
      })
    } else {
      res
      ->Fetch.Response.json
      ->then(data => {
        Promise.make(
          (resolve, _) => {
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
                CorePaymentLogger.logLifecycle(~event=RedirectingUser, ~paymentMethod)
                handleOpenUrl(intent.nextAction.redirectToUrl)
              } else {
                if !isPaymentSession {
                  postFailedSubmitResponse(
                    ~errortype="confirm_payment_failed",
                    ~message="Payment failed. Try again!",
                  )
                }
                if uri->String.includes("force_sync=true") {
                  CorePaymentLogger.logLifecycle(
                    ~event=RedirectingUserFailed,
                    ~message=intent.nextAction.type_,
                    ~paymentMethod,
                  )
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
                CorePaymentLogger.logLifecycle(
                  ~event=PaymentSuccess,
                  ~message=intent.authenticationDetails.status,
                  ~paymentMethod,
                )
              } else if intent.authenticationDetails.status === "failed" {
                CorePaymentLogger.logLifecycle(
                  ~event=PaymentFailed,
                  ~message=intent.authenticationDetails.status,
                  ~paymentMethod,
                )
              }
              handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
            } else {
              handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
              CorePaymentLogger.logLifecycle(
                ~event=PaymentSuccess,
                ~message="succeeded",
                ~paymentMethod,
              )
              url.searchParams.set("status", "succeeded")
            }
          },
        )->then(resolve)
      })
    }
  })
  ->catch(err => {
    Promise.make((resolve, _) => {
      try {
        let url = makeUrl(confirmParam.return_url)
        url.searchParams.set("status", "failed")
        let _exceptionMessage = err->formatException

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
        if !isPaymentSession {
          postFailedSubmitResponse(~errortype="error", ~message="Something went wrong")
        }
        let failedSubmitResponse = getFailedSubmitResponse(
          ~errorType="server_error",
          ~message="Something went wrong",
        )
        resolve(failedSubmitResponse)
      }
    })->then(resolve)
  })
}

let fetchPaymentManagementList = (~pmSessionId, ~endpoint, ~customPodUri, ~sdkAuthorization) => {
  open Promise
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/list-payment-methods`

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
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let retrievePaymentMethodSession = (~pmSessionId, ~endpoint, ~customPodUri, ~sdkAuthorization) => {
  open Promise
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}`

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
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let deletePaymentMethodV2 = (
  ~paymentMethodToken,
  ~pmSessionId,
  ~customPodUri,
  ~sdkAuthorization,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}`
  fetchApi(
    uri,
    ~method=#DELETE,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~bodyStr=[("payment_method_token", paymentMethodToken->JSON.Encode.string)]
    ->getJsonFromArrayOfJson
    ->JSON.stringify,
  )
  ->then(resp => {
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(_ => {
        JSON.Encode.null->resolve
      })
    } else {
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let updatePaymentMethod = (~bodyArr, ~pmSessionId, ~customPodUri, ~sdkAuthorization) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/update-saved-payment-method`

  fetchApi(
    uri,
    ~method=#PUT,
    ~bodyStr=bodyArr->getJsonFromArrayOfJson->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(_ => {
        JSON.Encode.null->resolve
      })
    } else {
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let useSaveCard = (paymentType: payment) => {
  open JotaiAtoms
  let paymentManagementList = Jotai.useAtomValue(JotaiAtomsV2.paymentManagementList)
  let keys = Jotai.useAtomValue(keys)
  let {sdkAuthorization} = keys
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let isCallbackUsedVal = Jotai.useAtomValue(JotaiAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Jotai.useAtomValue(redirectionFlagsAtom)
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
    | None =>
      postFailedSubmitResponse(
        ~errortype="confirm_payment_failed",
        ~message="Payment failed. Try again!",
      )
    }
  }
}

let useUpdateCard = (paymentType: payment) => {
  open JotaiAtoms
  let paymentManagementList = Jotai.useAtomValue(JotaiAtomsV2.paymentManagementList)
  let keys = Jotai.useAtomValue(keys)
  let {sdkAuthorization} = keys
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let isCallbackUsedVal = Jotai.useAtomValue(JotaiAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Jotai.useAtomValue(redirectionFlagsAtom)
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
    | None =>
      postFailedSubmitResponse(
        ~errortype="confirm_payment_failed",
        ~message="Payment failed. Try again!",
      )
    }
  }
}

let savePaymentMethod = (~bodyArr, ~pmSessionId, ~sdkAuthorization) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/confirm`

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=bodyArr->getJsonFromArrayOfJson->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri=""),
  )
  ->then(resp => {
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(_ => {
        JSON.Encode.null->resolve
      })
    } else {
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}
