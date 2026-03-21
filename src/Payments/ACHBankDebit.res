open RecoilAtoms
open Utils
open ACHTypes

@react.component
let make = () => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)

  let (bankError, setBankError) = React.useState(_ => "")

  let (openToolTip, setOpenToolTip) = React.useState(_ => false)

  let (modalData, setModalData) = React.useState(_ => None)

  let toolTipRef = React.useRef(Nullable.null)

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

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let complete = areRequiredFieldsValid && !areRequiredFieldsEmpty && modalData->Option.isSome
  let empty = areRequiredFieldsEmpty

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="ach_bank_debit")

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if modalData->Option.isNone {
        setBankError(_ => "Enter bank details and then confirm payment")
      }
      if complete {
        switch modalData {
        | Some(data: ACHTypes.data) =>
          let body =
            PaymentBody.dynamicPaymentBody("bank_debit", "ach")
            ->getJsonFromArrayOfJson
            ->flattenObject(true)
            ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
            ->getArrayOfTupleFromDict
            ->Array.concat([
              (
                "payment_method_data.bank_debit.ach_bank_debit.account_number",
                data.accountNumber->JSON.Encode.string,
              ),
              (
                "payment_method_data.bank_debit.ach_bank_debit.routing_number",
                data.routingNumber->JSON.Encode.string,
              ),
              (
                "payment_method_data.bank_debit.ach_bank_debit.bank_account_holder_name",
                data.accountHolderName->JSON.Encode.string,
              ),
              (
                "payment_method_data.bank_debit.ach_bank_debit.account_type",
                data.accountType->JSON.Encode.string,
              ),
            ])
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
  }, (
    modalData,
    isManualRetryEnabled,
    requiredFieldsBody,
    areRequiredFieldsValid,
    areRequiredFieldsEmpty,
  ))
  useSubmitPaymentData(submitCallback)

  let paymentMethodType = "ach"
  let paymentMethod = "bank_debit"

  <>
    <RenderIf condition={isVerifyPMAuthConnectorConfigured}>
      <AddBankDetails paymentMethodType />
    </RenderIf>
    <RenderIf condition={!isVerifyPMAuthConnectorConfigured}>
      <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingGridColumn}>
        <DynamicFields paymentMethod paymentMethodType setRequiredFieldsBody />
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
        <Surcharge paymentMethod paymentMethodType />
        <Terms paymentMethod paymentMethodType />
        <FullScreenPortal>
          <BankDebitModal setModalData />
        </FullScreenPortal>
      </div>
    </RenderIf>
  </>
}

let default = make
