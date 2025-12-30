open RecoilAtoms
open Utils

@react.component
let make = (~giftCardOptions) => {
  let {themeObj, localeString, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)
  let (giftCardInfo, setGiftCardInfo) = Recoil.useRecoilState(RecoilAtomsV2.giftCardInfoAtom)
  let appliedGiftCards = giftCardInfo.appliedGiftCards
  let remainingAmount = giftCardInfo.remainingAmount
  let (showGiftCardForm, setShowGiftCardForm) = React.useState(_ => false)
  let (selectedGiftCard, setSelectedGiftCard) = React.useState(_ => "")
  let (remainingCurrency, setRemainingCurrency) = React.useState(_ => "")
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let isGiftCardOnlyPayment = GiftCardHooks.useIsGiftCardOnlyPayment()

  let giftCardOptionsAvailable = giftCardOptions->Array.length > 0
  let hasAppliedGiftCards = appliedGiftCards->Array.length > 0

  let giftCardDropdownOptions = React.useMemo(() => {
    let baseOptions = giftCardOptions->Array.map(giftCardType => {
      let displayName = giftCardType->Utils.snakeToTitleCase
      {
        DropdownField.value: giftCardType,
        label: displayName,
      }
    })
    baseOptions
  }, [giftCardOptions])

  let handleRemainingAmountUpdate = (amount, currency) => {
    setGiftCardInfo(prev => {...prev, remainingAmount: amount})
    setRemainingCurrency(_ => currency)
  }

  let handleToggleGiftCardForm = () => {
    setShowGiftCardForm(prev => !prev)
    if showGiftCardForm {
      setSelectedGiftCard(_ => "")
    }
  }

  let removeGiftCard = async giftCardId => {
    let updatedCards = appliedGiftCards->Array.filter(card => card.id !== giftCardId)
    setGiftCardInfo(prev => {...prev, appliedGiftCards: updatedCards})

    if updatedCards->Array.length === 0 {
      setGiftCardInfo(prev => {...prev, remainingAmount: 0.0})
      setRemainingCurrency(_ => "")
    } else {
      let {clientSecret, publishableKey, profileId, paymentId} = keys

      let paymentMethods = updatedCards->Array.map(card => {
        DynamicFieldsUtils.getGiftCardDataFromRequiredFieldsBody(card.requiredFieldsBody)
      })

      try {
        let applyResponse = await PaymentHelpersV2.checkBalanceAndApplyPaymentMethod(
          ~paymentMethods,
          ~clientSecret,
          ~publishableKey,
          ~customPodUri,
          ~profileId,
          ~paymentId,
          ~logger=loggerState,
        )
        let applyResponseDict = applyResponse->Utils.getDictFromJson
        let remainingAmount = applyResponseDict->Utils.getFloat("remaining_amount", 0.0)
        let currency = applyResponseDict->Utils.getString("currency", "")
        handleRemainingAmountUpdate(remainingAmount, currency)
      } catch {
      | _ => ()
      }
    }
  }

  let handleGiftCardAdded = newGiftCard => {
    setGiftCardInfo(prev => {
      ...prev,
      appliedGiftCards: Array.concat(prev.appliedGiftCards, [newGiftCard]),
    })
    setSelectedGiftCard(_ => "")
    setShowGiftCardForm(_ => false)
  }

  let totalDiscount = React.useMemo(() => {
    let total = appliedGiftCards->Array.reduce(0.0, (acc, card) => {
      acc +. card.balance
    })
    total
  }, [appliedGiftCards])

  let appliedCardsCount = appliedGiftCards->Array.length->Int.toString
  let appliedCardsMessage = `${appliedCardsCount} gift card already applied.`

  let giftCardDiscountMessage = `Total ${remainingCurrency} ${totalDiscount->Float.toString} applied.`

  let giftCardPaymentInfoMessage =
    remainingAmount === 0.0
      ? " No remaining amount to pay. Please proceed with payment."
      : ` Pay remaining ${remainingCurrency} ${remainingAmount->Float.toString} with other payment method below.`

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit && isGiftCardOnlyPayment {
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
        ~bodyArr={
          primaryBody->Array.concat(splitPaymentBodyArr)
        },
        ~confirmParam=confirm.confirmParams,
        ~handleUserError=false,
        ~manualRetry=isManualRetryEnabled,
      )
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
          <span className="text-base font-small" style={color: themeObj.colorText}>
            <Icon size={16} name="gift-cards" />
          </span>
          <span className="text-base font-medium" style={color: themeObj.colorText}>
            {localeString.giftCardSectionTitle->React.string}
          </span>
        </div>
        <span className="text-base font-small" style={color: themeObj.colorText}>
          {showGiftCardForm
            ? <Icon name="arrow-up" size={14} />
            : <Icon name="arrow-down" size={14} />}
        </span>
      </div>
      <RenderIf condition={showGiftCardForm}>
        <div className="flex flex-col gap-4 w-full p-4 pt-0">
          <div className="flex flex-col gap-2">
            <RenderIf condition={giftCardOptionsAvailable}>
              <DropdownField
                appearance=config.appearance
                fieldName="Select gift card"
                value=selectedGiftCard
                setValue=setSelectedGiftCard
                disabled={hasAppliedGiftCards}
                options=giftCardDropdownOptions
              />
            </RenderIf>
            <RenderIf condition={!giftCardOptionsAvailable}>
              <div className="p-3 text-center text-gray-500">
                {"No gift cards available"->React.string}
              </div>
            </RenderIf>
          </div>
          <RenderIf condition={hasAppliedGiftCards}>
            <div className="p-3 rounded-lg bg-blue-50">
              <div className="flex items-center gap-2 text-sm text-blue-700">
                <div className="w-4 h-4 rounded-full bg-blue-500 flex items-center justify-center">
                  <span className="text-white text-xs"> {"!"->React.string} </span>
                </div>
                <span> {appliedCardsMessage->React.string} </span>
              </div>
            </div>
          </RenderIf>
          <GiftCardForm
            selectedGiftCard
            isDisabled={hasAppliedGiftCards}
            onGiftCardAdded={handleGiftCardAdded}
            onRemainingAmountUpdate={handleRemainingAmountUpdate}
          />
        </div>
      </RenderIf>
    </div>
    <RenderIf condition={hasAppliedGiftCards}>
      <div className="w-full mb-4">
        {appliedGiftCards
        ->Array.mapWithIndex((card, index) => {
          let displayName = `${card.giftCardType->String.toUpperCase} Card ${card.maskedNumber}`
          let balanceText = `${card.currency} ${card.balance->Float.toString} applied`
          let id = card.id
          <GiftCardsListItem
            key={index->Int.toString}
            displayName
            balanceText
            giftCardType=card.giftCardType
            removeGiftCard
            id
          />
        })
        ->React.array}
      </div>
    </RenderIf>
    <RenderIf condition={hasAppliedGiftCards}>
      <GiftCardSummary giftCardPaymentInfoMessage giftCardDiscountMessage />
    </RenderIf>
  </>
}
