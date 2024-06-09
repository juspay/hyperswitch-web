open PaymentMethodCollectUtils
open PaymentMethodCollectTypes
open RecoilAtoms

@react.component
let make = (~integrateError, ~logger) => {
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(paymentMethodCollectOptionAtom)

  // Component states
  let (availablePaymentMethods, setAvailablePaymentMethods) = React.useState(_ =>
    defaultAvailablePaymentMethods
  )
  let (availablePaymentMethodTypes, setAvailablePaymentMethodTypes) = React.useState(_ =>
    defaultAvailablePaymentMethodTypes
  )
  let (selectedPaymentMethod, setSelectedPaymentMethod) = React.useState(_ =>
    defaultSelectedPaymentMethod
  )
  let (selectedPaymentMethodType, setSelectedPaymentMethodType) = React.useState(_ =>
    defaultSelectedPaymentMethodType
  )
  let (collectError, setCollectError) = React.useState(_ => None)
  let (paymentMethodData, setPaymentMethodData) = React.useState(_ => Dict.make())
  let (amount, setAmount) = React.useState(_ => options.amount)
  let (currency, setCurrency) = React.useState(_ => options.currency)
  let (flow, setFlow) = React.useState(_ => options.flow)
  let (linkId, setLinkId) = React.useState(_ => options.linkId)
  let (merchantName, setMerchantName) = React.useState(_ => options.collectorName)
  let (merchantLogo, setMerchantLogo) = React.useState(_ => options.logo)
  let (merchantTheme, setMerchantTheme) = React.useState(_ => options.theme)
  let (fieldValidityDict, setFieldValidityDict): (
    Js.Dict.t<option<bool>>,
    (Js.Dict.t<option<bool>> => Js.Dict.t<option<bool>>) => unit,
  ) = React.useState(_ => Dict.make())

  // DOM references
  let inputRef = React.useRef(Nullable.null)

  // Form a list of available payment methods
  React.useEffect(() => {
    let availablePMT = {
      card: [],
      bankTransfer: [],
      wallet: [],
    }
    let _ = options.enabledPaymentMethods->Array.map(pm => {
      switch pm {
      | Card(cardType) =>
        if !(availablePMT.card->Array.includes(cardType)) {
          availablePMT.card->Array.push(cardType)
        }
      | BankTransfer(bankTransferType) =>
        if !(availablePMT.bankTransfer->Array.includes(bankTransferType)) {
          availablePMT.bankTransfer->Array.push(bankTransferType)
        }
      | Wallet(walletType) =>
        if !(availablePMT.wallet->Array.includes(walletType)) {
          availablePMT.wallet->Array.push(walletType)
        }
      }
    })

    let availablePM: array<paymentMethod> = []
    if !(availablePM->Array.includes(BankTransfer)) && availablePMT.bankTransfer->Array.length > 0 {
      availablePM->Array.push(BankTransfer)
    }
    if !(availablePM->Array.includes(Card)) && availablePMT.card->Array.length > 0 {
      availablePM->Array.push(Card)
    }
    if !(availablePM->Array.includes(Wallet)) && availablePMT.wallet->Array.length > 0 {
      availablePM->Array.push(Wallet)
    }

    setAvailablePaymentMethods(_ => availablePM)
    setAvailablePaymentMethodTypes(_ => availablePMT)

    None
  }, [options.enabledPaymentMethods])

  // Update amount
  React.useEffect(() => {
    setAmount(_ => options.amount)
    None
  }, [options.amount])

  // Update currency
  React.useEffect(() => {
    setCurrency(_ => options.currency)
    None
  }, [options.currency])

  // Update flow
  React.useEffect(() => {
    setFlow(_ => options.flow)
    None
  }, [options.flow])

  // Update linkId
  React.useEffect(() => {
    setLinkId(_ => options.linkId)
    None
  }, [options.linkId])

  // Update merchant's name
  React.useEffect(() => {
    setMerchantName(_ => options.collectorName)
    None
  }, [options.collectorName])

  // Update merchant's logo
  React.useEffect(() => {
    setMerchantLogo(_ => options.logo)
    None
  }, [options.logo])

  // Update merchant's primary theme
  React.useEffect(() => {
    setMerchantTheme(_ => options.theme)
    None
  }, [options.theme])

  // Reset payment method type
  React.useEffect(() => {
    switch selectedPaymentMethod {
    | Some(Card) => setSelectedPaymentMethodType(_ => Some(Card(Debit)))
    | _ => setSelectedPaymentMethodType(_ => None)
    }

    None
  }, [selectedPaymentMethod])

  let resetForm = () => {
    setPaymentMethodData(_ => Dict.make())
    setFieldValidityDict(_ => Dict.make())
  }

  let handleBackClick = () => {
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

  let renderBackButton = () => {
    switch (selectedPaymentMethod, selectedPaymentMethodType) {
    | (Some(_), _) =>
      <button
        className="bg-jp-gray-600 rounded-full h-7 w-7 self-center"
        onClick={_ => handleBackClick()}>
        {React.string("←")}
      </button>
    | (None, _) => React.null
    }
  }

  let renderContentHeader = () =>
    switch selectedPaymentMethodType {
    | Some(pmt) =>
      switch pmt {
      | Card(_) => React.string("Enter card details")
      | BankTransfer(bankTransferType) =>
        React.string("Enter " ++ bankTransferType->String.make ++ " bank details ")
      | Wallet(walletTransferType) =>
        React.string("Enter " ++ walletTransferType->String.make ++ " wallet details ")
      }
    | None =>
      switch selectedPaymentMethod {
      | Some(Card) => React.string("Enter card details")
      | Some(BankTransfer) => React.string("Select a bank method")
      | Some(Wallet) => React.string("Select a wallet")
      | None => React.string("Select an account for payouts")
      }
    }

  let renderContentSubHeader = () =>
    switch selectedPaymentMethod {
    | Some(_) => React.null
    | None => React.string("Funds will be credited to this account")
    }

  let renderPMOptions = () => {
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
  }

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

  let handleSubmit = _ev => {
    let pmdBody = formCreatePaymentMethodRequestBody(
      selectedPaymentMethodType,
      paymentMethodData,
      fieldValidityDict,
    )

    switch pmdBody {
    | Some(pmd) => {
        let pmdBody =
          pmd->Array.map(((k, v)) => (k, v->JSON.Encode.string))->Dict.fromArray->Js.Json.object_
        let body: array<(string, Js.Json.t)> = [("customer_id", options.customerId->Js.Json.string)]
        switch selectedPaymentMethod {
        | Some(selectedPaymentMethod) => {
            let paymentMethod = selectedPaymentMethod->getPaymentMethod
            body->Array.push(("payment_method", paymentMethod->Js.Json.string))
            body->Array.push((paymentMethod, pmdBody))
          }
        | None => ()
        }
        switch selectedPaymentMethodType {
        | Some(selectedPaymentMethodType) =>
          body->Array.push((
            "payment_method_type",
            selectedPaymentMethodType->getPaymentMethodType->Js.Json.string,
          ))
        | None => ()
        }
        // Create payment method
        open Promise
        PaymentHelpers.createPaymentMethod(
          ~clientSecret=keys.clientSecret->Option.getOr(""),
          ~publishableKey=keys.publishableKey,
          ~logger,
          ~switchToCustomPod=false,
          ~endpoint="http://localhost:8080",
          ~body,
        )
        ->then(res => {
          Js.Console.log2("DEBUG RES", res)
          resolve()
        })
        ->catch(err => {
          Js.Console.log2("DEBUG ERR", err)
          resolve()
        })
        ->ignore
      }
    | None => {
        Js.Console.log2("DEBUG", "Invalid data")
        setCollectError(_ => Some("Invalid Data"))
      }
    }
  }

  // PMD dict
  let setPaymentMethodDataValue = (key: paymentMethodDataField, value) =>
    setPaymentMethodData(_ => paymentMethodData->setValue(key->getPaymentMethodDataFieldKey, value))

  let getPaymentMethodDataValue = (key: paymentMethodDataField) =>
    paymentMethodData
    ->getValue(key->getPaymentMethodDataFieldKey)
    ->Option.getOr("")

  // Field validity dict
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
          | Venmo =>
            <React.Fragment>
              {VenmoMail->renderInputTemplate}
              {VenmoMobNumber->renderInputTemplate}
            </React.Fragment>
          | Pix => PixId->renderInputTemplate
          }}
        </div>
      }}
      <button
        className="min-w-full mt-[40px] text-[18px] font-semibold px-[10px] py-[5px] text-white rounded"
        style={backgroundColor: merchantTheme}
        onClick={handleSubmit}>
        {React.string("SAVE")}
      </button>
    </div>
  }

  if integrateError {
    <ErrorOccured />
  } else {
    <div className="flex h-screen">
      {switch flow {
      | PayoutLinkInitiate =>
        <React.Fragment>
          // Merchant's info
          <div
            className="flex flex-col w-4/10 px-[50px] py-[80px]"
            style={backgroundColor: merchantTheme}>
            <div
              className="flex flex-col self-end rounded-md shadow-lg min-w-80 w-full max-w-96"
              style={backgroundColor: "#FEFEFE"}>
              <div className="mx-[20px] mt-[20px] flex flex-row justify-between">
                <div className="font-bold text-[35px]">
                  {React.string(`${currency} ${amount->Int.toString}`)}
                </div>
                <img className="h-12 w-auto" src={merchantLogo} alt="O" />
              </div>
              <div className="mx-[20px]">
                <div className="self-center text-[20px] font-semibold">
                  {React.string("Payout from ")}
                  {React.string(merchantName)}
                </div>
                <div className="flex flex-row mt-[5px]">
                  <div className="font-semibold text-[12px]"> {React.string("Ref Id")} </div>
                  <div className="ml-[5px] text-[12px] text-gray-800"> {React.string(linkId)} </div>
                </div>
              </div>
              <div className="mt-[10px] px-[20px] py-[5px] bg-gray-200 text-[13px] rounded-b-lg">
                {React.string(`Link expires on: `)}
              </div>
            </div>
          </div>
          // Collect widget
          <div className="flex flex-row w-6/10 px-[50px] py-[80px]">
            <div className="shadow-lg rounded p-[40px] h-min min-w-96">
              <div className="flex flex-row justify-start">
                <div className="flex justify-center items-center"> {renderBackButton()} </div>
                <div className="ml-[20px] text-[30px] font-semibold"> {renderContentHeader()} </div>
              </div>
              <div className="text-[16px] text-center text-gray-500">
                {renderContentSubHeader()}
              </div>
              <div className="mt-[10px]">
                {switch selectedPaymentMethodType {
                | Some(pmt) => renderInputs(pmt)
                | None => renderPMTOptions()
                }}
              </div>
            </div>
          </div>
        </React.Fragment>

      | PayoutMethodCollect =>
        <React.Fragment>
          // Merchant's info
          <div className="flex flex-col w-3/10 p-[50px]" style={backgroundColor: merchantTheme}>
            <div className="flex flex-row">
              <img className="h-12 w-auto" src={merchantLogo} alt="O" />
              <div className="ml-[15px] text-white self-center text-[25px] font-bold">
                {React.string(merchantName)}
              </div>
            </div>
          </div>
          // Collect widget
          <div className="flex flex-row w-7/10 p-[50px] ml-[30px]">
            <div
              className="flex flex-col rounded-[2px] h-min-content border-2 border-jp-gray-200 mt-[60px]">
              {availablePaymentMethods
              ->Array.mapWithIndex((pm, i) => {
                let border = availablePaymentMethods->Array.length - 1 === i ? "" : "border-b-2"
                let paymentMethod = pm->String.make
                let background =
                  selectedPaymentMethod->String.make === paymentMethod ? "bg-blue-200" : ""
                let classes = `p-[10px] text-start ${border} ${background} hover:bg-blue-200`
                <button
                  key={Int.toString(i)}
                  onClick={_e => setSelectedPaymentMethod(_ => Some(pm))}
                  className={classes}>
                  {React.string(paymentMethod)}
                </button>
              })
              ->React.array}
            </div>
            <div className="ml-[30px] min-h-[250px]">
              <div className="text-[40px] font-bold"> {renderContentHeader()} </div>
              <div>
                {switch selectedPaymentMethodType {
                | Some(pmt) => renderInputs(pmt)
                | None => renderPMTOptions()
                }}
              </div>
            </div>
          </div>
        </React.Fragment>
      }}
    </div>
  }
}

let default = make
