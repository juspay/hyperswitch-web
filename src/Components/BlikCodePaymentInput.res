open RecoilAtoms
open Utils

@react.component
let make = () => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let (blikCode, setblikCode) = Recoil.useLoggedRecoilState(userBlikCode, "blikCode", loggerState)

  let blikCodeRef = React.useRef(Nullable.null)
  let formatBSB = bsb => {
    let formatted = bsb->String.replaceRegExp(%re("/\D+/g"), "")
    let firstPart = formatted->CardUtils.slice(0, 3)
    let secondPart = formatted->CardUtils.slice(3, 6)

    if formatted->String.length <= 3 {
      firstPart
    } else if formatted->String.length > 3 && formatted->String.length <= 6 {
      `${firstPart}-${secondPart}`
    } else {
      formatted
    }
  }

  let changeblikCode = ev => {
    let val: string = ReactEvent.Form.target(ev)["value"]
    setblikCode(prev => {
      ...prev,
      value: val->formatBSB,
    })
  }

  React.useEffect(() => {
    setblikCode(prev => {
      ...prev,
      errorString: switch prev.isValid {
      | Some(val) => val ? "" : "Invalid blikCode"
      | None => ""
      },
    })
    None
  }, [blikCode.isValid])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if blikCode.value == "" {
        setblikCode(prev => {
          ...prev,
          errorString: "blikCode cannot be empty",
        })
      }
    }
  }, [blikCode])
  useSubmitPaymentData(submitCallback)

  <RenderIf condition={true}>
    <PaymentField
      fieldName="Blik code"
      setValue={setblikCode}
      value=blikCode
      onChange=changeblikCode
      paymentType=Payment
      type_="blikCode"
      name="blikCode"
      inputRef=blikCodeRef
      placeholder="000 000"
      maxLength=7
    />
  </RenderIf>
}
