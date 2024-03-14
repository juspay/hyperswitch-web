open RecoilAtoms
open Utils

let cleanSocialSecurityNumber = socialSecurityNumber =>
  socialSecurityNumber->Js.String2.replaceByRe(%re("/\D+/g"), "")

let formatSocialSecurityNumber = socialSecurityNumber => {
  let formatted = socialSecurityNumber->cleanSocialSecurityNumber
  let firstPart = formatted->CardUtils.slice(0, 3)
  let secondPart = formatted->CardUtils.slice(3, 6)
  let thirdPart = formatted->CardUtils.slice(6, 9)
  let fourthPart = formatted->CardUtils.slice(9, 11)

  if formatted->Js.String2.length <= 3 {
    firstPart
  } else if formatted->Js.String2.length > 3 && formatted->Js.String2.length <= 6 {
    `${firstPart}.${secondPart}`
  } else if formatted->Js.String2.length > 6 && formatted->Js.String2.length <= 9 {
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

  let socialSecurityNumberRef = React.useRef(Js.Nullable.null)

  let (complete, empty) = React.useMemo1(() => {
    (
      socialSecurityNumber->cleanSocialSecurityNumber->Js.String2.length == 11,
      socialSecurityNumber->Js.String2.length == 0,
    )
  }, [socialSecurityNumber])

  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="boleto", ~loggerState)
    None
  }, (complete, empty))

  React.useEffect1(() => {
    setComplete(._ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback1((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if complete {
        let body = PaymentBody.boletoBody(
          ~socialSecurityNumber=socialSecurityNumber->Js.String2.replaceByRe(%re("/\D+/g"), ""),
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
    if val->Js.String2.length != 11 && val->Js.String2.length > 0 {
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
