open RecoilAtoms

@react.component
let make = (~selectedGiftCard, ~isDisabled=false, ~onGiftCardAdded, ~onRemainingAmountUpdate) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)
  let giftCardInfo = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.giftCardInfoAtom)
  let appliedGiftCards = giftCardInfo.appliedGiftCards
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let (giftCardNumber, setGiftCardNumber) = Recoil.useRecoilState(userGiftCardNumber)
  let (_, setGiftCardPin) = Recoil.useRecoilState(userGiftCardPin)

  let (isSubmitting, setIsSubmitting) = React.useState(_ => false)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(
    RecoilAtomsV2.areRequiredFieldsValidSplit,
  )
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(
    RecoilAtomsV2.areRequiredFieldsEmptySplit,
  )

  let (generalError, setGeneralError) = React.useState(_ => "")

  let handleSubmit = async _ => {
    setGeneralError(_ => "")
    if selectedGiftCard === "" {
      setGeneralError(_ => localeString.selectPaymentMethodText)
      Utils.postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message=localeString.selectPaymentMethodText,
      )
    } else if areRequiredFieldsValid && !areRequiredFieldsEmpty {
      setIsSubmitting(_ => true)
      let {clientSecret, publishableKey, profileId, paymentId} = keys
      let clientSecretVal = clientSecret->Option.getOr("")

      let appliedGiftCardPaymentMethods = appliedGiftCards->Array.map(card => {
        PaymentUtils.getGiftCardDataFromRequiredFieldsBody(card.requiredFieldsBody)
      })

      let newGiftCardData = PaymentUtils.getGiftCardDataFromRequiredFieldsBody(requiredFieldsBody)

      let paymentMethods = Array.concat(appliedGiftCardPaymentMethods, [newGiftCardData])

      try {
        let response = await PaymentHelpersV2.checkBalanceAndApplyPaymentMethod(
          ~paymentMethods,
          ~clientSecret=clientSecretVal,
          ~publishableKey,
          ~customPodUri,
          ~profileId,
          ~paymentId,
          ~logger=loggerState,
        )

        setIsSubmitting(_ => false)

        let responseDict = response->Utils.getDictFromJson

        let balancesJson = responseDict->Dict.get("balances")

        if balancesJson->Option.isNone {
          setGeneralError(_ => localeString.enterValidDetailsText)
        } else {
          let balancesArray = balancesJson->Option.flatMap(JSON.Decode.array)

          if balancesArray->Option.isNone {
            setGeneralError(_ => localeString.enterValidDetailsText)
          } else {
            balancesArray
            ->Option.getOr([])
            ->Array.forEach(balanceItem => {
              let balanceDict = balanceItem->Utils.getDictFromJson
              let eligibilityJson = balanceDict->Dict.get("eligibility")

              if eligibilityJson->Option.isNone {
                setGeneralError(_ => localeString.enterValidDetailsText)
              } else {
                let eligibilityDict = eligibilityJson->Option.getUnsafe->Utils.getDictFromJson
                let successJson = eligibilityDict->Dict.get("success")

                switch successJson {
                | Some(successJson) =>
                  let successDict = successJson->Utils.getDictFromJson
                  let applicableAmount = successDict->Utils.getFloat("applicable_amount", 0.0)
                  let currency = successDict->Utils.getString("currency", "")

                  let newGiftCard: GiftCardTypes.appliedGiftCard = {
                    giftCardType: selectedGiftCard,
                    maskedNumber: `**** ${giftCardNumber.value->String.slice(
                        ~start=-4,
                        ~end=giftCardNumber.value->String.length,
                      )}`,
                    balance: applicableAmount,
                    currency,
                    id: `${selectedGiftCard}_${Date.now()->Float.toString}`,
                    requiredFieldsBody,
                  }

                  onGiftCardAdded(newGiftCard)
                | None =>
                  switch eligibilityDict->Dict.get("failure") {
                  | Some(_) => setGeneralError(_ => localeString.giftCardNumberInvalidText)
                  | None => setGeneralError(_ => localeString.enterValidDetailsText)
                  }
                }
              }
            })

            let remainingAmount = responseDict->Utils.getFloat("remaining_amount", 0.0)
            let responseCurrency = responseDict->Utils.getString("currency", "")

            onRemainingAmountUpdate(remainingAmount, responseCurrency)

            setGiftCardNumber(_ => RecoilAtoms.defaultFieldValues)
            setGiftCardPin(_ => RecoilAtoms.defaultFieldValues)
          }
        }
      } catch {
      | _ =>
        setIsSubmitting(_ => false)
        setGeneralError(_ => localeString.enterValidDetailsText)
      }
    } else {
      setGeneralError(_ => localeString.enterFieldsText)
      Utils.postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message=localeString.enterFieldsText,
      )
    }
  }
  <div className="flex flex-col gap-4 w-full">
    <RenderIf condition={appliedGiftCards->Array.length < 1}>
      <DynamicFields
        paymentMethod="gift_card"
        paymentMethodType={selectedGiftCard}
        setRequiredFieldsBody
        disableInfoElement=true
        splitAtomsEnabled=true
      />
    </RenderIf>
    <div className="flex flex-col justify-end w-full">
      <button
        className={`w-full flex flex-row justify-center items-center`}
        style={
          borderRadius: themeObj.buttonBorderRadius,
          backgroundColor: themeObj.buttonBackgroundColor,
          height: themeObj.buttonHeight,
          cursor: {isSubmitting || isDisabled ? "not-allowed" : "pointer"},
          opacity: {isSubmitting || isDisabled ? "0.6" : "1"},
          width: themeObj.buttonWidth,
          border: `${themeObj.buttonBorderWidth} solid ${themeObj.buttonBorderColor}`,
        }
        disabled={isSubmitting || isDisabled}
        onClick={e => {
          handleSubmit(e)->ignore
        }}>
        <span
          style={
            color: themeObj.buttonTextColor,
            fontSize: themeObj.buttonTextFontSize,
            fontWeight: themeObj.buttonTextFontWeight,
          }>
          {(isSubmitting ? "Applying..." : "Apply")->React.string}
        </span>
      </button>
      <RenderIf condition={generalError !== "" && !isDisabled}>
        <div style={{color: themeObj.colorDanger}} className="text-sm font-medium mt-1">
          {generalError->React.string}
        </div>
      </RenderIf>
    </div>
  </div>
}
