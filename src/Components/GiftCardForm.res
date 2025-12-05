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
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)
  let appliedGiftCards = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.appliedGiftCardsAtom)

  let (giftCardNumber, setGiftCardNumber) = Recoil.useRecoilState(userGiftCardNumber)
  let (_, setGiftCardCvc) = Recoil.useRecoilState(userGiftCardCvc)

  let (isSubmitting, setIsSubmitting) = React.useState(_ => false)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (areRequiredFieldsValid, setAreRequiredFieldsValid) = React.useState(_ => true)
  let (areRequiredFieldsEmpty, setAreRequiredFieldsEmpty) = React.useState(_ => false)

  let (generalError, setGeneralError) = React.useState(_ => "")

  let handleSubmit = _ => {
    setGeneralError(_ => "")

    if selectedGiftCard === "" {
      setGeneralError(_ => localeString.selectPaymentMethodText)
      Utils.postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message=localeString.selectPaymentMethodText,
      )
    } else if areRequiredFieldsValid && !areRequiredFieldsEmpty {
      setIsSubmitting(_ => true)
      let clientSecret = keys.clientSecret->Option.getOr("")
      let publishableKey = keys.publishableKey
      let profileId = keys.profileId
      let paymentId = keys.paymentId

      let appliedGiftCardPaymentMethods = appliedGiftCards->Array.map(card => {
        let giftCardTuples = []->mergeAndFlattenToTuples(card.requiredFieldsBody)
        let data =
          giftCardTuples
          ->getJsonFromArrayOfJson
          ->getDictFromJson
          ->getDictFromDict("payment_method_data")
        data
      })

      let newGiftCardTuples = []->mergeAndFlattenToTuples(requiredFieldsBody)
      let newGiftCardData =
        newGiftCardTuples
        ->getJsonFromArrayOfJson
        ->getDictFromJson
        ->getDictFromDict("payment_method_data")

      let paymentMethods = Array.concat(appliedGiftCardPaymentMethods, [newGiftCardData])

      PaymentHelpersV2.checkBalanceAndApplyPaymentMethod(
        ~paymentMethods,
        ~clientSecret,
        ~publishableKey,
        ~customPodUri,
        ~profileId,
        ~paymentId,
      )
      ->Promise.then(response => {
        setIsSubmitting(_ => false)

        let responseDict = response->Utils.getDictFromJson

        switch responseDict->Dict.get("balances") {
        | Some(balancesJson) =>
          switch balancesJson->JSON.Decode.array {
          | Some(balancesArray) if balancesArray->Array.length > 0 =>
            balancesArray->Array.forEach(balanceItem => {
              let balanceDict = balanceItem->Utils.getDictFromJson
              switch balanceDict->Dict.get("eligibility") {
              | Some(eligibilityJson) =>
                let eligibilityDict = eligibilityJson->Utils.getDictFromJson
                switch eligibilityDict->Dict.get("success") {
                | Some(successJson) =>
                  let successDict = successJson->Utils.getDictFromJson
                  let applicableAmount = successDict->Utils.getFloat("applicable_amount", 0.0)
                  let currency = successDict->Utils.getString("currency", "USD")

                  let newGiftCard: RecoilAtomsV2.appliedGiftCard = {
                    giftCardType: selectedGiftCard,
                    maskedNumber: `**** ${giftCardNumber.value->String.slice(
                        ~start=-4,
                        ~end=giftCardNumber.value->String.length,
                      )}`,
                    balance: applicableAmount, // Use applicable amount rather than full balance
                    currency,
                    id: `${selectedGiftCard}_${Date.now()->Float.toString}`,
                    requiredFieldsBody,
                  }

                  switch onGiftCardAdded {
                  | Some(callback) => callback(newGiftCard)
                  | None => ()
                  }
                | None =>
                  switch eligibilityDict->Dict.get("failure") {
                  | Some(_) => setGeneralError(_ => localeString.giftCardNumberInvalidText)
                  | None => setGeneralError(_ => localeString.enterValidDetailsText)
                  }
                }
              | None => setGeneralError(_ => localeString.enterValidDetailsText)
              }
            })

            let remainingAmount = responseDict->Utils.getFloat("remaining_amount", 0.0)
            let responseCurrency = responseDict->Utils.getString("currency", "USD")

            switch onRemainingAmountUpdate {
            | Some(callback) => callback(Some(remainingAmount), responseCurrency)
            | None => ()
            }

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

        Promise.resolve()
      })
      ->Promise.catch(_ => {
        setIsSubmitting(_ => false)
        setGeneralError(_ => localeString.enterValidDetailsText)
        Promise.resolve()
      })
      ->ignore
    } else {
      setGeneralError(_ => localeString.enterFieldsText)
      Utils.postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message=localeString.enterFieldsText,
      )
    }
  }

  <div className="flex flex-col gap-4 w-full">
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
        paymentMethod="gift_card"
        paymentMethodType={selectedGiftCard}
        setRequiredFieldsBody
        setAreRequiredFieldsValid
        setAreRequiredFieldsEmpty
        disableInfoElement=true
      />
    </RenderIf>
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
