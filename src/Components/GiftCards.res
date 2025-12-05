open RecoilAtoms
open Utils

@react.component
let make = () => {
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let paymentMethodsListV2 = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentMethodsListV2)
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)
  let (appliedGiftCards, setAppliedGiftCards) = Recoil.useRecoilState(
    RecoilAtomsV2.appliedGiftCardsAtom,
  )
  let (showGiftCardForm, setShowGiftCardForm) = React.useState(_ => false)
  let (selectedGiftCard, setSelectedGiftCard) = React.useState(_ => "")
  let (remainingAmount, setRemainingAmount) = Recoil.useRecoilState(
    RecoilAtomsV2.remainingAmountAtom,
  )
  let (remainingCurrency, setRemainingCurrency) = React.useState(_ => "")
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  // Get gift card options from PML V2
  let giftCardOptions = React.useMemo(() => {
    switch paymentMethodsListV2 {
    | LoadedV2(data) =>
      data.paymentMethodsEnabled
      ->Array.filter(method => method.paymentMethodType === "gift_card")
      ->Array.map(method => method.paymentMethodSubtype)
    | _ => []
    }
  }, [paymentMethodsListV2])

  let giftCardDropdownOptions = React.useMemo(() => {
    let baseOptions = giftCardOptions->Array.map(giftCardType => {
      let displayName = switch giftCardType {
      | "givex" => "Givex"
      | _ => giftCardType->String.toUpperCase
      }
      {
        DropdownField.value: giftCardType,
        label: displayName,
      }
    })

    // Add placeholder option at the beginning
    let placeholderLabel =
      appliedGiftCards->Array.length > 0 ? "Gift card limit reached (1 max)" : "Select gift card"

    Array.concat([{DropdownField.value: "", label: placeholderLabel}], baseOptions)
  }, (giftCardOptions, appliedGiftCards))

  // Callback to handle remaining amount updates from GiftCardForm
  let handleRemainingAmountUpdate = (amount: option<float>, currency: string) => {
    setRemainingAmount(_ => amount)
    setRemainingCurrency(_ => currency)
  }

  let handleToggleGiftCardForm = () => {
    setShowGiftCardForm(prev => !prev)
    if showGiftCardForm {
      setSelectedGiftCard(_ => "")
    }
  }

  let removeGiftCard = (giftCardId: string) => {
    let updatedCards = appliedGiftCards->Array.filter(card => card.id !== giftCardId)
    setAppliedGiftCards(_ => updatedCards)

    if updatedCards->Array.length === 0 {
      setRemainingAmount(_ => None)
      setRemainingCurrency(_ => "")
    } else {
      let clientSecret = keys.clientSecret->Option.getOr("")
      let publishableKey = keys.publishableKey
      let profileId = keys.profileId
      let paymentId = keys.paymentId

      let paymentMethods = updatedCards->Array.map(card => {
        let giftCardTuples = []->mergeAndFlattenToTuples(card.requiredFieldsBody)
        let data =
          giftCardTuples
          ->getJsonFromArrayOfJson
          ->getDictFromJson
          ->getDictFromDict("payment_method_data")
        data
      })

      PaymentHelpersV2.checkBalanceAndApplyPaymentMethod(
        ~paymentMethods,
        ~clientSecret,
        ~publishableKey,
        ~customPodUri,
        ~profileId,
        ~paymentId,
      )
      ->Promise.then(applyResponse => {
        let applyResponseDict = applyResponse->Utils.getDictFromJson
        let remainingAmount = applyResponseDict->Utils.getFloat("remaining_amount", 0.0)
        let currency = applyResponseDict->Utils.getString("currency", "USD")
        handleRemainingAmountUpdate(Some(remainingAmount), currency)
        Promise.resolve()
      })
      ->Promise.catch(_ => Promise.resolve())
      ->ignore
    }
  }

  let handleGiftCardAdded = (newGiftCard: RecoilAtomsV2.appliedGiftCard) => {
    setAppliedGiftCards(prevCards => Array.concat(prevCards, [newGiftCard]))
    setSelectedGiftCard(_ => "")
    setShowGiftCardForm(_ => false)
  }

  // Calculate gift cards summary
  let (_giftCardsCount, totalDiscount, currency) = React.useMemo(() => {
    let count = appliedGiftCards->Array.length
    let (total, curr) = appliedGiftCards->Array.reduce((0.0, "USD"), ((acc, _), card) => {
      (acc +. card.balance, card.currency)
    })
    (count, total, curr)
  }, [appliedGiftCards])

  React.useEffect(() => {
    switch remainingAmount {
    | Some(amount) =>
      Utils.messageParentWindow([
        (
          "remainingAmount",
          [
            ("currency", currency->JSON.Encode.string),
            ("amount", amount->Float.toString->JSON.Encode.string),
          ]->Utils.getJsonFromArrayOfJson,
        ),
      ])
    | None =>
      Utils.messageParentWindow([
        (
          "remainingAmount",
          [
            ("currency", "NA"->JSON.Encode.string),
            ("amount", "NA"->JSON.Encode.string),
          ]->Utils.getJsonFromArrayOfJson,
        ),
      ])
    }
    None
  }, [appliedGiftCards])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if isGiftCardOnlyPayment {
        let splitPaymentBodyArr = PaymentBodyV2.createSplitPaymentBodyForGiftCards(
          appliedGiftCards->Array.sliceToEnd(~start=1),
        )
        let primaryBody = PaymentBodyV2.createGiftCardBody(
          ~giftCardType=appliedGiftCards
          ->Array.get(0)
          ->Option.map(card => card.giftCardType)
          ->Option.getOr(""),
          ~requiredFieldsBody=appliedGiftCards
          ->Array.get(0)
          ->Option.map(card => card.requiredFieldsBody)
          ->Option.getOr(Dict.make()),
        )

        intent(
          ~bodyArr=primaryBody->Array.concat(splitPaymentBodyArr),
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~manualRetry=isManualRetryEnabled,
        )
      }
    }
  }, (appliedGiftCards, remainingAmount, isManualRetryEnabled))
  useSubmitPaymentData(submitCallback)

  <>
    <div
      className="w-full mb-4 border rounded-lg transition-colors"
      style={
        borderColor: themeObj.borderColor,
        backgroundColor: themeObj.colorBackground,
      }>
      <div
        className="flex flex-row items-center justify-between w-full p-3 px-4 cursor-pointer"
        onClick={_ => handleToggleGiftCardForm()}>
        <div className="flex flex-row items-center gap-2">
          <Icon size={16} name="gift-cards" />
          <span className="text-base font-medium" style={color: themeObj.colorText}>
            {localeString.haveGiftCardText->React.string}
          </span>
        </div>
        <span className="text-base font-small" style={color: themeObj.colorText}>
          {showGiftCardForm
            ? <Icon name="arrow-up" size={16} />
            : <Icon name="arrow-down" size={16} />}
        </span>
      </div>
      <RenderIf condition={showGiftCardForm}>
        <div className="flex flex-col gap-4 w-full p-4 pt-0">
          <div className="flex flex-col gap-2">
            <label className="text-sm font-medium" style={color: themeObj.colorText}>
              {"Select gift card"->React.string}
            </label>
            <RenderIf condition={giftCardOptions->Array.length > 0}>
              <DropdownField
                appearance=config.appearance
                fieldName=""
                value=selectedGiftCard
                setValue=setSelectedGiftCard
                disabled={appliedGiftCards->Array.length > 0}
                options=giftCardDropdownOptions
              />
            </RenderIf>
            <RenderIf condition={giftCardOptions->Array.length === 0}>
              <div className="p-3 text-center text-gray-500">
                {"No gift cards available"->React.string}
              </div>
            </RenderIf>
          </div>
          <RenderIf condition={appliedGiftCards->Array.length > 0}>
            <div className="p-3 rounded-lg" style={backgroundColor: "#f0f9ff"}>
              <div className="flex items-center gap-2 text-sm text-blue-700">
                <div className="w-4 h-4 rounded-full bg-blue-500 flex items-center justify-center">
                  <span className="text-white text-xs"> {"ℹ"->React.string} </span>
                </div>
                <span>
                  {`${appliedGiftCards
                    ->Array.length
                    ->Int.toString} gift card${appliedGiftCards->Array.length > 1
                      ? "s"
                      : ""} already applied.`->React.string}
                </span>
              </div>
            </div>
          </RenderIf>
          <GiftCardForm
            selectedGiftCard
            isDisabled={appliedGiftCards->Array.length > 0}
            onGiftCardAdded={handleGiftCardAdded}
            onRemainingAmountUpdate={handleRemainingAmountUpdate}
          />
        </div>
      </RenderIf>
    </div>
    // Applied gift cards section - displayed outside the main container
    <RenderIf condition={appliedGiftCards->Array.length > 0}>
      <div className="w-full mb-4">
        {appliedGiftCards
        ->Array.mapWithIndex((card, index) => {
          let displayName = card.giftCardType->String.toUpperCase ++ " Card"
          let maskedNumber = card.maskedNumber

          <div
            key={index->Int.toString}
            className="flex items-center justify-between p-4 mb-3 rounded-lg border"
            style={
              borderColor: themeObj.borderColor,
              backgroundColor: themeObj.colorBackground,
            }>
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 flex items-center justify-center">
                {switch card.giftCardType->String.toLowerCase {
                | "givex" => <Icon name="givex" size=16 width=20 />
                | _ => <Icon name="gift-cards" size=16 />
                }}
              </div>
              <div className="flex flex-col">
                <span className="text-sm font-medium" style={color: themeObj.colorText}>
                  {`${displayName} ${maskedNumber}`->React.string}
                </span>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <span className="text-sm font-medium text-[#008236]">
                {`${card.currency} ${card.balance->Float.toString} applied`->React.string}
              </span>
              <button
                className="w-5 h-5 flex items-center justify-center text-gray-400 hover:text-red-500 transition-colors"
                onClick={_ => removeGiftCard(card.id)}>
                <span className="text-sm font-bold"> {"×"->React.string} </span>
              </button>
            </div>
          </div>
        })
        ->React.array}
      </div>
    </RenderIf>
    // Summary display for gift card applications
    <RenderIf condition={appliedGiftCards->Array.length > 0}>
      <div
        className="w-full p-4 mb-4 rounded-lg"
        style={
          backgroundColor: "#EFF6FF",
          borderColor: themeObj.borderColor,
        }>
        {switch remainingAmount {
        | Some(amount) if amount == 0.0 =>
          <div className="text-sm" style={color: themeObj.colorText}>
            <span className="font-medium">
              {`Total ${remainingCurrency} ${totalDiscount->Float.toString} applied.`->React.string}
            </span>
            <span>
              {" No remaining amount to pay. Please proceed with payment."->React.string}
            </span>
          </div>
        | Some(amount) =>
          <div className="text-sm" style={color: themeObj.colorText}>
            <span className="font-medium">
              {`Total ${remainingCurrency} ${totalDiscount->Float.toString} applied.`->React.string}
            </span>
            <span>
              {` Pay remaining ${remainingCurrency} ${amount->Float.toString} with other payment method below.`->React.string}
            </span>
          </div>
        | None =>
          <div className="text-sm" style={color: themeObj.colorText}>
            <span className="font-medium">
              {`Total ${currency} ${totalDiscount->Float.toString} applied.`->React.string}
            </span>
          </div>
        }}
      </div>
    </RenderIf>
  </>
}
