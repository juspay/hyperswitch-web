open Utils

type surchargeType = {
  \"type": string,
  value: float,
}

type eligibilitySurchargeDetails = {
  surcharge: surchargeType,
  taxOnSurcharge: option<float>,
  displaySurchargeAmount: float,
  displayTaxOnSurchargeAmount: float,
  displayTotalSurchargeAmount: float,
}

let parseSdkNextActionError = json => {
  let dict = json->getDictFromJson
  let nextAction = dict->getDictFromDict("sdk_next_action")->Dict.get("next_action")
  switch nextAction {
  | Some(nextActionJson) =>
    switch nextActionJson->JSON.Classify.classify {
    | String(str) => str === "deny" ? Some("") : None
    | Object(nextActionDict) =>
      nextActionDict
      ->Dict.get("deny")
      ->Option.map(denyJson => denyJson->getDictFromJson->getString("message", ""))
    | _ => None
    }
  | None => None
  }
}

let parseEligibilitySurchargeDetails = dict => {
  dict
  ->Dict.get("surcharge_details")
  ->Option.flatMap(surchargeJson => {
    let surchargeDict = surchargeJson->getDictFromJson
    let surchargeInnerDict = surchargeDict->getDictFromDict("surcharge")
    let displayTotal = getFloat(surchargeDict, "display_total_surcharge_amount", 0.0)
    if displayTotal > 0.0 {
      Some({
        surcharge: {
          \"type": surchargeInnerDict->getString("type", ""),
          value: getFloat(surchargeInnerDict, "value", 0.0),
        },
        taxOnSurcharge: surchargeDict
        ->Dict.get("tax_on_surcharge")
        ->Option.flatMap(v =>
          switch v->JSON.Classify.classify {
          | Number(n) => Some(n)
          | _ => None
          }
        ),
        displaySurchargeAmount: getFloat(surchargeDict, "display_surcharge_amount", 0.0),
        displayTaxOnSurchargeAmount: getFloat(
          surchargeDict,
          "display_tax_on_surcharge_amount",
          0.0,
        ),
        displayTotalSurchargeAmount: displayTotal,
      })
    } else {
      None
    }
  })
}

type eligibilityResponse = {
  eligibilityError: option<string>,
  surchargeDetails: option<eligibilitySurchargeDetails>,
}

let parseEligibilityResponse = json => {
  let dict = json->getDictFromJson
  let eligibilityError = json->parseSdkNextActionError
  let surchargeDetails = dict->parseEligibilitySurchargeDetails
  {eligibilityError, surchargeDetails}
}

let performEligibilityCheck = async (
  ~clientSecret: string,
  ~publishableKey: string,
  ~logger: HyperLoggerTypes.loggerMake,
  ~customPodUri,
  ~bodyArr,
  ~sdkAuthorization,
  ~endpoint,
  ~signal: Fetch.AbortSignal.t,
  ~shouldBlockConfirm: bool,
  ~setIsEligibilityPending: (bool => bool) => unit,
  ~setEligibilitySurchargeDetails: (
    option<eligibilitySurchargeDetails> => option<eligibilitySurchargeDetails>
  ) => unit,
  ~setEligibilityError: option<(option<string> => option<string>) => unit>,
  ~errorLogMessage: string,
  ~fetchEligibility,
) => {
  setEligibilitySurchargeDetails(_ => None)
  if shouldBlockConfirm {
    setIsEligibilityPending(_ => true)
  }
  try {
    let json = await fetchEligibility(
      ~clientSecret,
      ~publishableKey,
      ~logger,
      ~customPodUri,
      ~bodyArr,
      ~sdkAuthorization,
      ~endpoint,
      ~signal,
    )
    let {eligibilityError, surchargeDetails} = parseEligibilityResponse(json)
    setEligibilityError->Option.forEach(setter => setter(_ => eligibilityError))
    setEligibilitySurchargeDetails(_ => surchargeDetails)
    setIsEligibilityPending(_ => false)
  } catch {
  | exn =>
    logger.setLogError(
      ~value={
        "message": errorLogMessage,
        "error": exn->Identity.anyTypeToJson->JSON.stringify,
      }
      ->JSON.stringifyAny
      ->Option.getOr(""),
      ~eventName=PAYMENT_METHOD_ELIGIBILITY_CALL,
    )
    setEligibilityError->Option.forEach(setter => setter(_ => None))
    setIsEligibilityPending(_ => false)
  }
}

let startEligibilityCheck = async (
  ~controllerRef: React.ref<option<Fetch.AbortController.t>>,
  ~clientSecret: option<string>,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~bodyArr,
  ~sdkAuthorization,
  ~endpoint,
  ~shouldBlockConfirm: bool,
  ~setIsEligibilityPending,
  ~setEligibilitySurchargeDetails,
  ~setEligibilityError,
  ~errorLogMessage: string,
  ~fetchEligibility,
) => {
  controllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
  let controller = Fetch.AbortController.make()
  controllerRef.current = Some(controller)
  let signal = Fetch.AbortController.signal(controller)

  switch clientSecret {
  | Some(clientSecret) =>
    await performEligibilityCheck(
      ~clientSecret,
      ~publishableKey,
      ~logger,
      ~customPodUri,
      ~bodyArr,
      ~sdkAuthorization,
      ~endpoint,
      ~signal,
      ~shouldBlockConfirm,
      ~setIsEligibilityPending,
      ~setEligibilitySurchargeDetails,
      ~setEligibilityError,
      ~errorLogMessage,
      ~fetchEligibility,
    )
  | None => ()
  }
}

let getCardEligibilityErrorText = (
  ~cardEligibilityError,
  ~localeString: LocaleStringTypes.localeStrings,
) => {
  switch cardEligibilityError {
  | Some("")
  | None =>
    localeString.cardNotEligibleText
  | Some(eligibilityErrorText) => eligibilityErrorText
  }
}
