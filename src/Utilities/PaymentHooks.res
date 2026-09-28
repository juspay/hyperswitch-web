/*
 React hooks over the payment API in `PaymentHelpers`, in their own module so `PaymentHelpers`
 stays hook-free: the loader calls plain async functions from it, and when the hooks shared that
 file their `JotaiAtoms` references pulled the whole atoms module into the loader bundle.
 */
open Utils
open PaymentHelpersTypes
open LoggerUtils
open PaymentHelpers

let usePaymentSync = (optLogger: option<HyperLoggerTypes.loggerMake>, paymentType: payment) => {
  open JotaiAtoms
  let paymentMethodList = Jotai.useAtomValue(paymentMethodList)
  let keys = Jotai.useAtomValue(keys)
  let isCallbackUsedVal = Jotai.useAtomValue(JotaiAtoms.isCompleteCallbackUsed)
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let redirectionFlags = Jotai.useAtomValue(redirectionFlagsAtom)
  let setIsManualRetryEnabled = Jotai.useSetAtom(isManualRetryEnabled)
  (~handleUserError=false, ~confirmParam: ConfirmType.confirmParams, ~iframeId="") => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret,
        ~sdkAuthorization=keys.sdkAuthorization->Utils.getNonEmptyOption,
      )
      let headers = [("Content-Type", "application/json")]

      switch keys.sdkAuthorization->Utils.getNonEmptyOption {
      | Some(_) => ()
      | None => headers->Array.push(("api-key", confirmParam.publishableKey))
      }

      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)

      let clientSecretUriStr = switch keys.sdkAuthorization->Utils.getNonEmptyOption {
      | Some(_) => ""
      | None => `&client_secret=${clientSecret}`
      }

      let uri = `${endpoint}/payments/${paymentIntentId}?force_sync=true${clientSecretUriStr}`

      let paymentSync = () => {
        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr="",
          ~confirmParam: ConfirmType.confirmParams,
          ~clientSecret,
          ~optLogger,
          ~handleUserError,
          ~paymentType,
          ~iframeId,
          ~fetchMethod=#GET,
          ~setIsManualRetryEnabled,
          ~customPodUri,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~counter=0,
          ~isCallbackUsedVal,
          ~redirectionFlags,
          ~sdkAuthorization=keys.sdkAuthorization,
        )->ignore
      }
      switch paymentMethodList {
      | Loaded(_) => paymentSync()
      | _ => ()
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="sync_payment_failed",
        ~message="Sync Payment Failed. Try Again!",
      )
    }
  }
}

let maskStr = str => str->Js.String2.replaceByRe(%re(`/\S/g`), "x")

let rec maskPayload = payloadJson => {
  switch payloadJson->JSON.Classify.classify {
  | Object(valueDict) =>
    valueDict
    ->Dict.toArray
    ->Array.map(entry => {
      let (key, value) = entry
      (key, maskPayload(value))
    })
    ->getJsonFromArrayOfJson

  | Array(arr) => arr->Array.map(maskPayload)->JSON.Encode.array
  | String(valueStr) => valueStr->maskStr->JSON.Encode.string
  | Number(float) => Float.toString(float)->maskStr->JSON.Encode.string
  | Bool(bool) => bool->getStringFromBool->JSON.Encode.string
  | Null => JSON.Encode.string("null")
  }
}

