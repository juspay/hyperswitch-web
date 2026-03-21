open RecoilAtoms
open Utils
open ACHTypes

@react.component
let make = () => {
  let cleanBSB = str => str->String.replaceRegExp(%re("/-/g"), "")

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let (modalData, setModalData) = React.useState(_ => None)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let complete =
    areRequiredFieldsValid &&
    !areRequiredFieldsEmpty &&
    switch modalData {
    | Some(data: ACHTypes.data) =>
      data.accountNumber->String.length == 9 && data.sortCode->cleanBSB->String.length == 6
    | None => false
    }

  let empty =
    areRequiredFieldsEmpty ||
    switch modalData {
    | Some(data: ACHTypes.data) => data.accountNumber == "" && data.sortCode == ""
    | None => true
    }

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="becs_bank_debit")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        switch modalData {
        | Some(data: ACHTypes.data) => {
            let body =
              PaymentBody.dynamicPaymentBody("bank_debit", "becs")
              ->getJsonFromArrayOfJson
              ->flattenObject(true)
              ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
              ->getArrayOfTupleFromDict
              ->Array.concat([
                (
                  "payment_method_data.bank_debit.becs_bank_debit.account_number",
                  data.accountNumber->JSON.Encode.string,
                ),
                (
                  "payment_method_data.bank_debit.becs_bank_debit.bsb_number",
                  data.sortCode->JSON.Encode.string,
                ),
              ])
            intent(
              ~bodyArr=body,
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        | None => ()
        }
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

  let paymentMethod = "bank_debit"
  let paymentMethodType = "becs"

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingGridColumn}>
    <DynamicFields paymentMethod paymentMethodType setRequiredFieldsBody />
    <AddBankAccount modalData setModalData />
    <FullScreenPortal>
      <BankDebitModal setModalData />
    </FullScreenPortal>
    <Surcharge paymentMethod paymentMethodType />
    <Terms paymentMethod paymentMethodType />
  </div>
}

let default = make
