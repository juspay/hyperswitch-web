open RecoilAtoms
open PaymentType
open Utils

type addressType = Line1 | Line2 | City | Postal | State | Country

type dataModule = {states: JSON.t}

@val
external importStates: string => Promise.t<dataModule> = "import"

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
let make = (~paymentType, ~className="") => {
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let showDetails = getShowDetails(~billingDetails=fields.billingDetails, ~logger=loggerState)

  let (line1, setLine1) = Recoil.useLoggedRecoilState(userAddressline1, "line1", loggerState)
  let (line2, setLine2) = Recoil.useLoggedRecoilState(userAddressline2, "line2", loggerState)
  let (country, setCountry) = Recoil.useLoggedRecoilState(
    userAddressCountry,
    "country",
    loggerState,
  )
  let (city, setCity) = Recoil.useLoggedRecoilState(userAddressCity, "city", loggerState)
  let (postalCode, setPostalCode) = Recoil.useLoggedRecoilState(
    userAddressPincode,
    "postal_code",
    loggerState,
  )
  let (state, setState) = Recoil.useLoggedRecoilState(userAddressState, "state", loggerState)

  let line1Ref = React.useRef(Nullable.null)
  let line2Ref = React.useRef(Nullable.null)
  let cityRef = React.useRef(Nullable.null)
  let postalRef = React.useRef(Nullable.null)

  let (postalCodes, setPostalCodes) = React.useState(_ => [PostalCodeType.defaultPostalCode])
  let (stateJson, setStatesJson) = React.useState(_ => None)
  let (showOtherFileds, setShowOtherFields) = React.useState(_ => false)

  let countryNames = getCountryNames(Country.country)

  let checkPostalValidity = (
    postal: RecoilAtomTypes.field,
    setPostal: (
      OrcaPaymentPage.RecoilAtomTypes.field => OrcaPaymentPage.RecoilAtomTypes.field
    ) => unit,
    regex,
  ) => {
    if RegExp.test(regex->RegExp.fromString, postal.value) && postal.value !== "" && regex !== "" {
      setPostal(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else if (
      regex !== "" && !RegExp.test(regex->RegExp.fromString, postal.value) && postal.value !== ""
    ) {
      setPostal(prev => {
        ...prev,
        isValid: Some(false),
        errorString: localeString.postalCodeInvalidText,
      })
    }
  }

  React.useEffect0(() => {
    open Promise
    // Dynamically import/download Postal codes and states JSON
    PostalCodeType.importPostalCode("./../PostalCodes.bs.js")
    ->then(res => {
      setPostalCodes(_ => res.default)
      resolve()
    })
    ->catch(_ => {
      setPostalCodes(_ => [PostalCodeType.defaultPostalCode])
      resolve()
    })
    ->ignore
    importStates("./../States.json")
    ->then(res => {
      setStatesJson(_ => Some(res.states))
      resolve()
    })
    ->catch(_ => {
      setStatesJson(_ => None)
      resolve()
    })
    ->ignore

    None
  })

  let regex = CardUtils.postalRegex(
    postalCodes,
    ~country={getCountryCode(country.value).isoAlpha2},
    (),
  )

  let onPostalChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]

    setPostalCode(prev => {
      ...prev,
      value: val,
      errorString: "",
    })
    if regex !== "" && RegExp.test(regex->RegExp.fromString, val) {
      CardUtils.blurRef(postalRef)
    }
  }

  let onPostalBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]
    if regex !== "" && RegExp.test(regex->RegExp.fromString, val) && val !== "" {
      setPostalCode(prev => {
        ...prev,
        isValid: Some(true),
        errorString: "",
      })
    } else if regex !== "" && !RegExp.test(regex->RegExp.fromString, val) && val !== "" {
      setPostalCode(prev => {
        ...prev,
        isValid: Some(false),
        errorString: localeString.postalCodeInvalidText,
      })
    }
  }

  React.useEffect(() => {
    checkPostalValidity(postalCode, setPostalCode, regex)
    None
  }, (regex, country.value))

  React.useEffect(() => {
    setState(prev => {
      ...prev,
      value: "",
    })

    None
  }, [country.value])

  let submitCallback = React.useCallback6((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
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
  }, (line1, line2, country, state, city, postalCode))
  useSubmitPaymentData(submitCallback)

  let hasDefaulltValues =
    line2.value !== "" || city.value !== "" || postalCode.value !== "" || state.value !== ""

  <div
    className="flex flex-col" style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
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
        paymentType
        type_="text"
        name="line1"
        className
        inputRef=line1Ref
        placeholder=localeString.line1Placeholder
      />
    </RenderIf>
    <RenderIf condition={showOtherFileds || hasDefaulltValues}>
      <div
        className="flex flex-col animate-slowShow"
        style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
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
            paymentType
            type_="text"
            name="line2"
            className
            inputRef=line2Ref
            placeholder=localeString.line2Placeholder
          />
        </RenderIf>
        <div
          className="flex flex-row"
          style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridRow, ())}>
          <RenderIf condition={showField(showDetails.address, Country) == Auto}>
            <PaymentDropDownField
              fieldName=localeString.countryLabel
              value=country
              className
              setValue=setCountry
              options=countryNames
            />
          </RenderIf>
          <RenderIf condition={showField(showDetails.address, State) == Auto}>
            {switch stateJson {
            | Some(options) =>
              <PaymentDropDownField
                fieldName=localeString.stateLabel
                value=state
                className
                setValue=setState
                options={options->getStateNames(country)}
              />
            | None => React.null
            }}
          </RenderIf>
        </div>
        <div
          className="flex flex-row"
          style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridRow, ())}>
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
              paymentType
              type_="text"
              name="city"
              inputRef=cityRef
              placeholder=localeString.cityLabel
            />
          </RenderIf>
          <RenderIf condition={showField(showDetails.address, Postal) == Auto}>
            <PaymentField
              fieldName=localeString.postalCodeLabel
              setValue={setPostalCode}
              value=postalCode
              onBlur=onPostalBlur
              onChange=onPostalChange
              paymentType
              className
              name="postal"
              inputRef=postalRef
              placeholder=localeString.postalCodeLabel
            />
          </RenderIf>
        </div>
      </div>
    </RenderIf>
  </div>
}
