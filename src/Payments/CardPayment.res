type target = {checked: bool}
type event = {target: target}

@react.component
let make = (
  ~cardProps,
  ~expiryProps,
  ~cvcProps,
  ~isBancontact=false,
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
) => {
  open PaymentType
  open PaymentModeType
  open Utils
  open UtilityHooks

  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let (nickname, setNickname) = React.useState(_ => "")

  let (_, _, cardNumber, _, _, _, _, _, _, _) = cardProps

  let cardBrand = React.useMemo(() => {
    cardNumber->CardUtils.getCardBrand
  }, [cardNumber])

  let {displaySavedPaymentMethodsCheckbox} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let showFields = Recoil.useRecoilValueFromAtom(RecoilAtoms.showCardFieldsAtom)
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ => false)

  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
  }

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)

  useHandlePostMessages(
    ~complete=areRequiredFieldsValid,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="card",
  )

  let isGuestCustomer = useIsGuestCustomer()

  let isCustomerAcceptanceRequired = useIsCustomerAcceptanceRequired(
    ~displaySavedPaymentMethodsCheckbox,
    ~isSaveCardsChecked,
    ~list,
    ~isGuestCustomer,
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    let onSessionBody = [("customer_acceptance", PaymentBody.customerAcceptanceBody)]
    let defaultCardBody = PaymentBody.dynamicCardPaymentBody(~cardBrand, ~nickname, ())
    let banContactBody = PaymentBody.bancontactBody()
    let cardBody = if isCustomerAcceptanceRequired {
      defaultCardBody->Array.concat(onSessionBody)
    } else {
      defaultCardBody
    }
    if confirm.doSubmit {
      let validFormat = areRequiredFieldsValid
      if validFormat && (showFields || isBancontact) {
        intent(
          ~bodyArr={
            (isBancontact ? banContactBody : cardBody)
            ->Dict.fromArray
            ->JSON.Encode.object
            ->flattenObject(true)
            ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
            ->getArrayOfTupleFromDict
          },
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          (),
        )
      } else if !validFormat {
        setUserError(localeString.enterValidDetailsText)
      }
    }
  }, (areRequiredFieldsValid, requiredFieldsBody, isCustomerAcceptanceRequired, nickname))
  useSubmitPaymentData(submitCallback)

  let paymentMethod = isBancontact ? "bank_redirect" : "card"
  let paymentMethodType = isBancontact ? "bancontact_card" : "debit"
  let conditionsForShowingSaveCardCheckbox =
    list.mandate_payment->Option.isNone &&
    !isGuestCustomer &&
    list.payment_type !== SETUP_MANDATE &&
    options.displaySavedPaymentMethodsCheckbox &&
    !isBancontact

  let nicknameFieldClassName = conditionsForShowingSaveCardCheckbox ? "pt-2" : "pt-5"

  <div className="animate-slowShow">
    <RenderIf condition={showFields || isBancontact}>
      <div
        className="flex flex-col"
        style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
        <div className="w-full">
          <DynamicFields
            paymentType
            list
            paymentMethod
            paymentMethodType
            setRequiredFieldsBody
            cardProps={Some(cardProps)}
            expiryProps={Some(expiryProps)}
            cvcProps={Some(cvcProps)}
            isBancontact
          />
          <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
            <div className="pt-4 pb-2 flex items-center justify-start">
              <SaveDetailsCheckbox
                isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked
              />
            </div>
          </RenderIf>
          <RenderIf condition={isCustomerAcceptanceRequired}>
            <div className={`pb-2 ${nicknameFieldClassName}`}>
              <NicknamePaymentInput paymentType value=nickname setValue=setNickname />
            </div>
          </RenderIf>
        </div>
      </div>
    </RenderIf>
    <RenderIf condition={showFields || isBancontact}>
      <Surcharge
        list paymentMethod paymentMethodType cardBrand={cardBrand->CardUtils.getCardType}
      />
    </RenderIf>
    <RenderIf condition={!isBancontact}>
      {switch (list.mandate_payment, options.terms.card, list.payment_type) {
      | (Some(_), Auto, NEW_MANDATE)
      | (Some(_), Auto, SETUP_MANDATE)
      | (_, Always, NEW_MANDATE)
      | (_, Always, SETUP_MANDATE)
      | (_, _, SETUP_MANDATE)
      | (_, _, NEW_MANDATE) =>
        <div
          className="opacity-50 text-xs mb-2 text-left"
          style={ReactDOMStyle.make(
            ~color=themeObj.colorText,
            ~marginTop=themeObj.spacingGridColumn,
            (),
          )}>
          <Terms mode={Card} />
        </div>
      | (_, _, _) => React.null
      }}
    </RenderIf>
  </div>
}
