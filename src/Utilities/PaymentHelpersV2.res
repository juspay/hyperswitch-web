open Utils
open Identity
open PaymentHelpersTypes
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
                    handleOnPaymentCompleteMessage()
                  } else {
                    closePaymentLoaderIfAny()
                  }

                  postSubmitResponse(~jsonData=data, ~url=url.href)
                } else if confirmParam.redirect === Some("always") {
                  if isCallbackUsedVal->Option.getOr(false) {
                    handleOnPaymentCompleteMessage()
                  } else {
                    handleOpenUrl(url.href)
                  }
                } else {
                  resolve(data)
                }
              | _ =>
                if isCallbackUsedVal->Option.getOr(false) {
                  closePaymentLoaderIfAny()
                  handleOnPaymentCompleteMessage()
                } else {
                  handleOpenUrl(url.href)
                }
              }
            }

            if intent.authenticationDetails.status == "requires_customer_action" {
              if intent.nextAction.type_ == "redirect_to_url" {
                handleOpenUrl(intent.nextAction.redirectToUrl)
              } else {
                let message = "Payment failed. Try again!"
                if !isPaymentSession {
                  postFailedSubmitResponse(~errortype="confirm_payment_failed", ~message)
                }
                let recovered = uri->String.includes("force_sync=true")
                if recovered {
                  handleOpenUrl(url.href)
                } else {
                  let failedSubmitResponse = getFailedSubmitResponse(
                    ~errorType="confirm_payment_failed",
                    ~message,
                  )
                  resolve(failedSubmitResponse)
                }
              }
            } else if intent.authenticationDetails.status != "" {
              handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
            } else {
              handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
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
      | exn =>
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
  let headers = [("Authorization", sdkAuthorization)]->Dict.fromArray
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/list-payment-methods`

  fetchApiForSdk(
    uri,
    ~method=#GET,
    ~headers,
    ~customPodUri=Some(customPodUri),
    ~onSuccess=data => data,
    ~onFailure=_ => JSON.Encode.null,
  )
}

let retrievePaymentMethodSession = (~pmSessionId, ~endpoint, ~customPodUri, ~sdkAuthorization) => {
  let headers = [("Authorization", sdkAuthorization)]->Dict.fromArray
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}`

  fetchApiForSdk(
    uri,
    ~method=#GET,
    ~headers,
    ~customPodUri=Some(customPodUri),
    ~onSuccess=data => data,
    ~onFailure=_ => JSON.Encode.null,
  )
}

let deletePaymentMethodV2 = (
  ~paymentMethodToken,
  ~pmSessionId,
  ~customPodUri,
  ~sdkAuthorization,
) => {
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]->Dict.fromArray
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}`

  fetchApiForSdk(
    uri,
    ~method=#DELETE,
    ~headers,
    ~bodyStr=[("payment_method_token", paymentMethodToken->JSON.Encode.string)]
    ->getJsonFromArrayOfJson
    ->JSON.stringify,
    ~customPodUri=Some(customPodUri),
    ~onSuccess=data => data,
    ~onFailure=_ => JSON.Encode.null,
  )
}

let updatePaymentMethod = (~bodyArr, ~pmSessionId, ~customPodUri, ~sdkAuthorization) => {
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]->Dict.fromArray
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/update-saved-payment-method`

  fetchApiForSdk(
    uri,
    ~method=#PUT,
    ~headers,
    ~bodyStr=bodyArr->getJsonFromArrayOfJson->JSON.stringify,
    ~customPodUri=Some(customPodUri),
    ~onSuccess=data => data,
    ~onFailure=_ => JSON.Encode.null,
  )
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
      let message = "Payment failed. Try again!"
      postFailedSubmitResponse(~errortype="confirm_payment_failed", ~message)
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
      let message = "Payment failed. Try again!"
      postFailedSubmitResponse(~errortype="confirm_payment_failed", ~message)
    }
  }
}

let savePaymentMethod = (~bodyArr, ~pmSessionId, ~sdkAuthorization) => {
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Authorization", sdkAuthorization)]->Dict.fromArray
  let uri = `${endpoint}/v1/payment-method-sessions/${pmSessionId}/confirm`

  fetchApiForSdk(
    uri,
    ~method=#POST,
    ~headers,
    ~bodyStr=bodyArr->getJsonFromArrayOfJson->JSON.stringify,
    ~onSuccess=data => data,
    ~onFailure=_ => JSON.Encode.null,
  )
}
