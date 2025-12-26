open RecoilAtoms
open PaymentType
open Utils
open PaymentTypeContext

type addressType = Line1 | Line2 | City | Postal | State | Country

let getShowType = str => {
  switch str {
  | "auto" => Auto
  | "never" => Never
  | _ => Auto
  }
}

let showField = (val: PaymentType.addressType, type_: addressType) => {
  switch val {
  | JSONString(str) => getShowType(str)
  | JSONObject(address) =>
    switch type_ {
    | Line1 => address.line1
    | Line2 => address.line2
    | City => address.city
    | Postal => address.postal_code
    | State => address.state
    | Country => address.country
    }
  }
}

@react.component
let make = (~className="", ~paymentType: option<CardThemeType.mode>=?) => {
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let showDetails = getShowDetails(~billingDetails=fields.billingDetails)
  let contextPaymentType = usePaymentType()
  let paymentType = paymentType->Option.getOr(contextPaymentType)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let (line1, setLine1) = Recoil.useRecoilState(userAddressline1)
  let (line2, setLine2) = Recoil.useRecoilState(userAddressline2)
  let (country, setCountry) = Recoil.useRecoilState(userAddressCountry)
  let (city, setCity) = Recoil.useRecoilState(userAddressCity)
  let (postalCode, setPostalCode) = Recoil.useRecoilState(userAddressPincode)
  let (state, setState) = Recoil.useRecoilState(userAddressState)

  let line1Ref = React.useRef(Nullable.null)
  let line2Ref = React.useRef(Nullable.null)
  let cityRef = React.useRef(Nullable.null)
  let postalRef = React.useRef(Nullable.null)

  let (showOtherFileds, setShowOtherFields) = React.useState(_ => false)

  let stateNames = getStateNames(country)
  let countryData = CountryStateDataRefs.countryDataRef.contents
  let countryNames = getCountryNames(countryData)

  let checkPostalValidity = (
    postal: RecoilAtomTypes.field,
    setPostal: (RecoilAtomTypes.field => RecoilAtomTypes.field) => unit,
  ) => {
    if postal.value !== "" {
      setPostal(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else {
      setPostal(prev => {
        ...prev,
        isValid: Some(false),
        errorString: localeString.postalCodeInvalidText,
      })
    }
  }

  let onPostalChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    setPostalCode(prev => {
      ...prev,
      value: val,
      errorString: "",
    })
  }

  let onPostalBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    if val !== "" {
      setPostalCode(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else {
      setPostalCode(prev => {
        ...prev,
        isValid: Some(false),
        errorString: localeString.postalCodeInvalidText,
      })
    }
  }

  React.useEffect(() => {
    checkPostalValidity(postalCode, setPostalCode)
    setState(prev => {
      ...prev,
      value: "",
    })

    None
  }, [country.value])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit && !isGiftCardOnlyPayment {
      if line1.value == "" {
        setLine1(prev => {
          ...prev,
          errorString: localeString.line1EmptyText,
        })
      }
      if line2.value == "" {
        setLine2(prev => {
          ...prev,
          errorString: localeString.line2EmptyText,
        })
      }
      if state.value == "" {
        setState(prev => {
          ...prev,
          errorString: localeString.stateEmptyText,
        })
      }
      if postalCode.value == "" {
        setPostalCode(prev => {
          ...prev,
          errorString: localeString.postalCodeEmptyText,
        })
      }
      if city.value == "" {
        setCity(prev => {
          ...prev,
          errorString: localeString.cityEmptyText,
        })
      }
    }
  }, (line1, line2, country, state, city, postalCode, isGiftCardOnlyPayment))
  useSubmitPaymentData(submitCallback)

  let hasDefaulltValues =
    line2.value !== "" || city.value !== "" || postalCode.value !== "" || state.value !== ""

  <div className="flex flex-col" style={gridGap: themeObj.spacingGridColumn}>
    <RenderIf condition={showField(showDetails.address, Line1) == Auto}>
      <PaymentField
        fieldName=localeString.line1Label
        setValue={setLine1}
        value=line1
        onChange={ev => {
          setShowOtherFields(_ => true)
          setLine1(prev => {
            ...prev,
            value: ReactEvent.Form.target(ev)["value"],
          })
        }}
        type_="text"
        name="line1"
        className
        inputRef=line1Ref
        placeholder=localeString.line1Placeholder
        paymentType
      />
    </RenderIf>
    <RenderIf condition={showOtherFileds || hasDefaulltValues}>
      <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingGridColumn}>
        <RenderIf condition={showField(showDetails.address, Line2) == Auto}>
          <PaymentField
            fieldName=localeString.line2Label
            setValue={setLine2}
            value=line2
            onChange={ev => {
              setLine2(prev => {
                ...prev,
                value: ReactEvent.Form.target(ev)["value"],
              })
            }}
            type_="text"
            name="line2"
            className
            inputRef=line2Ref
            placeholder=localeString.line2Placeholder
            paymentType
          />
        </RenderIf>
        <div className="flex flex-row" style={gridGap: themeObj.spacingGridRow}>
          <RenderIf condition={showField(showDetails.address, Country) == Auto}>
            <PaymentDropDownField
              fieldName=localeString.countryLabel
              value=country
              className
              setValue=setCountry
              options=countryNames
            />
          </RenderIf>
          <RenderIf
            condition={showField(showDetails.address, State) == Auto &&
              stateNames->Array.length > 0}>
            <PaymentDropDownField
              fieldName=localeString.stateLabel
              value=state
              className
              setValue=setState
              options={stateNames}
            />
          </RenderIf>
        </div>
        <div className="flex flex-row" style={gridGap: themeObj.spacingGridRow}>
          <RenderIf condition={showField(showDetails.address, City) == Auto}>
            <PaymentField
              fieldName=localeString.cityLabel
              setValue={setCity}
              className
              value=city
              onChange={ev => {
                setCity(prev => {
                  ...prev,
                  value: ReactEvent.Form.target(ev)["value"],
                })
              }}
              type_="text"
              name="city"
              inputRef=cityRef
              placeholder=localeString.cityLabel
              paymentType
            />
          </RenderIf>
          <RenderIf condition={showField(showDetails.address, Postal) == Auto}>
            <PaymentField
              fieldName=localeString.postalCodeLabel
              setValue={setPostalCode}
              value=postalCode
              onBlur=onPostalBlur
              onChange=onPostalChange
              className
              name="postal"
              inputRef=postalRef
              placeholder=localeString.postalCodeLabel
              paymentType
            />
          </RenderIf>
        </div>
      </div>
    </RenderIf>
  </div>
}