let useCompleteAuthorizeHandler = () => {
  open JotaiAtoms

  let customPodUri = Jotai.useAtomValue(customPodUri)
  let setIsManualRetryEnabled = Jotai.useSetAtom(isManualRetryEnabled)
  let isCallbackUsedVal = Jotai.useAtomValue(isCompleteCallbackUsed)
  let redirectionFlags = Jotai.useAtomValue(redirectionFlagsAtom)
  let keys = Jotai.useAtomValue(keys)

  (
    ~clientSecret: option<string>,
    ~bodyArr,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId,
    ~optLogger,
    ~handleUserError,
    ~paymentType,
    ~sdkHandleOneClickConfirmPayment,
    ~headers: option<array<(string, string)>>=?,
    ~paymentMode: option<string>=?,
    ~sdkAuthorization: option<string>=?,
  ) =>
    switch clientSecret {
    | Some(cs) =>
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret=cs,
        ~sdkAuthorization,
      )
      let uri = `${endpoint}/payments/${paymentIntentId}/complete_authorize`

      let finalHeaders = switch headers {
      | Some(h) => h
      | None => [
          ("Content-Type", "application/json"),
          ("X-Client-Source", paymentMode->Option.getOr("")),
        ]
      }

      let sdkAuth = switch (
        keys.sdkAuthorization->Utils.getNonEmptyOption,
        sdkAuthorization->Utils.getNonEmptyOption,
      ) {
      | (Some(sdkAuth), _)
      | (_, Some(sdkAuth)) =>
        Some(sdkAuth)
      | _ => None
      }

      switch sdkAuth {
      | Some(auth) => finalHeaders->Array.push(("Authorization", auth))
      | None => finalHeaders->Array.push(("api-key", confirmParam.publishableKey))
      }

      let clientSecretArr = switch sdkAuth {
      | Some(_) => []
      | None => [("client_secret", cs->JSON.Encode.string)]
      }

      let bodyStr =
        clientSecretArr
        ->Array.concatMany([bodyArr, BrowserSpec.broswerInfo()])
        ->getJsonFromArrayOfJson
        ->JSON.stringify

      intentCall(
        ~fetchApi,
        ~uri,
        ~headers=finalHeaders,
        ~bodyStr,
        ~confirmParam,
        ~clientSecret=cs,
        ~optLogger,
        ~handleUserError,
        ~paymentType,
        ~iframeId,
        ~fetchMethod=#POST,
        ~setIsManualRetryEnabled,
        ~customPodUri,
        ~sdkHandleOneClickConfirmPayment,
        ~counter=0,
        ~isCallbackUsedVal,
        ~redirectionFlags,
        ~sdkAuthorization=sdkAuth,
      )->ignore
    | None =>
      postFailedSubmitResponse(
        ~errortype="complete_authorize_failed",
        ~message="Complete Authorize Failed. Try Again!",
      )
    }
}

let useCompleteAuthorize = (optLogger, paymentType) => {
  let completeAuthorizeHandler = useCompleteAuthorizeHandler()
  let keys = Jotai.useAtomValue(JotaiAtoms.keys)
  let paymentMethodList = Jotai.useAtomValue(JotaiAtoms.paymentMethodList)
  let url = RescriptReactRouter.useUrl()
  let mode =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")
    ->CardThemeType.getPaymentMode
    ->CardThemeType.getPaymentModeToStrMapper

  (~handleUserError=false, ~bodyArr, ~confirmParam, ~iframeId=keys.iframeId) =>
    switch paymentMethodList {
    | Loaded(_) =>
      completeAuthorizeHandler(
        ~clientSecret=keys.clientSecret,
        ~bodyArr,
        ~confirmParam,
        ~iframeId,
        ~optLogger,
        ~handleUserError,
        ~paymentType,
        ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
        ~paymentMode=mode,
        ~sdkAuthorization=?keys.sdkAuthorization->Utils.getNonEmptyOption,
      )
    | _ => ()
    }
}

let useRedsysCompleteAuthorize = optLogger => {
  let completeAuthorizeHandler = useCompleteAuthorizeHandler()
  (
    ~handleUserError=false,
    ~bodyArr,
    ~confirmParam,
    ~iframeId="redsys3ds",
    ~clientSecret,
    ~headers,
    ~sdkAuthorization,
  ) =>
    completeAuthorizeHandler(
      ~clientSecret,
      ~bodyArr,
      ~confirmParam,
      ~iframeId,
      ~optLogger,
      ~handleUserError,
      ~paymentType=Card,
      ~sdkHandleOneClickConfirmPayment=false,
      ~headers,
      ~sdkAuthorization,
    )
}

