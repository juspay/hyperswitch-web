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
  ) => promise<Fetch.Response.t>,
  ~uri,
  ~headers,
  ~bodyStr,
  ~confirmParam: ConfirmType.confirmParams,
  ~clientSecret,
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
    url.searchParams.set("client_secret", clientSecret)
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
              handleLogging(
                ~optLogger,
                ~value=data->JSON.stringify,
                ~eventName=PAYMENT_FAILED,
                ~paymentMethod,
              )
            }
            let dict = data->getDictFromJson
            let errorObj = PaymentError.itemToObjMapper(dict)
            if !isPaymentSession {
              PaymentHelpers.closePaymentLoaderIfAny()
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
              PaymentHelpers.closePaymentLoaderIfAny()
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
            url.searchParams.set("client_secret", clientSecret)
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
                    PaymentHelpers.closePaymentLoaderIfAny()
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
                  PaymentHelpers.closePaymentLoaderIfAny()
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
                  ~internalMetadata=intent.nextAction.redirectToUrl,
                  ~eventName=REDIRECTING_USER,
                  ~paymentMethod,
                )
                handleOpenUrl(intent.nextAction.redirectToUrl)
              } else {
                if !isPaymentSession {
                  postFailedSubmitResponse(
                    ~errortype="confirm_payment_failed",
                    ~message="Payment failed. Try again!",
                  )
                }
                if uri->String.includes("force_sync=true") {
                  handleLogging(
                    ~optLogger,
                    ~value=intent.nextAction.type_,
                    ~internalMetadata=intent.nextAction.type_,
                    ~eventName=REDIRECTING_USER,
                    ~paymentMethod,
                    ~logType=ERROR,
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
              handleLogging(
                ~optLogger,
                ~value="succeeded",
                ~eventName=PAYMENT_SUCCESS,
                ~paymentMethod,
              )
              url.searchParams.set("status", "succeeded")
              handleOpenUrl(url.href)
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
        url.searchParams.set("client_secret", clientSecret)
        url.searchParams.set("status", "failed")
        let _exceptionMessage = err->formatException

        if !isPaymentSession {
          PaymentHelpers.closePaymentLoaderIfAny()
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

let fetchPaymentManagementList = (
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~profileId,
  ~endpoint,
  ~optLogger as _,
  ~customPodUri,
) => {
  open Promise
  let headers = [
    ("x-profile-id", `${profileId}`),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}/list-payment-methods`

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
  ~pmClientSecret,
  ~publishableKey,
  ~profileId,
  ~paymentMethodId,
  ~pmSessionId,
  ~logger as _,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
    ("x-profile-id", `${profileId}`),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}`
  fetchApi(
    uri,
    ~method=#DELETE,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~bodyStr=[("payment_method_id", paymentMethodId->JSON.Encode.string)]
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

let updatePaymentMethod = (
  ~bodyArr,
  ~pmClientSecret,
  ~publishableKey,
  ~profileId,
  ~pmSessionId,
  ~logger as _,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
    ("x-profile-id", `${profileId}`),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
    ("Content-Type", "application/json"),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}/update-saved-payment-method`

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

let savePaymentMethod = (
  ~bodyArr,
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~profileId,
  ~logger as _,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
    ("x-profile-id", `${profileId}`),
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}/confirm`
  fetchApi(
    uri,
    ~method=#POST,
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

let useSaveCard = (optLogger: option<HyperLoggerTypes.loggerMake>, paymentType: payment) => {
  open RecoilAtoms
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
  ) => {
    switch keys.pmClientSecret {
    | Some(pmClientSecret) =>
      let pmSessionId = keys.pmSessionId->Option.getOr("")
      let headers = [
        ("Content-Type", "application/json"),
        (
          "Authorization",
          `publishable-key=${keys.publishableKey},client-secret=${config.pmClientSecret}`,
        ),
        ("x-profile-id", keys.profileId),
      ]
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}/confirm`

      let browserInfo = BrowserSpec.broswerInfo
      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let bodyStr =
        [("client_secret", pmClientSecret->JSON.Encode.string)]
        ->Array.concatMany([bodyArr, browserInfo(), returnUrlArr])
        ->getJsonFromArrayOfJson
        ->JSON.stringify

      let saveCard = () => {
        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr,
          ~confirmParam: ConfirmType.confirmParams,
          ~clientSecret=pmClientSecret,
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
    | None =>
      postFailedSubmitResponse(
        ~errortype="confirms_payment_failed",
        ~message="Payment failed. Try again!",
      )
    }
  }
}
