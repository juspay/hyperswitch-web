open RecoilAtoms
open Utils

let cleanSocialSecurityNumber = socialSecurityNumber =>
  socialSecurityNumber->String.replaceRegExp(%re("/\D+/g"), "")

let formatSocialSecurityNumber = socialSecurityNumber => {
  let formatted = socialSecurityNumber->cleanSocialSecurityNumber
  let firstPart = formatted->CardUtils.slice(0, 3)
  let secondPart = formatted->CardUtils.slice(3, 6)
  let thirdPart = formatted->CardUtils.slice(6, 9)
  let fourthPart = formatted->CardUtils.slice(9, 11)

  if formatted->String.length <= 3 {
    firstPart
  } else if formatted->String.length > 3 && formatted->String.length <= 6 {
    `${firstPart}.${secondPart}`
  } else if formatted->String.length > 6 && formatted->String.length <= 9 {
    `${firstPart}.${secondPart}.${thirdPart}`
  } else {
    `${firstPart}.${secondPart}.${thirdPart}-${fourthPart}`
  }
}

@react.component
let make = (~paymentType: CardThemeType.mode, ~list: PaymentMethodsRecord.list) => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let (socialSecurityNumber, setSocialSecurityNumber) = React.useState(_ => "")

  let (socialSecurityNumberError, setSocialSecurityNumberError) = React.useState(_ => "")

  let socialSecurityNumberRef = React.useRef(Nullable.null)

  let (complete, empty) = React.useMemo1(() => {
    (
      socialSecurityNumber->cleanSocialSecurityNumber->String.length == 11,
      socialSecurityNumber->String.length == 0,
    )
  }, [socialSecurityNumber])

  React.useEffect(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="boleto", ~loggerState)
    None
  }, (complete, empty))

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if complete {
        let body = PaymentBody.boletoBody(
          ~socialSecurityNumber=socialSecurityNumber->String.replaceRegExp(%re("/\D+/g"), ""),
        )
        intent(
          ~bodyArr=body,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~iframeId,
          (),
        )
        ()
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, [socialSecurityNumber])
  useSubmitPaymentData(submitCallback)

  let changeSocialSecurityNumber = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    setSocialSecurityNumberError(_ => "")
    setSocialSecurityNumber(_ => val->formatSocialSecurityNumber)
  }
  let socialSecurityNumberBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]->cleanSocialSecurityNumber
    if val->String.length != 11 && val->String.length > 0 {
      setSocialSecurityNumberError(_ => "The social security number entered is invalid.")
    }
  }

  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
    <PaymentInputField
      fieldName=localeString.socialSecurityNumberLabel
      value=socialSecurityNumber
      onChange=changeSocialSecurityNumber
      paymentType
      errorString=socialSecurityNumberError
      isValid={socialSecurityNumberError == "" ? None : Some(false)}
      type_="tel"
      appearance=config.appearance
      maxLength=14
      onBlur=socialSecurityNumberBlur
      inputRef=socialSecurityNumberRef
      placeholder="000.000.000-00"
    />
    <Surcharge list paymentMethod="voucher" paymentMethodType="boleto" />
    <InfoElement />
  </div>
}

let default = make
