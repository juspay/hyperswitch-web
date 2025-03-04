@react.component
let make = (~mode) => {
  open RecoilAtoms
  open Utils

  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced
  let spacedStylesForBiilingDetails = isSpacedInnerLayout ? "p-2" : "my-2"
  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)
  let addressOptions = Recoil.useRecoilValueFromAtom(addressElementOptions)
  let (fullName, setFullName) = Recoil.useLoggedRecoilState(userFullName, "fullName", logger)
  let (email, setEmail) = Recoil.useLoggedRecoilState(userEmailAddress, "email", logger)
  let (phone, setPhone) = Recoil.useLoggedRecoilState(userPhoneNumber, "phone", logger)

  let (line1, setLine1) = Recoil.useLoggedRecoilState(userAddressline1, "line1", logger)
  let (line2, setLine2) = Recoil.useLoggedRecoilState(userAddressline2, "line2", logger)
  let (city, setCity) = Recoil.useLoggedRecoilState(userAddressCity, "city", logger)
  let (state, setState) = Recoil.useLoggedRecoilState(userAddressState, "state", logger)
  let (postalCode, setPostalCode) = Recoil.useLoggedRecoilState(
    userAddressPincode,
    "postal_code",
    logger,
  )

  let (country, setCountry) = Recoil.useLoggedRecoilState(userCountry, "country", logger)
  let countryArr = Country.country->Array.map(item => item.countryName)
  let updatedCountryArray = countryArr->DropdownField.updateArrayOfStringToOptionsTypeArray
  let (stateJson, setStatesJson) = React.useState(_ => None)
  let (complete, setComplete) = React.useState(_ => "false")
  let line1Ref = React.useRef(Nullable.null)
  let line2Ref = React.useRef(Nullable.null)
  let cityRef = React.useRef(Nullable.null)
  let postalRef = React.useRef(Nullable.null)

  let isFieldOptional = field => Array.includes(addressOptions.optional, field)

  React.useEffect0(() => {
    open Promise
    AddressPaymentInput.importStates("./States.json")
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

  let checkFieldCompletion = () => {
    let isNameComplete = isFieldOptional("full_name") ? true : fullName.value !== ""
    let isEmailComplete = isFieldOptional("email") ? true : email.value !== ""
    let isPhoneComplete = isFieldOptional("phone") ? true : phone.value !== ""
    let isLine1Complete = isFieldOptional("line1") ? true : line1.value !== ""
    let isLine2Complete = isFieldOptional("line2") ? true : line2.value !== ""
    let isCityComplete = isFieldOptional("city") ? true : city.value !== ""
    let isStateComplete = isFieldOptional("state") ? true : state.value !== ""
    let isPostalComplete = isFieldOptional("postal_code") ? true : postalCode.value !== ""
    let isCountryComplete = isFieldOptional("country") ? true : country !== ""

    setComplete(_ =>
      isNameComplete &&
      isEmailComplete &&
      isPhoneComplete &&
      isLine1Complete &&
      isLine2Complete &&
      isCityComplete &&
      isStateComplete &&
      isPostalComplete &&
      isCountryComplete
        ? "true"
        : "false"
    )
  }

  let checkRequiredFields = () => {
    if line1.value == "" && !isFieldOptional("line1") {
      setLine1(prev => {
        ...prev,
        errorString: prev.errorString === ""
          ? localeString.nameEmptyText("Address line 1")
          : prev.errorString,
      })
    }
    if line2.value == "" && !isFieldOptional("line2") {
      setLine2(prev => {
        ...prev,
        errorString: prev.errorString === ""
          ? localeString.nameEmptyText("Address line 2")
          : prev.errorString,
      })
    }
    if state.value == "" && !isFieldOptional("state") {
      setState(prev => {
        ...prev,
        errorString: prev.errorString === ""
          ? localeString.nameEmptyText("State name")
          : prev.errorString,
      })
    }
    if postalCode.value == "" && !isFieldOptional("postal_code") {
      setPostalCode(prev => {
        ...prev,
        errorString: prev.errorString === ""
          ? localeString.nameEmptyText("postal code")
          : prev.errorString,
      })
    }
    if city.value == "" && !isFieldOptional("city") {
      setCity(prev => {
        ...prev,
        errorString: prev.errorString === ""
          ? localeString.nameEmptyText("City name")
          : prev.errorString,
      })
    }
    if email.value == "" && !isFieldOptional("email") {
      setEmail(prev => {
        ...prev,
        errorString: prev.errorString === ""
          ? localeString.nameEmptyText("Email")
          : prev.errorString,
      })
    }
    if fullName.value == "" && !isFieldOptional("full_name") {
      setFullName(prev => {
        ...prev,
        errorString: prev.errorString === ""
          ? localeString.nameEmptyText("Full name")
          : prev.errorString,
      })
    }
    if phone.value == "" && !isFieldOptional("phone") {
      setPhone(prev => {
        ...prev,
        errorString: localeString.nameEmptyText("Phone number"),
      })
    }
    if country == "" && !isFieldOptional("country") {
      setPhone(prev => {
        ...prev,
        errorString: localeString.nameEmptyText("Country"),
      })
    }
  }

  let getAddressDetails = () => {
    let (firstName, lastName) = fullName.value->Utils.getFirstAndLastNameFromFullName
    let addressDetails: PaymentType.addressData = {
      complete: complete == "true",
      data: {
        first_name: firstName->getStringFromJson(""),
        last_name: lastName->getStringFromJson(""),
        line1: line1.value,
        line2: line2.value,
        city: city.value,
        state: state.value,
        postal_code: postalCode.value,
        country,
        email: email.value,
        phone: phone.value,
        country_code: phone.countryCode->Option.getOr(""),
      },
    }
    addressDetails
  }

  React.useEffect(() => {
    checkFieldCompletion()
    None
  }, [
    fullName.value,
    email.value,
    phone.value,
    line1.value,
    line2.value,
    city.value,
    state.value,
    postalCode.value,
  ])

  React.useEffect0(() => {
    Utils.messageParentWindow([("id", iframeId->JSON.Encode.string)])
    None
  })

  React.useEffect(() => {
    let handleFun = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("getBillingAddress")->Option.isSome && mode === "billing" {
        let currentAddressDetails = getAddressDetails()
        checkRequiredFields()
        Utils.messageParentWindow([
          ("billingAddressDetails", currentAddressDetails->Identity.anyTypeToJson),
        ])
      } else if dict->Dict.get("getShippingAddress")->Option.isSome && mode === "shipping" {
        let currentAddressDetails = getAddressDetails()
        checkRequiredFields()
        Utils.messageParentWindow([
          ("shippingAddressDetails", currentAddressDetails->Identity.anyTypeToJson),
        ])
      }
    }

    handleMessage(handleFun, "Error in parsing sent Data")
  }, [
    line1.value,
    line2.value,
    city.value,
    state.value,
    postalCode.value,
    country,
    email.value,
    phone.value,
    fullName.value,
    complete,
  ])

  let onPostalChange = ev => {
    let val = ReactEvent.Form.target(ev)["value"]

    if val !== "" {
      setPostalCode(_ => {
        isValid: Some(true),
        value: val,
        errorString: "",
      })
    } else {
      setPostalCode(_ => {
        isValid: Some(false),
        value: val,
        errorString: "",
      })
    }
  }

  <>
    <div
      className={`billing-section ${spacedStylesForBiilingDetails} w-full text-left`}
      style={
        border: {isSpacedInnerLayout ? `1px solid ${themeObj.borderColor}` : ""},
        borderRadius: {isSpacedInnerLayout ? themeObj.borderRadius : ""},
      }>
      <div
        className="billing-details-text"
        style={
          marginBottom: "5px",
          fontSize: themeObj.fontSizeLg,
          opacity: "0.6",
          textTransform: "capitalize",
        }>
        {React.string(mode ++ " details")}
      </div>
      <div
        className={`flex flex-col`}
        style={
          gap: isSpacedInnerLayout ? themeObj.spacingGridRow : "",
        }>
        // Full Name
        <FullNamePaymentInput paymentType={Payment} isOptional={isFieldOptional("full_name")} />
        // Address Line 1
        <PaymentField
          fieldName={`${localeString.line1Label} ${isFieldOptional("line1") ? "(Optional)" : ""}`}
          setValue={setLine1}
          value=line1
          onChange={ev => {
            let value = ReactEvent.Form.target(ev)["value"]
            setLine1(prev => {
              isValid: Some(value !== ""),
              value,
              errorString: value !== "" ? "" : prev.errorString,
            })
          }}
          onBlur={ev => {
            let value = ReactEvent.Focus.target(ev)["value"]
            setLine1(prev => {
              ...prev,
              isValid: Some(value !== ""),
            })
          }}
          paymentType={Payment}
          type_="text"
          name="line1"
          inputRef=line1Ref
          placeholder=localeString.line1Placeholder
          className={isSpacedInnerLayout ? "" : "!border-b-0"}
        />
        //Address Line 2
        <PaymentField
          fieldName={`${localeString.line2Label} ${isFieldOptional("line2") ? "(Optional)" : ""}`}
          setValue={setLine2}
          value=line2
          onChange={ev => {
            let value = ReactEvent.Form.target(ev)["value"]
            setLine2(prev => {
              isValid: Some(value !== ""),
              value,
              errorString: value !== "" ? "" : prev.errorString,
            })
          }}
          onBlur={ev => {
            let value = ReactEvent.Focus.target(ev)["value"]
            setLine2(prev => {
              ...prev,
              isValid: Some(value !== ""),
            })
          }}
          paymentType={Payment}
          type_="text"
          name="line2"
          inputRef=line2Ref
          placeholder={"Apt., unit number, etc"}
        />
        // State and City
        <div className={`flex ${isSpacedInnerLayout ? "gap-4" : ""} overflow-hidden`}>
          <PaymentField
            fieldName={`${localeString.cityLabel} ${isFieldOptional("city") ? "(Optional)" : ""}`}
            setValue={setCity}
            value=city
            onChange={ev => {
              let value = ReactEvent.Form.target(ev)["value"]
              setCity(prev => {
                isValid: Some(value !== ""),
                value,
                errorString: value !== "" ? "" : prev.errorString,
              })
            }}
            onBlur={ev => {
              let value = ReactEvent.Focus.target(ev)["value"]
              setCity(prev => {
                ...prev,
                isValid: Some(value !== ""),
              })
            }}
            paymentType={Payment}
            type_="text"
            name="city"
            inputRef=cityRef
            placeholder=localeString.cityLabel
            className={isSpacedInnerLayout ? "" : "!border-r-0"}
          />
          {switch stateJson {
          | Some(options) =>
            <PaymentDropDownField
              fieldName={`${localeString.stateLabel} ${isFieldOptional("state")
                  ? "(Optional)"
                  : ""}`}
              value=state
              setValue=setState
              options={options->getStateNames({
                value: country,
                isValid: None,
                errorString: "",
              })}
            />
          | None => React.null
          }}
        </div>
        // Country and Pincode
        <div className={`flex ${isSpacedInnerLayout ? "gap-4" : ""}`}>
          <DropdownField
            appearance=config.appearance
            fieldName={`${localeString.countryLabel} ${isFieldOptional("country")
                ? "(Optional)"
                : ""}`}
            value=country
            setValue={setCountry}
            disabled=false
            options=updatedCountryArray
            className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
          />
          <PaymentField
            fieldName={`${localeString.postalCodeLabel} ${isFieldOptional("postal_code")
                ? "(Optional)"
                : ""}`}
            setValue={setPostalCode}
            value=postalCode
            onBlur={ev => {
              let value = ReactEvent.Focus.target(ev)["value"]
              setPostalCode(prev => {
                ...prev,
                isValid: Some(value !== ""),
              })
            }}
            onChange=onPostalChange
            paymentType={Payment}
            name="postal"
            inputRef=postalRef
            placeholder=localeString.postalCodeLabel
            className={isSpacedInnerLayout ? "" : "!border-t-0"}
          />
        </div>
        // Phone Number
        <PhoneNumberPaymentInput isOptional={isFieldOptional("phone")} />
        // Email
        <EmailPaymentInput paymentType={Payment} isOptional={isFieldOptional("email")} />
      </div>
    </div>
  </>
}
