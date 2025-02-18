open Utils

let fetchPaymentManagementList = (
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~endpoint,
  ~optLogger,
  ~customPodUri,
) => {
  open Promise
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}/list-payment-methods`
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    Console.log2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let deletePaymentMethodV2 = (
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~paymentMethodId,
  ~logger,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/payment_methods/${paymentMethodId}`
  fetchApi(uri, ~method=#DELETE, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    Console.log2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let updatePaymentMethod = (
  ~bodyArr,
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~paymentMethodId,
  ~logger,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${paymentMethodId}/update-saved-payment-method`

  fetchApi(
    uri,
    ~method=#PUT,
    ~bodyStr=bodyArr->getJsonFromArrayOfJson->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    Console.log2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let savePaymentMethod = (
  ~bodyArr,
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  // ~paymentMethodId,
  ~logger,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
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
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
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
    Console.log2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}
