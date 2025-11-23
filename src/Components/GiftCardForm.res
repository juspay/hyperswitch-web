open Utils
open RecoilAtoms

type giftCardRequirements = {
  hasCardNumber: bool,
  hasCVC: bool,
}

@react.component
let make = (
  ~selectedGiftCard,
  ~isDisabled=false,
  ~onApply,
  ~onGiftCardAdded=?,
  ~onRemainingAmountUpdate=?,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let paymentMethodListValueV2 = Recoil.useRecoilValueFromAtom(
    RecoilAtomsV2.paymentMethodListValueV2,
  )
  // Get auth data from Recoil atoms
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)
  // Get applied gift cards from recoil
  let appliedGiftCards = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.appliedGiftCardsAtom)

  // Local state for form fields using InputField pattern
  let (giftCardNumber, setGiftCardNumber) = React.useState(_ => "")
  let (giftCardPin, setGiftCardPin) = React.useState(_ => "")
  let (giftCardNumberValid, setGiftCardNumberValid) = React.useState(_ => None)
  let (giftCardPinValid, setGiftCardPinValid) = React.useState(_ => None)
  let (giftCardNumberError, setGiftCardNumberError) = React.useState(_ => "")
  let (giftCardPinError, setGiftCardPinError) = React.useState(_ => "")
  let (isSubmitting, setIsSubmitting) = React.useState(_ => false)
  let (giftCardNumberFocus, setGiftCardNumberFocus) = React.useState(_ => false)
  let (giftCardPinFocus, setGiftCardPinFocus) = React.useState(_ => false)

  // General error state for API and form-level errors
  let (generalError, setGeneralError) = React.useState(_ => "")

  // Refs for InputField components
  let giftCardNumberRef = React.useRef(Nullable.null)
  let giftCardPinRef = React.useRef(Nullable.null)

  // Get gift card requirements from payment method configuration
  let giftCardRequirements = React.useMemo(() => {
    let defaultRequirements = {hasCardNumber: true, hasCVC: false}

    switch selectedGiftCard {
    | "" => defaultRequirements
    | _ =>
      // Find the specific gift card configuration
      let giftCardMethod =
        paymentMethodListValueV2.paymentMethodsEnabled
        ->Array.filter(method =>
          method.paymentMethodType === "gift_card" &&
            method.paymentMethodSubtype === selectedGiftCard
        )
        ->Array.get(0)

      switch giftCardMethod {
      | Some(method) => {
          let hasCardNumber =
            method.requiredFields->Array.some(field => field.display_name === "gift_card_number")

          let hasCVC =
            method.requiredFields->Array.some(field => field.display_name === "gift_card_cvc")

          {hasCardNumber, hasCVC}
        }
      | None => defaultRequirements
      }
    }
  }, [selectedGiftCard])

  Js.log2("giftCardRequirements:", giftCardRequirements)

  // Validation functions
  let validateGiftCardNumber = () => {
    if giftCardRequirements.hasCardNumber && giftCardNumber === "" {
      setGiftCardNumberError(_ => "Gift card number is required")
      setGiftCardNumberValid(_ => Some(false))
      false
    } else {
      setGiftCardNumberError(_ => "")
      setGiftCardNumberValid(_ => Some(true))
      true
    }
  }

  let validateGiftCardPin = () => {
    if giftCardRequirements.hasCVC {
      if giftCardPin === "" {
        setGiftCardPinError(_ => "Gift card PIN is required")
        setGiftCardPinValid(_ => Some(false))
        false
      } else {
        setGiftCardPinError(_ => "")
        setGiftCardPinValid(_ => Some(true))
        true
      }
    } else {
      setGiftCardPinError(_ => "")
      setGiftCardPinValid(_ => Some(true))
      true
    }
  }

  // Combined check balance and apply payment method function using the new API
  let handleSubmit = () => {
    // Clear any previous general errors
    setGeneralError(_ => "")

    // First validate gift card selection
    if selectedGiftCard === "" {
      setGeneralError(_ => "Please select a gift card type")
      Utils.postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message="Please select a gift card type",
      )
    } else {
      let isNumberValid = validateGiftCardNumber()
      let isPinValid = validateGiftCardPin()

      // Check if all required fields are filled
      let allRequiredFieldsFilled =
        (giftCardRequirements.hasCardNumber || giftCardNumber !== "") &&
          (giftCardRequirements.hasCVC || giftCardPin !== "")
      if !allRequiredFieldsFilled {
        setGeneralError(_ => "Please fill in all required fields")
        Utils.postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message="Please fill in all required fields",
        )
      } else if isNumberValid && isPinValid {
        setIsSubmitting(_ => true)

        let checkBalanceAndApply = () => {
          switch keys.clientSecret {
          | Some(clientSecret) => {
              let publishableKey = keys.publishableKey
              let profileId = keys.profileId
              let paymentId = keys.paymentId

              if clientSecret !== "" && publishableKey !== "" && paymentId !== "" {
                let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

                // Build payment methods array for the new combined API
                let giftCardData = Dict.fromArray([
                  (
                    "gift_card",
                    Dict.fromArray([
                      (
                        selectedGiftCard,
                        Dict.fromArray([
                          ("number", giftCardNumber->JSON.Encode.string),
                          ("cvc", giftCardPin->JSON.Encode.string),
                        ])
                        ->Dict.toArray
                        ->getJsonFromArrayOfJson,
                      ),
                    ])
                    ->Dict.toArray
                    ->getJsonFromArrayOfJson,
                  ),
                ])

                let paymentMethods = [giftCardData]

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
                          switch balancesArray->Array.get(0) {
                          | Some(balanceItem) =>
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
                                  giftCardNumber,
                                  maskedNumber: `**** ${giftCardNumber->String.slice(
                                      ~start=-4,
                                      ~end=giftCardNumber->String.length,
                                    )}`,
                                  balance: applicableAmount, // Use applicable amount rather than full balance
                                  currency,
                                  id: `${selectedGiftCard}_${giftCardNumber}_${Date.now()->Float.toString}`,
                                  cvc: giftCardPin,
                                }

                                // Add gift card to appliedGiftCards
                                switch onGiftCardAdded {
                                | Some(callback) => callback(newGiftCard)
                                | None =>
                                  Console.log2("Gift card applied successfully:", newGiftCard)
                                }

                                // Parse and update remaining amount
                                let remainingAmount =
                                  responseDict->Utils.getFloat("remaining_amount", 0.0)
                                let responseCurrency =
                                  responseDict->Utils.getString("currency", "USD")

                                // Call parent callback to update remaining amount
                                switch onRemainingAmountUpdate {
                                | Some(callback) =>
                                  callback(Some(remainingAmount), responseCurrency)
                                | None => ()
                                }

                                // Create form data object for onApply callback
                                let formData =
                                  [
                                    ("status", "success"->JSON.Encode.string),
                                  ]->getJsonFromArrayOfJson

                                // Call the onApply callback (this will close the form)
                                onApply(formData)

                                // Reset form
                                setGiftCardNumber(_ => "")
                                setGiftCardPin(_ => "")
                              | None =>
                                // Check for failure/error in eligibility
                                switch eligibilityDict->Dict.get("failure") {
                                | Some(failureJson) =>
                                  let failureDict = failureJson->Utils.getDictFromJson
                                  let reason =
                                    failureDict->Utils.getString(
                                      "reason",
                                      "Gift card is invalid or has insufficient balance",
                                    )
                                  setGeneralError(_ => reason)
                                | None =>
                                  setGeneralError(_ =>
                                    "Gift card validation failed. Please check your details."
                                  )
                                }
                              }
                            | None =>
                              setGeneralError(_ => "Gift card information could not be validated")
                            }
                          | None =>
                            setGeneralError(_ => "Gift card information could not be validated")
                          }
                        | _ => setGeneralError(_ => "No gift card information found")
                        }
                      | None => setGeneralError(_ => "Gift card validation failed")
                      }
                    } catch {
                    | _ => setGeneralError(_ => "An error occurred while processing your gift card")
                    }
                  } else {
                    setGeneralError(_ => "Gift card validation failed. Please try again.")
                  }
                  Promise.resolve()
                })
                ->Promise.catch(_ => {
                  setIsSubmitting(_ => false)
                  Console.log("Error in combined gift card API call")
                  Promise.resolve()
                })
                ->ignore
              } else {
                setIsSubmitting(_ => false)
                Console.log("Authentication data incomplete")
              }
            }
          | None => {
              setIsSubmitting(_ => false)
              Console.log("Client secret not available")
            }
          }
        }

        checkBalanceAndApply()
      } else {
        Console.log("Please fill in all required fields")
      }
    }
  }

  // Handle input changes
  let handleCardNumberChange = ev => {
    let value = ReactEvent.Form.target(ev)["value"]
    setGiftCardNumber(_ => value)
    setGiftCardNumberValid(_ => None)
    if giftCardNumberError !== "" {
      setGiftCardNumberError(_ => "")
    }
  }

  let handlePinChange = ev => {
    let value = ReactEvent.Form.target(ev)["value"]
    setGiftCardPin(_ => value)
    setGiftCardPinValid(_ => None)
    if giftCardPinError !== "" {
      setGiftCardPinError(_ => "")
    }
  }

  // Handle blur events
  let handleCardNumberBlur = _ => {
    setGiftCardNumberFocus(_ => false)
    validateGiftCardNumber()->ignore
  }

  let handlePinBlur = _ => {
    setGiftCardPinFocus(_ => false)
    validateGiftCardPin()->ignore
  }

  // Handle focus events
  let handleCardNumberFocus = (isFocused: bool) => {
    setGiftCardNumberFocus(_ => isFocused)
  }

  let handlePinFocus = (isFocused: bool) => {
    setGiftCardPinFocus(_ => isFocused)
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
    // Gift Card Number - Full width
    <RenderIf condition={selectedGiftCard !== ""}>
      <div className="flex flex-col gap-2 w-full">
        <InputField
          isValid={giftCardNumberValid}
          setIsValid={setGiftCardNumberValid}
          value={giftCardNumber}
          onChange={isDisabled ? _ => () : handleCardNumberChange}
          onBlur={isDisabled ? _ => () : handleCardNumberBlur}
          onFocus={isDisabled ? _ => () : handleCardNumberFocus}
          fieldName={giftCardRequirements.hasCardNumber ? "Gift Card Number*" : "Gift Card Number"}
          type_="text"
          placeholder={isDisabled ? "Gift card limit reached" : "1234 1234 1234 1234"}
          className={`w-full p-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${isDisabled
              ? "opacity-50 cursor-not-allowed bg-gray-100"
              : ""}`}
          inputRef={giftCardNumberRef}
          isFocus={giftCardNumberFocus && !isDisabled}
          errorString=?{giftCardNumberError !== "" && !isDisabled
            ? Some(giftCardNumberError)
            : None}
          errorStringClasses="text-sm text-red-500"
          maxLength={32}
          labelClassName="text-sm font-medium"
        />
      </div>
      // Gift Card PIN
      <div className="flex flex-col gap-2 w-full">
        <InputField
          isValid={giftCardPinValid}
          setIsValid={setGiftCardPinValid}
          value={giftCardPin}
          onChange={isDisabled ? _ => () : handlePinChange}
          onBlur={isDisabled ? _ => () : handlePinBlur}
          onFocus={isDisabled ? _ => () : handlePinFocus}
          fieldName={giftCardRequirements.hasCVC ? "Gift Card PIN*" : "Gift Card PIN"}
          type_="text"
          placeholder={isDisabled ? "Gift card limit reached" : "123456"}
          className={`w-full p-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 ${isDisabled
              ? "opacity-50 cursor-not-allowed bg-gray-100"
              : ""}`}
          inputRef={giftCardPinRef}
          isFocus={giftCardPinFocus && !isDisabled}
          errorString=?{giftCardPinError !== "" && !isDisabled ? Some(giftCardPinError) : None}
          errorStringClasses="text-sm text-red-500"
          maxLength={10}
          labelClassName="text-sm font-medium"
        />
      </div>
    </RenderIf>
    // Apply button
    <div className="flex justify-end w-full">
      <button
        className="px-6 py-3 text-sm font-medium text-white rounded-lg transition-opacity disabled:opacity-50 disabled:cursor-not-allowed w-full"
        style={backgroundColor: themeObj.colorPrimary}
        disabled={isSubmitting}
        onClick={_ => handleSubmit()}>
        {(isSubmitting ? "Applying..." : "Apply")->React.string}
      </button>
    </div>
  </div>
}
