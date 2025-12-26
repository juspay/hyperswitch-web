open PaymentMethodCollectTypes
open PaymentMethodCollectUtils
open RecoilAtoms

@react.component
let make = (
  ~availablePaymentMethodTypes,
  ~primaryTheme,
  ~handleSubmit,
  ~tabsView,
  ~defaultOptionsLimitInTabLayout=defaultOptionsLimitInTabLayout,
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
  // let (validityDict, setValidityDict) = Recoil.useRecoilState(validityDictAtom)

  // Component states
  let (orderedPmts, setOrderedPmts): (
    array<paymentMethodType>,
    (array<paymentMethodType> => array<paymentMethodType>) => unit,
  ) = React.useState(_ => availablePaymentMethodTypes)
  let (formSubmitted, setFormSubmitted) = React.useState(_ => false)

  // Views history
  module View = {
    let viewStack = React.useRef([tabsView])
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
      viewStack.current->Array.get(viewStack.current->Array.length - 1)->Option.getOr(tabsView)
    let (view, setViewState) = React.useState(_ => get())
    // For setting and popping views
    let setView = view => {
      setViewState(_ => {
        push(view)
        view
      })
    }
    let popView = (~count=1) => {
      setViewState(_ => {
        for _ in 1 to count {
          pop()
        }
        get()
      })
    }
  }

  React.useEffect(() => {
    availablePaymentMethodTypes
    ->Array.get(0)
    ->Option.map(pmt => setActivePmt(_ => pmt))
    ->ignore
    setOrderedPmts(_ => availablePaymentMethodTypes)
    None
  }, [availablePaymentMethodTypes])

  let handleTabSelection = newPmtStr => {
    orderedPmts
    ->Array.find(pmt => pmt->getPaymentMethodTypeLabel === newPmtStr)
    ->Option.map(newPmt => {
      if orderedPmts->Array.indexOf(newPmt) >= defaultOptionsLimitInTabLayout {
        // Move the selected payment method at the last tab position
        let ordList = availablePaymentMethodTypes->Array.reduceWithIndex([], (acc, pmt, i) => {
          if i === defaultOptionsLimitInTabLayout - 1 {
            acc->Array.push(newPmt)
          }
          if pmt !== newPmt {
            acc->Array.push(pmt)
          }
          acc
        })
        setOrderedPmts(_ => ordList)
      }
      setActivePmt(_ => newPmt)
      newPmt
    })
    ->ignore
  }

  let renderSaveButton = onClickHandler =>
    <button
      className="min-w-full mt-10 text-lg font-semibold px-2.5 py-1.5 text-white rounded"
      style={backgroundColor: primaryTheme}
      onClick=onClickHandler>
      {React.string(localeString.formSaveText)}
    </button>

  let renderPmtTabs = activePmt => {
    let key = activePmt->getPaymentMethodTypeLabel
    let activeStyles: JsxDOM.style = {
      borderColor: primaryTheme,
      borderWidth: "2px",
      color: primaryTheme,
    }
    let defaultStyles: JsxDOM.style = {
      borderColor: "#9A9FA8",
      borderWidth: "1px",
      color: primaryTheme,
    }
    let hiddenTabs = orderedPmts->Array.reduceWithIndex([], (options, pmt, i) => {
      if i >= defaultOptionsLimitInTabLayout {
        let key = pmt->getPaymentMethodTypeLabel
        options->Array.push(
          <option
            key={i->Int.toString} value={key} className="text-black bg-white hover:bg-gray-100">
            {React.string(key)}
          </option>,
        )
      }
      options
    })
    let visibleTabs = orderedPmts->Array.reduceWithIndex([], (items, pmt, i) => {
      if i < defaultOptionsLimitInTabLayout {
        let key = pmt->getPaymentMethodTypeLabel
        items->Array.push(
          <div
            key={i->Int.toString}
            onClick={_ => handleTabSelection(key)}
            className="flex w-full items-center rounded border-0 px-2.5 py-1.5 mr-2.5 cursor-pointer hover:bg-jp-gray-50"
            style={key === activePmt->getPaymentMethodTypeLabel ? activeStyles : defaultStyles}>
            {pmt->getPaymentMethodTypeIcon}
            <div className="ml-2.5"> {React.string(key)} </div>
          </div>,
        )
      }
      items
    })
    <div className="flex flex-row w-full">
      {visibleTabs->React.array}
      {<RenderIf condition={orderedPmts->Array.length > defaultOptionsLimitInTabLayout}>
        <div className="relative">
          <Icon
            className="absolute z-10 pointer translate-x-2.5 translate-y-3.5 pointer-events-none"
            name="arrow-down"
            size=10
          />
          <select
            value=key
            onChange={ev => handleTabSelection(ReactEvent.Form.target(ev)["value"])}
            className="h-full relative rounded border border-solid border-jp-gray-700 py-1.5 cursor-pointer bg-white text-transparent w-8 hover:bg-jp-gray-50">
            {<option key value=key disabled={true}> {React.string(key)} </option>}
            {hiddenTabs->React.array}
          </select>
        </div>
      </RenderIf>}
    </div>
  }

  let renderInfoTemplate = (label, value, uniqueKey) => {
    let labelClasses = "w-4/10 text-jp-gray-800 text-sm min-w-40 text-end"
    let valueClasses = "w-6/10 text-sm min-w-40"
    <div key={uniqueKey} className="flex flex-row items-center">
      <div className={labelClasses}> {React.string(label)} </div>
      <div className="mx-2.5 h-4 w-0.5 bg-jp-gray-300"> {React.string("")} </div>
      <div className={valueClasses}> {React.string(value)} </div>
    </div>
  }

  <div className="w-full max-w-[520px]">
    {switch View.view {
    /// SCREEN #1 - FORM DATA COLLECTION
    | DetailsForm => {
        let contentHeaderClasses = "text-xl lg:text-2xl font-semibold mt-5"
        let key = activePmt->getPaymentMethodTypeLabel

        let onSaveHandler = () => {
          let (fieldValidity, isAddressValid) =
            payoutDynamicFields.address
            ->Option.map(addressFields => {
              addressFields->Array.reduce((Dict.make(), true), (
                (fieldValidity, isAddressValid),
                field,
              ) => {
                let key = BillingAddress(field.fieldType)->getPaymentMethodDataFieldKey
                let value = formData->Dict.get(key)->Option.getOr("")
                let validity =
                  BillingAddress(field.fieldType)->calculateValidity(
                    value,
                    "",
                    ~default=Some(false),
                  )
                fieldValidity->Dict.set(key, validity)
                (fieldValidity, isAddressValid && validity != Some(false))
              })
            })
            ->Option.getOr((validityDict->Dict.copy, true))

          let (fieldValidity, isPmdValid) = payoutDynamicFields.payoutMethodData->Array.reduce(
            (fieldValidity, isAddressValid),
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
            ->Option.map(pmd => View.setView(FinalizeView(activePmt, pmd)))
            ->ignore
          }
        }

        <div>
          {renderPmtTabs(activePmt)}
          <div className={contentHeaderClasses}>
            {switch activePmt {
            | Card(_) => localeString.formHeaderEnterCardText
            | BankRedirect(_)
            | BankTransfer(_) =>
              key->localeString.formHeaderBankText
            | Wallet(_) => key->localeString.formHeaderWalletText
            }->React.string}
          </div>
          {payoutDynamicFields.payoutMethodData->renderPayoutMethodForm->React.array}
          {payoutDynamicFields.address
          ->Option.map(addressFields => {
            let fieldsToCollect =
              addressFields->Array.filter(addressField => addressField.value == None)
            if fieldsToCollect->Array.length > 0 {
              let formFields = addressFields->renderAddressForm
              <>
                <div className={`mb-2.5 ${contentHeaderClasses}`}>
                  {React.string(localeString.billingDetailsText)}
                </div>
                {formFields->React.array}
              </>
            } else {
              React.null
            }
          })
          ->Option.getOr(React.null)}
          {renderSaveButton(_ => onSaveHandler())}
        </div>
      }

    /// SCREEN #2 - FINALIZE VIEW
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
              onClick={_ => View.popView()}
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
