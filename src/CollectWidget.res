open PaymentMethodCollectTypes
open PaymentMethodCollectUtils

@react.component
let make = (
  ~availablePaymentMethods,
  ~availablePaymentMethodTypes,
  ~primaryTheme,
  ~handleSubmit,
) => {
  // Component states
  let (selectedPaymentMethod, setSelectedPaymentMethod) = React.useState(_ =>
    defaultSelectedPaymentMethod
  )
  let (selectedPaymentMethodType, setSelectedPaymentMethodType) = React.useState(_ =>
    defaultSelectedPaymentMethodType
  )
  let (fieldValidityDict, setFieldValidityDict): (
    Dict.t<option<bool>>,
    (Dict.t<option<bool>> => Dict.t<option<bool>>) => unit,
  ) = React.useState(_ => Dict.make())
  let (savedPMD, setSavedPMD): (
    option<paymentMethodData>,
    (option<paymentMethodData> => option<paymentMethodData>) => unit,
  ) = React.useState(_ => None)
  let (submitted, setSubmitted) = React.useState(_ => false)
  let (paymentMethodData, setPaymentMethodData) = React.useState(_ => Dict.make())
  let inputRef = React.useRef(Nullable.null)

  // Reset payment method type
  React.useEffect(() => {
    switch selectedPaymentMethod {
    | Some(Card) => setSelectedPaymentMethodType(_ => Some(Card(Debit)))
    | _ => setSelectedPaymentMethodType(_ => None)
    }

    None
  }, [selectedPaymentMethod])

  // Helpers
  let resetForm = () => {
    setPaymentMethodData(_ => Dict.make())
    setFieldValidityDict(_ => Dict.make())
  }

  let handleBackClick = () => {
    switch savedPMD {
    | Some(_) => setSavedPMD(_ => None)
    | None =>
      switch selectedPaymentMethodType {
      | Some(Card(_)) => {
          setSelectedPaymentMethod(_ => None)
          setSelectedPaymentMethodType(_ => None)
          resetForm()
        }
      | Some(_) => setSelectedPaymentMethodType(_ => None)
      | None =>
        switch selectedPaymentMethod {
        | Some(_) => {
            setSelectedPaymentMethod(_ => None)
            resetForm()
            ()
          }
        | None => ()
        }
      }
    }
  }

  let setPaymentMethodDataValue = (key: paymentMethodDataField, value) =>
    setPaymentMethodData(_ => paymentMethodData->setValue(key->getPaymentMethodDataFieldKey, value))

  let getPaymentMethodDataValue = (key: paymentMethodDataField) =>
    paymentMethodData
    ->getValue(key->getPaymentMethodDataFieldKey)
    ->Option.getOr("")

  let setFieldValidity = (key: paymentMethodDataField, value) => {
    let fieldValidityCopy = fieldValidityDict->Dict.copy
    fieldValidityCopy->Dict.set(key->getPaymentMethodDataFieldKey, value)
    setFieldValidityDict(_ => fieldValidityCopy)
  }

  let getFieldValidity = (key: paymentMethodDataField) =>
    fieldValidityDict->Dict.get(key->getPaymentMethodDataFieldKey)->Option.getOr(None)

  let calculateAndSetValidity = (key: paymentMethodDataField) => {
    let updatedValidity = paymentMethodData->calculateValidity(key)
    key->setFieldValidity(updatedValidity)
  }

  let handleSave = _ev => {
    let pmd = formPaymentMethodData(selectedPaymentMethodType, paymentMethodData, fieldValidityDict)
    setSavedPMD(_ => pmd)
  }

  // UI renders
  let renderBackButton = () => {
    switch (selectedPaymentMethod, selectedPaymentMethodType) {
    | (Some(_), _) =>
      <button
        className="bg-jp-gray-600 rounded-full h-7 w-7 self-center mr-[20px]"
        onClick={_ => handleBackClick()}>
        {React.string("←")}
      </button>
    | _ => React.null
    }
  }

  let renderContentHeader = () =>
    switch (savedPMD, selectedPaymentMethodType) {
    | (Some(_), _) => React.string("Review")
    | (None, Some(pmt)) =>
      switch pmt {
      | Card(_) => React.string("Enter card details")
      | BankTransfer(bankTransferType) =>
        React.string("Enter " ++ bankTransferType->String.make ++ " bank details ")
      | Wallet(walletTransferType) =>
        React.string("Enter " ++ walletTransferType->String.make ++ " wallet details ")
      }
    | (None, None) =>
      switch selectedPaymentMethod {
      | Some(Card) => React.string("Enter card details")
      | Some(BankTransfer) => React.string("Select a bank method")
      | Some(Wallet) => React.string("Select a wallet")
      | None => React.string("Select an account for payouts")
      }
    }

  let renderContentSubHeader = () =>
    switch savedPMD {
    | Some(_) => React.string("Your payout method details")
    | None =>
      switch selectedPaymentMethod {
      | Some(_) => React.null
      | None => React.string("Funds will be credited to this account")
      }
    }

  let renderInfoTemplate = (label, value, uniqueKey) => {
    let labelClasses = "w-4/10 text-jp-gray-800 text-[14px] min-w-40 text-end"
    let valueClasses = "w-6/10 text-[14px] min-w-40"
    <div key={uniqueKey} className="flex flex-row items-center">
      <div className={labelClasses}> {React.string(label)} </div>
      <div className="mx-[10px] h-[15px] w-[2px] bg-jp-gray-300"> {React.string("")} </div>
      <div className={valueClasses}> {React.string(value)} </div>
    </div>
  }

  let renderFinalizeScreen = (pmd: paymentMethodData) => {
    let (paymentMethod, paymentMethodType, fields) = pmd
    <div>
      <div className="flex flex-col">
        <div className="flex flex-row items-center mt-[10px] mb-[10px] text-[20px]">
          <img src={"merchantLogo"} alt="" className="h-[25px] w-auto" />
          <div className="ml-[10px]">
            {React.string(paymentMethodType->getPaymentMethodTypeLabel)}
          </div>
          <div className="ml-[5px]"> {React.string(paymentMethod->String.make)} </div>
        </div>
        {fields
        ->Array.mapWithIndex((field, i) => {
          let (field, value) = field
          {renderInfoTemplate(field->getPaymentMethodDataFieldLabel, value, i->Int.toString)}
        })
        ->React.array}
      </div>
      <div
        className="flex flex-row items-center min-w-full mt-[20px] py-[5px] px-[10px] text-[13px] border border-solid border-blue-200 rounded bg-blue-50">
        <img src={"merchantLogo"} alt="" className="h-[12px] w-auto mr-[5px]" />
        {React.string(
          `Your funds will be deposited in the selected ${paymentMethod
            ->getPaymentMethodLabel
            ->String.toLowerCase}`,
        )}
      </div>
      <button
        onClick={_ => {
          setSubmitted(_ => true)
          handleSubmit(pmd)
        }}
        disabled={submitted}
        className="min-w-full mt-[20px] text-[18px] font-semibold px-[10px] py-[5px] text-white rounded"
        style={backgroundColor: primaryTheme}>
        {React.string(submitted ? "SUBMITTING" : "SUBMIT")}
      </button>
    </div>
  }

  let renderInputTemplate = (field: paymentMethodDataField) => {
    let isValid = field->getFieldValidity
    let labelClasses = `text-[14px] mt-[10px] ${isValid->Option.getOr(true)
        ? "text-jp-gray-800"
        : "text-red-950"}`
    let inputClasses = `min-w-full border mt-[5px] px-[10px] py-[8px] rounded-lg ${isValid->Option.getOr(
        true,
      )
        ? "border-jp-gray-200"
        : "border-red-950"}`
    <InputField
      id={field->getPaymentMethodDataFieldKey}
      className=inputClasses
      labelClassName=labelClasses
      paymentType={PaymentMethodCollectElement}
      inputRef
      isFocus={true}
      isValid
      fieldName={field->getPaymentMethodDataFieldLabel}
      placeholder={field->getPaymentMethodDataFieldPlaceholder}
      maxLength={field->getPaymentMethodDataFieldMaxLength}
      value={field->getPaymentMethodDataValue}
      onChange={event => field->setPaymentMethodDataValue(ReactEvent.Form.target(event)["value"])}
      setIsValid={updatedValidityFn => field->setFieldValidity(updatedValidityFn())}
      onBlur={_ev => field->calculateAndSetValidity}
    />
  }

  let renderInputs = (pmt: paymentMethodType) => {
    <div>
      {switch pmt {
      | Card(_) =>
        <div className="collect-card">
          <div className="flex flex-row">
            <div className="w-5/10"> {CardNumber->renderInputTemplate} </div>
            <div className="w-3/10 ml-[30px]"> {CardExpDate->renderInputTemplate} </div>
          </div>
          {CardHolderName->renderInputTemplate}
        </div>
      | BankTransfer(bankTransferType) =>
        <div className="collect-bank">
          {switch bankTransferType {
          | ACH =>
            <React.Fragment>
              {ACHRoutingNumber->renderInputTemplate}
              {ACHAccountNumber->renderInputTemplate}
            </React.Fragment>
          | Bacs =>
            <React.Fragment>
              {BacsSortCode->renderInputTemplate}
              {BacsAccountNumber->renderInputTemplate}
            </React.Fragment>
          | Sepa =>
            <React.Fragment>
              {SepaIban->renderInputTemplate}
              {SepaBic->renderInputTemplate}
            </React.Fragment>
          }}
        </div>
      | Wallet(walletType) =>
        <div className="collect-wallet">
          {switch walletType {
          | Paypal =>
            <React.Fragment>
              {PaypalMail->renderInputTemplate}
              {PaypalMobNumber->renderInputTemplate}
            </React.Fragment>
          | Venmo => <React.Fragment> {VenmoMobNumber->renderInputTemplate} </React.Fragment>
          | Pix => PixId->renderInputTemplate
          }}
        </div>
      }}
      <button
        className="min-w-full mt-[40px] text-[18px] font-semibold px-[10px] py-[5px] text-white rounded"
        style={backgroundColor: primaryTheme}
        onClick={handleSave}>
        {React.string("SAVE")}
      </button>
    </div>
  }

  let renderPMOptions = () =>
    <div className="flex flex-col mt-[10px]">
      {availablePaymentMethods
      ->Array.mapWithIndex((pm, i) => {
        <button
          key={Int.toString(i)}
          onClick={_ => setSelectedPaymentMethod(_ => Some(pm))}
          className="text-start border border-solid border-jp-gray-200 px-[20px] py-[10px] rounded mt-[10px] hover:bg-jp-gray-50">
          {React.string(pm->String.make)}
        </button>
      })
      ->React.array}
    </div>

  let renderPMTOptions = () => {
    let commonClasses = "text-start border border-solid border-jp-gray-200 px-[20px] py-[10px] rounded mt-[10px] hover:bg-jp-gray-50"
    <div className="flex flex-col">
      {switch selectedPaymentMethod {
      | Some(Card) => React.null
      | Some(BankTransfer) =>
        availablePaymentMethodTypes.bankTransfer
        ->Array.mapWithIndex((pmt, i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(BankTransfer(pmt)))}
            className=commonClasses>
            {React.string(pmt->String.make)}
          </button>
        )
        ->React.array
      | Some(Wallet) =>
        availablePaymentMethodTypes.wallet
        ->Array.mapWithIndex((pmt, i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(Wallet(pmt)))}
            className=commonClasses>
            {React.string(pmt->String.make)}
          </button>
        )
        ->React.array
      | None => renderPMOptions()
      }}
    </div>
  }

  <div className="shadow-lg rounded p-[40px] h-min min-w-96">
    <div className="flex flex-row justify-start">
      <div className="flex justify-center items-center"> {renderBackButton()} </div>
      <div className="text-[30px] font-semibold"> {renderContentHeader()} </div>
    </div>
    <div className="text-[16px] text-gray-500"> {renderContentSubHeader()} </div>
    <div className="mt-[10px]">
      {switch savedPMD {
      | Some(pmd) => renderFinalizeScreen(pmd)
      | None =>
        switch selectedPaymentMethodType {
        | Some(pmt) => renderInputs(pmt)
        | None => renderPMTOptions()
        }
      }}
    </div>
  </div>
}
let default = make
