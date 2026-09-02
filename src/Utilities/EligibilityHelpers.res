open Utils
open LoggerCommonHelpers

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

type eligibilityAmountDetails = {
  totalAmount: int,
  netAmount: int,
  currency: string,
}

type eligibleOffer = {
  offerQuoteId: string,
  offerAmount: int,
  currency: string,
  code: string,
  title: string,
  description: string,
}

type eligibilityOfferDetails = {
  offerQuoteIds: array<string>,
  eligibleOffers: array<eligibleOffer>,
  amountDetails: option<eligibilityAmountDetails>,
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

let parseEligibilityAmountDetails = dict =>
  dict
  ->getOptionalDict("amount_details")
  ->Option.map(amountDetailsDict => {
    totalAmount: getInt(amountDetailsDict, "total_amount", 0),
    netAmount: getInt(amountDetailsDict, "net_amount", 0),
    currency: amountDetailsDict->getString("currency", ""),
  })

let parseEligibilityOfferDetails = dict => {
  let amountDetails = dict->parseEligibilityAmountDetails
  dict
  ->getOptionalDict("offer_details")
  ->Option.flatMap(offerDetailsDict => {
    let offerQuoteIds =
      offerDetailsDict
      ->getStrArray("uplifted_offer_quote_ids")
      ->Array.filter(offerQuoteId => offerQuoteId !== "")
    let eligibleOffers =
      offerDetailsDict
      ->getArrayOfObjectsFromDict("eligible_offers")
      ->Array.map(offerDict => {
        offerQuoteId: offerDict->getString("offer_quote_id", ""),
        offerAmount: getInt(offerDict, "offer_amount", 0),
        currency: offerDict->getString("currency", ""),
        code: offerDict->getString("code", ""),
        title: offerDict->getString("title", ""),
        description: offerDict->getString("description", ""),
      })
      ->Array.filter(offer => offer.offerQuoteId !== "")

    eligibleOffers->Array.length > 0 ? Some({offerQuoteIds, eligibleOffers, amountDetails}) : None
  })
}

type eligibilityResponse = {
  eligibilityError: option<string>,
  surchargeDetails: option<eligibilitySurchargeDetails>,
  offerDetails: option<eligibilityOfferDetails>,
}

let parseEligibilityResponse = json => {
  let dict = json->getDictFromJson
  let eligibilityError = json->parseSdkNextActionError
  let surchargeDetails = dict->parseEligibilitySurchargeDetails
  let offerDetails = dict->parseEligibilityOfferDetails
  {eligibilityError, surchargeDetails, offerDetails}
}

let performEligibilityCheck = async (
  ~clientSecret: string,
  ~publishableKey: string,
  ~customPodUri,
  ~bodyArr,
  ~sdkAuthorization,
  ~endpoint,
  ~signal: Fetch.AbortSignal.t,
  ~setIsEligibilityPending: (bool => bool) => unit,
  ~setEligibilitySurchargeDetails: (
    option<eligibilitySurchargeDetails> => option<eligibilitySurchargeDetails>
  ) => unit,
  ~setEligibilityOfferDetails: (
    option<eligibilityOfferDetails> => option<eligibilityOfferDetails>
  ) => unit,
  ~setEligibilityError: option<(option<string> => option<string>) => unit>,
  ~errorLogMessage: string,
  ~fetchEligibility,
) => {
  setEligibilitySurchargeDetails(_ => None)
  setEligibilityOfferDetails(_ => None)
  setIsEligibilityPending(_ => true)
  try {
    let json = await fetchEligibility(
      ~clientSecret,
      ~publishableKey,
      ~customPodUri,
      ~bodyArr,
      ~sdkAuthorization,
      ~endpoint,
      ~signal,
    )
    let {eligibilityError, surchargeDetails, offerDetails} = parseEligibilityResponse(json)
    setEligibilityError->Option.forEach(setter => setter(_ => eligibilityError))
    setEligibilitySurchargeDetails(_ => surchargeDetails)
    setEligibilityOfferDetails(_ => offerDetails)
    setIsEligibilityPending(_ => false)
  } catch {
  | exn =>
    CorePaymentLogger.logLifecycle(
      ~event=PaymentFailed,
      ~message=errorLogMessage,
      ~details=[("error", exn->Identity.anyTypeToJson->JSON.stringify->JSON.Encode.string)],
    )
    setEligibilityError->Option.forEach(setter => setter(_ => None))
    setIsEligibilityPending(_ => false)
  }
}

let startEligibilityCheck = async (
  ~controllerRef: React.ref<option<Fetch.AbortController.t>>,
  ~clientSecret: option<string>,
  ~publishableKey,
  ~customPodUri,
  ~bodyArr,
  ~sdkAuthorization,
  ~endpoint,
  ~setIsEligibilityPending,
  ~setEligibilitySurchargeDetails,
  ~setEligibilityOfferDetails,
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
      ~customPodUri,
      ~bodyArr,
      ~sdkAuthorization,
      ~endpoint,
      ~signal,
      ~setIsEligibilityPending,
      ~setEligibilitySurchargeDetails,
      ~setEligibilityOfferDetails,
      ~setEligibilityError,
      ~errorLogMessage,
      ~fetchEligibility,
    )
  | None => setIsEligibilityPending(_ => false)
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
