open Utils
open RecoilAtoms

@react.component
let make = (
  ~selectedGiftCard,
  ~isDisabled=false,
  ~onGiftCardAdded=?,
  ~onRemainingAmountUpdate=?,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  // Get auth data from Recoil atoms
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)
  // Get applied gift cards from recoil
  let appliedGiftCards = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.appliedGiftCardsAtom)

  // Use Recoil atoms for gift card fields
  let (giftCardNumber, setGiftCardNumber) = Recoil.useRecoilState(userGiftCardNumber)
  let (giftCardCvc, setGiftCardCvc) = Recoil.useRecoilState(userGiftCardCvc)

  let (isSubmitting, setIsSubmitting) = React.useState(_ => false)
  let (_, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  // General error state for API and form-level errors
  let (generalError, setGeneralError) = React.useState(_ => "")

  // Combined check balance and apply payment method function using the new API
  let handleSubmit = _ => {
    // Clear any previous general errors
    setGeneralError(_ => "")

    // First validate gift card selection
    if selectedGiftCard === "" {
      setGeneralError(_ => localeString.selectPaymentMethodText)
      Utils.postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message=localeString.selectPaymentMethodText,
      )
    } else if giftCardNumber.value !== "" && giftCardCvc.value !== "" {
      setIsSubmitting(_ => true)

      let checkBalanceAndApply = () => {
        switch keys.clientSecret {
        | Some(clientSecret) => {
            let publishableKey = keys.publishableKey
            let profileId = keys.profileId
            let paymentId = keys.paymentId

            if clientSecret !== "" && publishableKey !== "" && paymentId !== "" {
              let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

              // Build payment methods array for all applied gift cards
              let appliedGiftCardPaymentMethods = appliedGiftCards->Array.map(card => {
                Dict.fromArray([
                  (
                    "gift_card",
                    Dict.fromArray([
                      (
                        card.giftCardType,
                        Dict.fromArray([
                          ("number", card.giftCardNumber->JSON.Encode.string),
                          ("cvc", card.cvc->JSON.Encode.string),
                        ])
                        ->Dict.toArray
                        ->getJsonFromArrayOfJson,
                      ),
                    ])
                    ->Dict.toArray
                    ->getJsonFromArrayOfJson,
                  ),
                ])
              })

              // Build payment method for the new gift card being added
              let newGiftCardData = Dict.fromArray([
                (
                  "gift_card",
                  Dict.fromArray([
                    (
                      selectedGiftCard,
                      Dict.fromArray([
                        ("number", giftCardNumber.value->JSON.Encode.string),
                        ("cvc", giftCardCvc.value->JSON.Encode.string),
                      ])
                      ->Dict.toArray
                      ->getJsonFromArrayOfJson,
                    ),
                  ])
                  ->Dict.toArray
                  ->getJsonFromArrayOfJson,
                ),
              ])

              // Concatenate applied gift cards with the new one
              let paymentMethods = Array.concat(appliedGiftCardPaymentMethods, [newGiftCardData])

              PaymentHelpersV2.checkBalanceAndApplyPaymentMethod(
                ~paymentMethods,
                ~clientSecret,
                ~publishableKey,
                ~customPodUri,
                ~endpoint,
                ~profileId,
                ~paymentId,
              )
              ->Promise.then(response => {
                setIsSubmitting(_ => false)

                if response !== JSON.Encode.null {
                  try {
                    let responseDict = response->Utils.getDictFromJson

                    // Parse balances array to get gift card info
                    switch responseDict->Dict.get("balances") {
                    | Some(balancesJson) =>
                      switch balancesJson->JSON.Decode.array {
                      | Some(balancesArray) if balancesArray->Array.length > 0 =>
                        // Iterate through all balance items
                        balancesArray->Array.forEach(balanceItem => {
                          let balanceDict = balanceItem->Utils.getDictFromJson
                          switch balanceDict->Dict.get("eligibility") {
                          | Some(eligibilityJson) =>
                            let eligibilityDict = eligibilityJson->Utils.getDictFromJson
                            switch eligibilityDict->Dict.get("success") {
                            | Some(successJson) =>
                              let successDict = successJson->Utils.getDictFromJson
                              let balance = successDict->Utils.getFloat("balance", 0.0)
                              let applicableAmount =
                                successDict->Utils.getFloat("applicable_amount", 0.0)
                              let currency = successDict->Utils.getString("currency", "USD")

                              // Create a new applied gift card object
                              let newGiftCard: RecoilAtomsV2.appliedGiftCard = {
                                giftCardType: selectedGiftCard,
                                giftCardNumber: giftCardNumber.value,
                                maskedNumber: `**** ${giftCardNumber.value->String.slice(
                                    ~start=-4,
                                    ~end=giftCardNumber.value->String.length,
                                  )}`,
                                balance: applicableAmount, // Use applicable amount rather than full balance
                                currency,
                                id: `${selectedGiftCard}_${Date.now()->Float.toString}`,
                                cvc: giftCardCvc.value,
                              }

                              // Add gift card to appliedGiftCards
                              switch onGiftCardAdded {
                              | Some(callback) => callback(newGiftCard)
                              | None => ()
                              }
                            | None =>
                              // Check for failure/error in eligibility
                              switch eligibilityDict->Dict.get("failure") {
                              | Some(_) =>
                                setGeneralError(_ => localeString.giftCardNumberInvalidText)
                              | None => setGeneralError(_ => localeString.enterValidDetailsText)
                              }
                            }
                          | None => setGeneralError(_ => localeString.enterValidDetailsText)
                          }
                        })

                        // Parse and update remaining amount (done after processing all balances)
                        let remainingAmount = responseDict->Utils.getFloat("remaining_amount", 0.0)
                        let responseCurrency = responseDict->Utils.getString("currency", "USD")

                        // Call parent callback to update remaining amount
                        switch onRemainingAmountUpdate {
                        | Some(callback) => callback(Some(remainingAmount), responseCurrency)
                        | None => ()
                        }

                        // Reset form
                        setGiftCardNumber(_ => {
                          value: "",
                          isValid: None,
                          errorString: "",
                        })
                        setGiftCardCvc(_ => {
                          value: "",
                          isValid: None,
                          errorString: "",
                        })
                      | _ => setGeneralError(_ => localeString.enterValidDetailsText)
                      }
                    | None => setGeneralError(_ => localeString.enterValidDetailsText)
                    }
                  } catch {
                  | _ => setGeneralError(_ => localeString.enterValidDetailsText)
                  }
                } else {
                  setGeneralError(_ => localeString.enterValidDetailsText)
                }
                Promise.resolve()
              })
              ->Promise.catch(_ => {
                setIsSubmitting(_ => false)
                setGeneralError(_ => localeString.enterValidDetailsText)
                Promise.resolve()
              })
              ->ignore
            } else {
              setIsSubmitting(_ => false)
              setGeneralError(_ => localeString.enterValidDetailsText)
            }
          }
        | None => {
            setIsSubmitting(_ => false)
            setGeneralError(_ => localeString.enterValidDetailsText)
          }
        }
      }

      checkBalanceAndApply()
    } else {
      setGeneralError(_ => localeString.enterFieldsText)
      Utils.postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message=localeString.enterFieldsText,
      )
    }
  }

  <div className="flex flex-col gap-4 w-full">
    // General error message display
    <RenderIf condition={generalError !== "" && !isDisabled}>
      <div
        className="w-full p-3 rounded-lg border"
        style={borderColor: "#ef4444", backgroundColor: "#fef2f2"}>
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 rounded-full bg-red-500 flex items-center justify-center">
            <span className="text-white text-xs"> {"!"->React.string} </span>
          </div>
          <span className="text-sm font-medium text-red-600"> {generalError->React.string} </span>
        </div>
      </div>
    </RenderIf>
    <RenderIf condition={selectedGiftCard !== ""}>
      <DynamicFields
        paymentMethod="gift_card" paymentMethodType={selectedGiftCard} setRequiredFieldsBody
      />
    </RenderIf>
    // Apply button
    <div className="flex justify-end w-full">
      <button
        className="px-6 py-3 text-sm font-medium text-white rounded-lg transition-opacity disabled:opacity-50 disabled:cursor-not-allowed w-full"
        style={backgroundColor: themeObj.colorPrimary}
        disabled={isSubmitting || isDisabled}
        onClick={handleSubmit}>
        {(isSubmitting ? "Applying..." : "Apply")->React.string}
      </button>
    </div>
  </div>
}
