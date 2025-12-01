open PaymentMethodCollectTypes
open PaymentMethodCollectUtils
open RecoilAtoms

@react.component
let make = (
  ~availablePaymentMethods,
  ~availablePaymentMethodTypes,
  ~primaryTheme,
  ~handleSubmit,
  ~enabledPaymentMethodsWithDynamicFields: array<paymentMethodTypeWithDynamicFields>,
  ~journeyView,
  ~renderAddressForm,
  ~renderPayoutMethodForm,
) => {
  // Recoil states
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let payoutDynamicFields = Recoil.useRecoilValueFromAtom(payoutDynamicFieldsAtom)
  let formData = Recoil.useRecoilValueFromAtom(formDataAtom)
  let (activePmt, setActivePmt) = Recoil.useRecoilState(paymentMethodTypeAtom)
  let (validityDict, setValidityDict) = Recoil.useRecoilState(validityDictAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let supportedCardBrands = React.useMemo(() => {
    paymentMethodListValue->PaymentUtils.getSupportedCardBrands
  }, [paymentMethodListValue])

  // Component states
  let (formSubmitted, setFormSubmitted) = React.useState(_ => false)

  module View = {
    let viewStack = React.useRef([journeyView])
    let push = newState => {
      viewStack.current = [...viewStack.current, newState]
    }
    let pop = () => {
      switch viewStack.current->Array.length {
      | 0 | 1 => ()
      | _ => viewStack.current->Array.pop->ignore
      }
    }
    let get = () =>
      viewStack.current->Array.get(viewStack.current->Array.length - 1)->Option.getOr(journeyView)

    let (view, setStateView) = React.useState(_ => get())

    // For setting and popping views
    let setView = view => {
      setStateView(_ => {
        push(view)
        view
      })
    }
    let popView = (~count=1) => {
      setStateView(_ => {
        for _ in 1 to count {
          pop()
        }
        get()
      })
    }
  }

  // UI renderers
  let renderInfoTemplate = (label, value, uniqueKey) => {
    let labelClasses = "w-4/10 text-jp-gray-800 text-sm min-w-40 text-end"
    let valueClasses = "w-6/10 text-sm min-w-40"
    <div key={uniqueKey} className="flex flex-row items-center">
      <div className={labelClasses}> {React.string(label)} </div>
      <div className="mx-2.5 h-4 w-0.5 bg-jp-gray-300"> {React.string("")} </div>
      <div className={valueClasses}> {React.string(value)} </div>
    </div>
  }

  let renderBackButton = () =>
    <div className="flex justify-center items-center">
      <button
        className="bg-jp-gray-600 rounded-full h-7 w-7 self-center mr-5"
        onClick={_ => View.popView()}>
        {React.string("←")}
      </button>
    </div>

  let renderSaveButton = onClickHandler =>
    <button
      className="min-w-full mt-10 text-lg font-semibold px-2.5 py-1.5 text-white rounded"
      style={backgroundColor: primaryTheme}
      onClick=onClickHandler>
      {React.string(localeString.formSaveText)}
    </button>

  let renderHeader = (title, shouldRenderBackButton) => {
    let headerWrapperClasses = "flex flex-row justify-start"
    <div className=headerWrapperClasses>
      {shouldRenderBackButton ? renderBackButton() : React.null}
      <div className="text-xl lg:text-3xl font-semibold"> {React.string(title)} </div>
    </div>
  }

  // Contant variables
  let contentSubHeaderClasses = "text-base text-gray-500"

  <div className="w-full max-w-[520px]">
    {switch View.view {
    /// SCREEN #1 - PAYMENT METHOD SELECTION
    | SelectPM => {
        let optionSelectionHandler = (newPm: paymentMethod) => {
          // Update view
          // For cards - render forms
          // For other pms - render PMT selection screen
          let newView = switch newPm {
          | Card => {
              let newPmt = Card(Debit)
              let payoutDynamicFields =
                getPayoutDynamicFields(
                  enabledPaymentMethodsWithDynamicFields,
                  newPmt,
                )->Option.getOr(defaultPayoutDynamicFields(~pmt=newPmt))
              setActivePmt(_ => newPmt)
              payoutDynamicFields.address
              ->Option.map(address => {
                let fieldsToCollect =
                  address->Array.filter(addressField => addressField.value == None)
                if fieldsToCollect->Array.length > 0 {
                  AddressForm(address)
                } else {
                  PMDForm(newPmt, payoutDynamicFields.payoutMethodData)
                }
              })
              ->Option.getOr(PMDForm(newPmt, payoutDynamicFields.payoutMethodData))
            }
          | _ => SelectPMType(newPm)
          }

          View.setView(newView)
        }
        <>
          {renderHeader(localeString.formHeaderSelectAccountText, false)}
          <div className=contentSubHeaderClasses>
            {React.string(localeString.formFundsInfoText)}
          </div>
          <div className="mt-2.5">
            <div className="flex flex-col mt-2.5">
              {availablePaymentMethods
              ->Array.mapWithIndex((option, i) => {
                <button
                  key={Int.toString(i)}
                  onClick={_ => optionSelectionHandler(option)}
                  className="flex flex-row items-center border border-solid border-jp-gray-200 px-5 py-2.5 rounded mt-2.5 hover:bg-jp-gray-50">
                  {option->getPaymentMethodIcon}
                  <label className="text-start ml-2.5 cursor-pointer">
                    {React.string(option->String.make)}
                  </label>
                </button>
              })
              ->React.array}
            </div>
          </div>
        </>
      }

    /// SCREEN #2 - PAYMENT METHOD TYPE SELECTION
    | SelectPMType(selectedPm) => {
        let availablePmts = availablePaymentMethodTypes->Array.filterMap(pmt =>
          switch (selectedPm, pmt) {
          | (BankRedirect, BankRedirect(bankRedirect)) => Some(BankRedirect(bankRedirect))
          | (BankTransfer, BankTransfer(transfer)) => Some(BankTransfer(transfer))
          | (Wallet, Wallet(wallet)) => Some(Wallet(wallet))
          | _ => None
          }
        )
        let optionSelectionHandler = newPmt => {
          // Set new payment method type
          setActivePmt(_ => newPmt)

          // Update view
          let payoutDynamicFields =
            getPayoutDynamicFields(enabledPaymentMethodsWithDynamicFields, newPmt)->Option.getOr(
              defaultPayoutDynamicFields(~pmt=newPmt),
            )

          let newView =
            payoutDynamicFields.address
            ->Option.map(address => {
              let fieldsToCollect =
                address->Array.filter(addressField => addressField.value == None)
              if fieldsToCollect->Array.length > 0 {
                AddressForm(address)
              } else {
                PMDForm(newPmt, payoutDynamicFields.payoutMethodData)
              }
            })
            ->Option.getOr(PMDForm(newPmt, payoutDynamicFields.payoutMethodData))

          View.setView(newView)
        }
        switch selectedPm {
        | Card => {
            View.setView(SelectPM)
            React.null
          }
        | BankRedirect | BankTransfer | Wallet =>
          <>
            {renderHeader(localeString.formHeaderSelectBankText, true)}
            <div className="mt-2.5">
              <div className="flex flex-col mt-2.5">
                {availablePmts
                ->Array.mapWithIndex((option, i) => {
                  switch option {
                  | Card(_) => React.null
                  | BankRedirect(bankRedirect) =>
                    <button
                      key={Int.toString(i)}
                      onClick={_ => optionSelectionHandler(option)}
                      className="flex flex-row items-center border border-solid border-jp-gray-200 px-5 py-2.5 rounded mt-2.5 hover:bg-jp-gray-50">
                      {bankRedirect->getBankRedirectIcon}
                      <label className="text-start ml-2.5 cursor-pointer">
                        {React.string(bankRedirect->String.make)}
                      </label>
                    </button>
                  | BankTransfer(transfer) =>
                    <button
                      key={Int.toString(i)}
                      onClick={_ => optionSelectionHandler(option)}
                      className="flex flex-row items-center border border-solid border-jp-gray-200 px-5 py-2.5 rounded mt-2.5 hover:bg-jp-gray-50">
                      {transfer->getBankTransferIcon}
                      <label className="text-start ml-2.5 cursor-pointer">
                        {React.string(transfer->String.make)}
                      </label>
                    </button>
                  | Wallet(wallet) =>
                    <button
                      key={Int.toString(i)}
                      onClick={_ => optionSelectionHandler(option)}
                      className="flex flex-row items-center border border-solid border-jp-gray-200 px-5 py-2.5 rounded mt-2.5 hover:bg-jp-gray-50">
                      {wallet->getWalletIcon}
                      <label className="text-start ml-2.5 cursor-pointer">
                        {React.string(wallet->String.make)}
                      </label>
                    </button>
                  }
                })
                ->React.array}
              </div>
            </div>
          </>
        }
      }

    /// SCREEN #3 - ADDRESS COLLECION (OPTIONAL)
    | AddressForm(addressFields) => {
        let onSaveHandler = () => {
          let (fieldValidity, isAddressValid) = addressFields->Array.reduce((Dict.make(), true), (
            (fieldValidity, isAddressValid),
            field,
          ) => {
            let key = BillingAddress(field.fieldType)->getPaymentMethodDataFieldKey
            let value = formData->Dict.get(key)->Option.getOr("")
            let validity =
              BillingAddress(field.fieldType)->calculateValidity(value, "", ~default=Some(false))
            fieldValidity->Dict.set(key, validity)
            (fieldValidity, isAddressValid && validity != Some(false))
          })

          setValidityDict(_ => fieldValidity)
          if isAddressValid {
            View.setView(PMDForm(activePmt, payoutDynamicFields.payoutMethodData))
          }
        }
        <>
          {renderHeader(localeString.billingDetailsText, true)}
          <div className=contentSubHeaderClasses>
            {React.string(localeString.formSubheaderBillingDetailsText)}
          </div>
          <div className="mt-2.5">
            {addressFields->renderAddressForm->React.array}
            {renderSaveButton(_ => onSaveHandler())}
          </div>
        </>
      }

    /// SCREEN #4 PAYMENT METHOD DETAILS COLLECTION
    | PMDForm(activePmt, pmdFields) => {
        let pm = activePmt->getPaymentMethodForPmt
        let key = activePmt->getPaymentMethodTypeLabel

        let onSaveHandler = () => {
          let (fieldValidity, isPmdValid) = pmdFields->Array.reduce(
            (validityDict->Dict.copy, true),
            ((fieldValidity, isPmdValid), field) => {
              let key = PayoutMethodData(field.fieldType)->getPaymentMethodDataFieldKey
              let value = formData->Dict.get(key)->Option.getOr("")
              let validCardBrand = CardUtils.getFirstValidCardSchemeFromPML(
                ~cardNumber=value,
                ~enabledCardSchemes=supportedCardBrands->Option.getOr([]),
              )
              let newCardBrand = switch validCardBrand {
              | Some(brand) => brand
              | None => value->CardUtils.getCardBrand
              }
              let validity =
                PayoutMethodData(field.fieldType)->calculateValidity(
                  value,
                  newCardBrand,
                  ~default=Some(false),
                )
              fieldValidity->Dict.set(key, validity)
              (fieldValidity, isPmdValid && validity != Some(false))
            },
          )

          setValidityDict(_ => fieldValidity)
          if isPmdValid {
            formPaymentMethodData(formData, fieldValidity, payoutDynamicFields)
            ->Option.map(pmd => View.setView(FinalizeView((activePmt, pmd))))
            ->ignore
          }
        }
        <>
          {renderHeader(
            switch pm {
            | Card => localeString.formHeaderEnterCardText
            | BankRedirect
            | BankTransfer =>
              key->localeString.formHeaderBankText
            | Wallet => key->localeString.formHeaderWalletText
            },
            true,
          )}
          <div className="mt-2.5">
            {pmdFields->renderPayoutMethodForm->React.array}
            {renderSaveButton(_ => onSaveHandler())}
          </div>
        </>
      }

    /// SCREEN #5 FINALIZE SCREEN
    | FinalizeView(pmt, formFields) => {
        let pm = pmt->getPaymentMethodForPmt

        <div>
          <div className="flex flex-col">
            <div className="flex flex-row items-center mb-2.5 text-xl font-semibold">
              <img src={"merchantLogo"} alt="" className="h-6 w-auto" />
              <div className="ml-1.5">
                {React.string(
                  pmt
                  ->getPaymentMethodTypeLabel
                  ->localeString.formHeaderReviewTabLayoutText,
                )}
              </div>
            </div>
            {formFields
            ->Array.mapWithIndex((field, i) => {
              let (field, value) = field
              switch field {
              | PayoutMethodData(pmdFieldInfo) =>
                switch pmdFieldInfo.fieldType {
                | CardExpDate(CardExpYear) => React.null
                | CardExpDate(CardExpMonth) => {
                    let expiryYear =
                      formData
                      ->Dict.get(
                        PayoutMethodData(CardExpDate(CardExpYear))->getPaymentMethodDataFieldKey,
                      )
                      ->Option.flatMap(value =>
                        value
                        ->String.split("/")
                        ->Array.get(1)
                        ->Option.map(year => `20${year->String.trim}`)
                      )
                      ->Option.getOr("")
                    let expiryValue = `${value} / ${expiryYear}`
                    renderInfoTemplate(
                      PayoutMethodData(CardExpDate(CardExpMonth))->getPaymentMethodDataFieldLabel(
                        localeString,
                      ),
                      expiryValue,
                      i->Int.toString,
                    )
                  }
                | fieldType =>
                  renderInfoTemplate(
                    PayoutMethodData(fieldType)->getPaymentMethodDataFieldLabel(localeString),
                    value,
                    i->Int.toString,
                  )
                }
              | BillingAddress(_) => React.null
              }
            })
            ->React.array}
          </div>
          <div
            className="flex flex-row items-center min-w-full my-5 px-2.5 py-1.5 text-xs border border-solid border-blue-200 rounded bg-blue-50">
            <img src={"merchantLogo"} alt="" className="h-3 w-auto mr-1.5" />
            {React.string(
              pm
              ->getPaymentMethodLabel
              ->String.toLowerCase
              ->localeString.formFundsCreditInfoText,
            )}
          </div>
          <div className="flex my-5 text-lg font-semibold w-full">
            <button
              onClick={_ => View.popView(~count={View.viewStack.current->Array.length - 2})}
              disabled={formSubmitted}
              className="w-full px-2.5 py-1.5 rounded border border-solid"
              style={color: primaryTheme, borderColor: primaryTheme}>
              {React.string(localeString.formEditText)}
            </button>
            <button
              onClick={_ => {
                setFormSubmitted(_ => true)
                handleSubmit((pmt, formFields))
              }}
              disabled={formSubmitted}
              className="w-full px-2.5 py-1.5 text-white rounded ml-2.5"
              style={backgroundColor: primaryTheme}>
              {React.string(
                formSubmitted ? localeString.formSubmittingText : localeString.formSubmitText,
              )}
            </button>
          </div>
        </div>
      }
    }}
  </div>
}

let default = make
