open RecoilAtoms
open Utils

type upiMethod = UPICollect | UPIIntent | UPIQR | NONE

let getPaymentMethodType = method =>
  switch method {
  | UPICollect => "upi_collect"
  | UPIQR => "upi_qr"
  | UPIIntent => "upi_intent"
  | NONE => ""
  }

let getMethodLabel = method =>
  switch method {
  | UPICollect => "Pay by UPI ID / VPA"
  | UPIQR => "Pay with QR Code"
  | UPIIntent => "Pay by any UPI app"
  | NONE => ""
  }

@react.component
let make = (~upiMethods) => {
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (selectedMethod, setSelectedMethod) = React.useState(_ => NONE)

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)

  let isMobile = React.useMemo0(() => {
    switch UPIHelpers.getMobileOperatingSystem() {
    | "ANDROID" | "IOS" => true
    | _ => false
    }
  })

  let availablePaymentMethods = React.useMemo(() => {
    let methods = []

    if upiMethods->Array.includes("upi_collect") {
      methods->Array.push(UPICollect)->ignore
    }

    if upiMethods->Array.includes("upi_intent") && isMobile {
      methods->Array.push(UPIIntent)->ignore
    }

    if upiMethods->Array.includes("upi_qr") {
      methods->Array.push(UPIQR)->ignore
    }

    methods
  }, (upiMethods, isMobile))

  React.useEffect(() => {
    switch availablePaymentMethods->Array.get(0) {
    | Some(method) => setSelectedMethod(_ => method)
    | None => ()
    }
    None
  }, [availablePaymentMethods])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if areRequiredFieldsValid && !areRequiredFieldsEmpty {
        intent(
          ~bodyArr=PaymentBody.dynamicPaymentBody(
            "upi",
            selectedMethod->getPaymentMethodType,
          )->mergeAndFlattenToTuples(requiredFieldsBody),
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~manualRetry=false,
          ~iframeId=keys.iframeId,
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (selectedMethod, areRequiredFieldsValid, requiredFieldsBody, areRequiredFieldsEmpty))

  useSubmitPaymentData(submitCallback)

  let renderMethodButton = (method: upiMethod, i) => {
    let isSelected = selectedMethod === method
    let label = method->getMethodLabel
    let paymentMethodType = method->getPaymentMethodType

    <button
      key={i->Int.toString}
      type_="button"
      onClick={_ => {
        setSelectedMethod(_ => method)
      }}
      className={`flex flex-col items-start w-full p-4 rounded-lg transition-all border`}>
      <div
        className="flex items-center gap-3 w-full"
        style={
          paddingBottom: isSelected ? "1rem" : "0rem",
          borderBottom: !isSelected ? "0px" : `1px solid ${themeObj.borderColor}`,
        }>
        <input
          type_="radio"
          name="upi_method"
          value={i->Int.toString}
          checked=isSelected
          onChange={_ => {
            setSelectedMethod(_ => method)
          }}
          className="w-4 h-4"
        />
        <span className="text-base font-medium" style={color: themeObj.colorText}>
          {React.string(label)}
        </span>
      </div>
      <RenderIf condition={isSelected && selectedMethod == UPIQR}>
        <UPIQRCode.UPIQRCodeInfoElement />
      </RenderIf>
      <RenderIf condition={isSelected}>
        <div
          className="DynamicFields flex flex-col animate-slowShow w-full mt-3"
          style={gridGap: themeObj.spacingGridColumn}>
          <DynamicFields paymentMethod="upi" paymentMethodType setRequiredFieldsBody />
          <RenderIf condition={method == UPIIntent}>
            <InfoElement />
          </RenderIf>
        </div>
      </RenderIf>
    </button>
  }

  <div className="animate-slowShow">
    <div className="flex flex-col" style={gridGap: themeObj.spacingGridColumn}>
      <RenderIf condition={availablePaymentMethods->Array.length > 0}>
        <div className="flex flex-col" style={gridGap: themeObj.spacingGridRow}>
          {availablePaymentMethods
          ->Array.mapWithIndex((item, i) => {renderMethodButton(item, i)})
          ->React.array}
        </div>
      </RenderIf>
    </div>
  </div>
}