let usePaymentIntent = (optLogger, paymentType) => {
  open JotaiAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let paymentTypeFromUrl = componentName->CardThemeType.getPaymentMode
  let blockConfirm = Jotai.useAtomValue(isConfirmBlocked)
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let paymentMethodList = Jotai.useAtomValue(paymentMethodList)
  let keys = Jotai.useAtomValue(keys)
  let isCallbackUsedVal = Jotai.useAtomValue(JotaiAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Jotai.useAtomValue(redirectionFlagsAtom)

  let setIsManualRetryEnabled = Jotai.useSetAtom(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    ~intentCallback=_ => (),
    ~manualRetry=false,
    ~isTrustpayInterceptorConfirm=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret,
        ~sdkAuthorization=keys.sdkAuthorization->Utils.getNonEmptyOption,
      )
      let headers = {
        let baseHeaders = [
          ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
        ]
        switch keys.sdkAuthorization->Utils.getNonEmptyOption {
        | Some(sdkAuth) => baseHeaders->Array.push(("Authorization", sdkAuth))
        | _ => baseHeaders->Array.push(("api-key", confirmParam.publishableKey))
        }

        baseHeaders
      }

      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let manual_retry = manualRetry ? [("retry_action", "manual_retry"->JSON.Encode.string)] : []
      let clientSecretArr = switch keys.sdkAuthorization->Utils.getNonEmptyOption {
      | Some(_) => []
      | None => [("client_secret", clientSecret->JSON.Encode.string)]
      }
      let body = clientSecretArr->Array.concatMany([returnUrlArr, manual_retry])

      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let path = `payments/${paymentIntentId}/confirm`

      let uri = `${endpoint}/${path}`

      let callIntent = body => {
        let contentLength = body->String.length->Int.toString
        let maskedPayload =
          body->safeParseOpt->Option.getOr(JSON.Encode.null)->maskPayload->JSON.stringify
        let _loggerPayload =
          [
            ("payload", maskedPayload->JSON.Encode.string),
            (
              "headers",
              headers
              ->Array.map(header => {
                let (key, value) = header
                (key, value->JSON.Encode.string)
              })
              ->getJsonFromArrayOfJson,
            ),
          ]
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        switch paymentType {
        | Card =>
          handleLogging(
            ~optLogger,
            // ~internalMetadata=loggerPayload,
            ~value=contentLength,
            ~eventName=PAYMENT_ATTEMPT,
            ~paymentMethod="CARD",
          )
        | _ =>
          bodyArr->Array.forEach(((str, json)) => {
            if str === "payment_method_type" {
              handleLogging(
                ~optLogger,
                ~value=contentLength,
                // ~internalMetadata=loggerPayload,
                ~eventName=PAYMENT_ATTEMPT,
                ~paymentMethod=json->getStringFromJson(""),
              )
            }
            ()
          })
        }
        if blockConfirm && GlobalVars.isInteg {
          Console.warn2("CONFIRM IS BLOCKED - Body", body)
          Console.warn2(
            "CONFIRM IS BLOCKED - Headers",
            headers->Dict.fromArray->Identity.anyTypeToJson->JSON.stringify,
          )
        } else {
          intentCall(
            ~fetchApi,
            ~uri,
            ~headers,
            ~bodyStr=body,
            ~confirmParam: ConfirmType.confirmParams,
            ~clientSecret,
            ~optLogger,
            ~handleUserError,
            ~paymentType,
            ~iframeId,
            ~fetchMethod=#POST,
            ~setIsManualRetryEnabled,
            ~customPodUri,
            ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
            ~counter=0,
            ~isCallbackUsedVal,
            ~componentName,
            ~redirectionFlags,
            ~sdkAuthorization=keys.sdkAuthorization->Utils.getNonEmptyOption,
            ~isTrustpayInterceptorConfirm,
          )
          ->then(val => {
            intentCallback(val)
            resolve()
          })
          ->catch(_ => resolve())
          ->ignore
        }
      }

      let broswerInfo = BrowserSpec.broswerInfo
      let intentWithoutMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concatMany([
            bodyArr->Array.concat(broswerInfo()),
            mandatePaymentType->PaymentBody.paymentTypeBody,
          ])
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      let intentWithMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concat(
            bodyArr->Array.concatMany([PaymentBody.mandateBody(mandatePaymentType), broswerInfo()]),
          )
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      switch paymentMethodList {
      | LoadError(data)
      | Loaded(data) =>
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapperFromClientList
        let mandatePaymentType =
          paymentList.payment_type->PaymentMethodsRecord.paymentTypeToStringMapper
        if paymentList.payment_methods->Array.length > 0 {
          switch paymentList.mandate_payment {
          | Some(_) =>
            switch paymentType {
            | Card
            | Gpay
            | Applepay
            | KlarnaRedirect
            | Paypal
            | BankDebits =>
              intentWithMandate(mandatePaymentType)
            | _ => intentWithoutMandate(mandatePaymentType)
            }
          | None => intentWithoutMandate(mandatePaymentType)
          }
        } else {
          postFailedSubmitResponse(
            ~errortype="payment_methods_empty",
            ~message="Payment Failed. Try again!",
          )
          Console.warn("Please enable atleast one Payment method.")
        }

      | SemiLoaded => intentWithoutMandate("")
      | _ =>
        postFailedSubmitResponse(
          ~errortype="payment_methods_loading",
          ~message="Please wait. Try again!",
        )
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="confirm_payment_failed",
        ~message="Payment failed. Try again!",
      )
    }
  }
}

