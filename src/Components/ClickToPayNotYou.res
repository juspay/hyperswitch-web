open ClickToPayHelpers
open Utils

@react.component
let make = (~setIsShowClickToPayNotYou, ~isCTPAuthenticateNotYouClicked, ~getVisaCards) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (clickToPayConfig, setClickToPayConfig) = Recoil.useRecoilState(RecoilAtoms.clickToPayConfig)

  let (identifier, setIdentifier) = React.useState(_ => "")
  let (isValid, setIsValid) = React.useState(_ => false)
  let (identifierType, setIdentifierType) = React.useState(_ => EMAIL_ADDRESS)

  let updateCtpNotYouState = consumerIdentity => {
    setClickToPayConfig(prev => {
      ...prev,
      clickToPayCards: Some([]),
    })
    setClickToPayConfig(prev => {
      ...prev,
      consumerIdentity,
    })
    setIsShowClickToPayNotYou(_ => false)
  }

  let onContinue = consumerIdentity => {
    open Promise
    switch clickToPayConfig.clickToPayProvider {
    | MASTERCARD =>
      ClickToPayHelpers.signOut()
      ->finally(() => {
        updateCtpNotYouState(consumerIdentity)
      })
      ->catch(err => resolve(Error(err)))
      ->ignore
    | VISA =>
      updateCtpNotYouState(consumerIdentity)

      (
        async _ => {
          setClickToPayConfig(prev => {
            ...prev,
            visaComponentState: CARDS_LOADING,
          })
          try {
            let _ = await signOutVisaUnified()
            await getVisaCards(
              ~identityValue=consumerIdentity.identityValue,
              ~otp="",
              ~identityType=consumerIdentity.identityType,
            )
          } catch {
          | _ =>
            setClickToPayConfig(prev => {
              ...prev,
              visaComponentState: NONE,
            })
          }
        }
      )()->ignore
    | NONE => ()
    }
  }

  let onBack = _ => {
    setIsShowClickToPayNotYou(_ => false)
  }

  let countryAndCodeCodeList =
    phoneNumberJson
    ->JSON.Decode.object
    ->Option.getOr(Dict.make())
    ->getArray("countries")

  let countryCodes = countryAndCodeCodeList->Array.map(countryObj => {
    let countryObjDict = countryObj->getDictFromJson
    let countryCode = countryObjDict->getString("phone_number_code", "")
    let countryName = countryObjDict->getString("country_code", "")
    {code: countryCode, countryISO: countryName}
  })

  let (countryCode, setCountryCode) = React.useState(() =>
    (countryCodes->Array.get(0)->Option.getOr(defaultCountry)).countryISO
  )

  let validateIdentifier = (value, identityType: identityType) => {
    let emailRegex = %re("/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/")
    let phoneRegex = %re("/^\d{6,14}$/")

    switch identityType {
    | EMAIL_ADDRESS => emailRegex->RegExp.test(value)
    | MOBILE_PHONE_NUMBER => phoneRegex->RegExp.test(value)
    }
  }

  let formatPhoneNumber: string => string = value => {
    if String.startsWith(value, "+") {
      if String.includes(value, " ") {
        value
      } else {
        String.replaceRegExp(value, %re("/^\+(\d{1,3})(\d+)$/"), "+$1 $2")
      }
    } else if String.match(value, %re("/^\d+$/"))->Option.isSome {
      `+${value}`
    } else {
      value
    }
  }

  let handleInputChange = ev => {
    let target = ev->ReactEvent.Form.target
    let newValue = target["value"]
    let formattedValue =
      identifierType === MOBILE_PHONE_NUMBER ? newValue->formatPhoneNumber : newValue
    setIdentifier(_ => formattedValue)
  }

  let handleTypeChange = ev => {
    let target = ev->ReactEvent.Form.target
    let newValue = target["value"]
    setIdentifierType(_ => newValue)
    setIdentifier(_ => "") // Clear the input when changing type
  }

  let handleCountryCodeChange = ev => {
    let target = ev->ReactEvent.Form.target
    let newValue = target["value"]
    setCountryCode(_ => newValue)
  }

  let handlePhoneInputChange = ev => {
    let target = ev->ReactEvent.Form.target
    let newValue = target["value"]->String.replaceRegExp(%re("/\\D/g"), "") // Remove non-digit characters
    setIdentifier(_ => newValue)
  }

  React.useEffect(() => {
    setIsValid(_ => validateIdentifier(identifier, identifierType))
    None
  }, (identifier, identifierType))

  let handleSubmit = e => {
    e->ReactEvent.Form.preventDefault
    if isValid {
      let country =
        countryCodes
        ->Array.find(country => countryCode === country.countryISO)
        ->Option.getOr(defaultCountry)
      let submittedIdentifier =
        identifierType === MOBILE_PHONE_NUMBER
          ? String.sliceToEnd(country.code, ~start=1) ++ " " ++ identifier
          : identifier
      onContinue({identityValue: submittedIdentifier, identityType: identifierType})
    }
  }

  let _maskedEmail = (~onNotYouClick) => {
    <div className="flex space-x-2 text-sm text-[#484848]">
      <button
        onClick={onNotYouClick} className="underline cursor-pointer [text-underline-offset:0.2rem]">
        {React.string("Not you?")}
      </button>
    </div>
  }

  <div className="p-4 bg-white rounded-lg border border-[#E6E1E1] flex flex-col space-y-4">
    <div className="flex flex-col">
      <RenderIf condition={!isCTPAuthenticateNotYouClicked}>
        <button onClick={onBack}>
          <Icon name="arrow-back" size=16 />
        </button>
      </RenderIf>
      <div className="flex justify-center items-center">
        <div>
          <ClickToPayHelpers.SrcMark
            cardBrands={clickToPayConfig.availableCardBrands->Array.join(",")} height="32"
          />
        </div>
      </div>
    </div>
    <div className="flex flex-col justify-center items-center space-y-4 px-4">
      <p className="text-sm font-normal">
        {React.string(
          "Enter a new email or mobile number to access a different set of linked cards.",
        )}
      </p>
      <form
        onSubmit={handleSubmit}
        className="w-full flex flex-col justify-center items-center space-y-4">
        <div className="w-full flex space-x-2">
          <div className="relative w-1/3">
            <select
              value={identifierType->getIdentityType}
              onChange={handleTypeChange}
              className="w-full p-3 pr-10 border border-gray-300 rounded-md appearance-none">
              <option value={EMAIL_ADDRESS->getIdentityType}> {React.string("Email")} </option>
              <option value={MOBILE_PHONE_NUMBER->getIdentityType}>
                {React.string("Phone")}
              </option>
            </select>
            <div
              className="absolute inset-y-0 right-4 flex items-center selection:pointer-events-none">
              <Icon
                className="absolute z-10 pointer pointer-events-none" name="arrow-down" size=10
              />
            </div>
          </div>
          {identifierType === EMAIL_ADDRESS
            ? <input
                type_="text"
                value={identifier}
                onChange={handleInputChange}
                placeholder="Enter email"
                className="w-2/3 p-3 border border-gray-300 rounded-md"
                required=true
              />
            : <div className="w-2/3 flex border border-gray-300 rounded-md overflow-hidden">
                <div className="relative">
                  <select
                    value={countryCode}
                    onChange={handleCountryCodeChange}
                    className="h-full p-3 appearance-none focus:outline-none">
                    {countryCodes
                    ->Array.map(country =>
                      <option
                        key={`${country.code}-${country.countryISO}`} value={country.countryISO}>
                        {React.string(`${country.countryISO} ${country.code}`)}
                      </option>
                    )
                    ->React.array}
                  </select>
                  <div
                    className="absolute inset-y-0 right-4 flex items-center selection:pointer-events-none">
                    <Icon
                      className="absolute z-10 pointer pointer-events-none"
                      name="arrow-down"
                      size=10
                    />
                  </div>
                </div>
                <input
                  type_="tel"
                  value={identifier}
                  onChange={handlePhoneInputChange}
                  placeholder="Mobile number"
                  className="flex-grow p-3 focus:outline-none w-full"
                  required=true
                />
              </div>}
        </div>
        <button
          type_="submit"
          className={`w-full p-3 ${isValid ? "" : "opacity-50 cursor-not-allowed"}`}
          style={
            backgroundColor: themeObj.buttonBackgroundColor,
            color: themeObj.buttonTextColor,
            borderRadius: themeObj.buttonBorderRadius,
            fontSize: themeObj.buttonTextFontSize,
          }
          disabled={!isValid}>
          {React.string("Switch ID")}
        </button>
      </form>
    </div>
  </div>
}

module ClickToPayNotYouText = {
  @react.component
  let make = (~setIsShowClickToPayNotYou) => {
    let onNotYouClick = _ => {
      setIsShowClickToPayNotYou(_ => true)
    }

    <div className="flex space-x-2 text-sm text-[#484848]">
      <button
        onClick={onNotYouClick} className="underline cursor-pointer [text-underline-offset:0.2rem]">
        {React.string("Not you?")}
      </button>
    </div>
  }
}
