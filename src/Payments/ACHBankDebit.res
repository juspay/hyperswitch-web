open RecoilAtoms
open Utils
open PaymentModeType

@react.component
let make = () => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let (bankError, setBankError) = React.useState(_ => "")

  let (openToolTip, setOpenToolTip) = React.useState(_ => false)

  let (modalData, setModalData) = React.useState(_ => None)

  let toolTipRef = React.useRef(Nullable.null)
  let line1 = Recoil.useRecoilValueFromAtom(userAddressline1)
  let line2 = Recoil.useRecoilValueFromAtom(userAddressline2)
  let country = Recoil.useRecoilValueFromAtom(userAddressCountry)
  let city = Recoil.useRecoilValueFromAtom(userAddressCity)
  let postalCode = Recoil.useRecoilValueFromAtom(userAddressPincode)
  let state = Recoil.useRecoilValueFromAtom(userAddressState)
  let countryCode = Utils.getCountryCode(country.value).isoAlpha2
  let stateCode = Utils.getStateCodeFromStateName(state.value, countryCode)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let pmAuthMapper = React.useMemo1(
    () =>
      PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(paymentMethodListValue.payment_methods),
    [paymentMethodListValue.payment_methods],
  )

  let isVerifyPMAuthConnectorConfigured =
    displaySavedPaymentMethods && pmAuthMapper->Dict.get("ach")->Option.isSome

  OutsideClick.useOutsideClick(
    ~refs=ArrayOfRef([toolTipRef]),
    ~isActive=openToolTip,
    ~callback=() => {
      setOpenToolTip(_ => false)
    },
  )

  React.useEffect(() => {
    if modalData->Option.isSome {
      setBankError(_ => "")
    }
    None
  }, [modalData])

  let complete =
    email.value != "" &&
    fullName.value != "" &&
    email.isValid->Option.getOr(false) &&
    modalData->Option.isSome
  let empty = email.value == "" || fullName.value != ""

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="ach_bank_debit")

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit && !isGiftCardOnlyPayment {
      if modalData->Option.isNone {
        setBankError(_ => "Enter bank details and then confirm payment")
      }
      if complete {
        switch modalData {
        | Some(data) =>
          let body = PaymentBody.achBankDebitBody(
            ~email=email.value,
            ~bank=data,
            ~cardHolderName=fullName.value,
            ~line1=line1.value,
            ~line2=line2.value,
            ~country=countryCode,
            ~city=city.value,
            ~postalCode=postalCode.value,
            ~stateCode,
          )
          intent(
            ~bodyArr=body,
            ~confirmParam=confirm.confirmParams,
            ~handleUserError=false,
            ~manualRetry=isManualRetryEnabled,
          )
        | None => ()
        }
        ()
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, modalData, fullName, isManualRetryEnabled, isGiftCardOnlyPayment))
  useSubmitPaymentData(submitCallback)

  <>
    <RenderIf condition={isVerifyPMAuthConnectorConfigured}>
      <AddBankDetails paymentMethodType="ach" />
    </RenderIf>
    <RenderIf condition={!isVerifyPMAuthConnectorConfigured}>
      <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingGridColumn}>
        <FullNamePaymentInput />
        <EmailPaymentInput />
        <div className="flex flex-col">
          <AddBankAccount modalData setModalData />
          <RenderIf condition={bankError->String.length > 0}>
            <div
              className="Error pt-1"
              style={
                color: themeObj.colorDangerText,
                fontSize: themeObj.fontSizeSm,
                alignSelf: "start",
                textAlign: "left",
              }>
              {React.string(bankError)}
            </div>
          </RenderIf>
        </div>
        <Surcharge paymentMethod="bank_debit" paymentMethodType="ach" />
        <Terms mode=ACHBankDebit />
        <FullScreenPortal>
          <BankDebitModal setModalData />
        </FullScreenPortal>
      </div>
    </RenderIf>
  </>
}

let default = make