let usePostSessionTokens = (
  optLogger,
  paymentType: payment,
  paymentMethod: PaymentMethodCollectTypes.paymentMethod,
) => {
  open JotaiAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let paymentTypeFromUrl =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")->CardThemeType.getPaymentMode
  let customPodUri = Jotai.useAtomValue(customPodUri)
  let paymentMethodList = Jotai.useAtomValue(paymentMethodList)
  let keys = Jotai.useAtomValue(keys)
  let redirectionFlags = Jotai.useAtomValue(JotaiAtoms.redirectionFlagsAtom)

  let setIsManualRetryEnabled = Jotai.useSetAtom(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    ~intentCallback=_ => (),
    ~manualRetry as _=false,
    ~isTrustpayInterceptorConfirm as _=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentId = Utils.getPaymentIdOrExtractFromSdkAuth(
        ~clientSecret,
        ~sdkAuthorization=keys.sdkAuthorization->Utils.getNonEmptyOption,
      )

      let headers = [
        ("Content-Type", "application/json"),
        ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
      ]

      let body = [
        ("payment_id", paymentIntentId->JSON.Encode.string),
        ("payment_method_type", (paymentType :> string)->JSON.Encode.string),
        ("payment_method", (paymentMethod :> string)->JSON.Encode.string),
      ]

      switch keys.sdkAuthorization->Utils.getNonEmptyOption {
      | Some(sdkAuth) => headers->Array.push(("Authorization", sdkAuth))
      | _ => {
          headers->Array.push(("api-key", confirmParam.publishableKey))
          body->Array.push(("client_secret", clientSecret->JSON.Encode.string))
        }
      }

      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let uri = `${endpoint}/payments/${paymentIntentId}/post_session_tokens`

      let callIntent = body => {
        let contentLength = body->String.length->Int.toString
        let maskedPayload =
          body->safeParseOpt->Option.getOr(JSON.Encode.null)->maskPayload->JSON.stringify
        let _loggerPayload =
          [
            ("payload", maskedPayload->JSON.Encode.string),
            (
              "headers",
              headers
              ->Array.map(header => {
                let (key, value) = header
                (key, value->JSON.Encode.string)
              })
              ->getJsonFromArrayOfJson,
            ),
          ]
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        switch paymentType {
        | Card =>
          handleLogging(
            ~optLogger,
            // ~internalMetadata=loggerPayload,
            ~value=contentLength,
            ~eventName=PAYMENT_ATTEMPT,
            ~paymentMethod="CARD",
          )
        | _ =>
          bodyArr->Array.forEach(((str, json)) => {
            if str === "payment_method_type" {
              handleLogging(
                ~optLogger,
                ~value=contentLength,
                // ~internalMetadata=loggerPayload,
                ~eventName=PAYMENT_ATTEMPT,
                ~paymentMethod=json->getStringFromJson(""),
              )
            }
            ()
          })
        }

        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr=body,
          ~confirmParam: ConfirmType.confirmParams,
          ~clientSecret,
          ~optLogger,
          ~handleUserError,
          ~paymentType,
          ~iframeId,
          ~fetchMethod=#POST,
          ~setIsManualRetryEnabled,
          ~customPodUri,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~counter=0,
          ~redirectionFlags,
          ~sdkAuthorization=keys.sdkAuthorization,
        )
        ->then(val => {
          intentCallback(val)
          resolve()
        })
        ->catch(_ => Promise.resolve())
        ->ignore
      }

      let broswerInfo = BrowserSpec.broswerInfo
      let intentWithoutMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concatMany([
            bodyArr->Array.concat(broswerInfo()),
            mandatePaymentType->PaymentBody.paymentTypeBody,
          ])
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      let intentWithMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concat(
            bodyArr->Array.concatMany([PaymentBody.mandateBody(mandatePaymentType), broswerInfo()]),
          )
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      switch paymentMethodList {
      | LoadError(data)
      | Loaded(data) =>
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapperFromClientList
        let mandatePaymentType =
          paymentList.payment_type->PaymentMethodsRecord.paymentTypeToStringMapper
        if paymentList.payment_methods->Array.length > 0 {
          switch paymentList.mandate_payment {
          | Some(_) =>
            switch paymentType {
            | Card
            | Gpay
            | Applepay
            | KlarnaRedirect
            | Paypal
            | BankDebits =>
              intentWithMandate(mandatePaymentType)
            | _ => intentWithoutMandate(mandatePaymentType)
            }
          | None => intentWithoutMandate(mandatePaymentType)
          }
        } else {
          postFailedSubmitResponse(
            ~errortype="payment_methods_empty",
            ~message="Payment Failed. Try again!",
          )
          Console.warn("Please enable atleast one Payment method.")
        }
      | SemiLoaded => intentWithoutMandate("")
      | _ =>
        postFailedSubmitResponse(
          ~errortype="payment_methods_loading",
          ~message="Please wait. Try again!",
        )
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="post_session_tokens_failed",
        ~message="Post Session Tokens failed. Try again!",
      )
    }
  }
}
