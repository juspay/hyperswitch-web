open RecoilAtoms
open Utils
open PaymentModeType

@react.component
let make = (~paymentType: CardThemeType.mode, ~list: PaymentMethodsRecord.list) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)

  let (bankError, setBankError) = React.useState(_ => "")

  let (openToolTip, setOpenToolTip) = React.useState(_ => false)

  let (modalData, setModalData) = React.useState(_ => None)

  let toolTipRef = React.useRef(Js.Nullable.null)
  let (line1, _) = Recoil.useLoggedRecoilState(userAddressline1, "line1", loggerState)
  let (line2, _) = Recoil.useLoggedRecoilState(userAddressline2, "line2", loggerState)
  let (country, _) = Recoil.useLoggedRecoilState(userAddressCountry, "country", loggerState)
  let (city, _) = Recoil.useLoggedRecoilState(userAddressCity, "city", loggerState)
  let (postalCode, _) = Recoil.useLoggedRecoilState(userAddressPincode, "postal_code", loggerState)
  let (state, _) = Recoil.useLoggedRecoilState(userAddressState, "state", loggerState)

  OutsideClick.useOutsideClick(
    ~refs=ArrayOfRef([toolTipRef]),
    ~isActive=openToolTip,
    ~callback=() => {
      setOpenToolTip(_ => false)
    },
    (),
  )

  React.useEffect1(() => {
    if modalData->Belt.Option.isSome {
      setBankError(_ => "")
    }
    None
  }, [modalData])

  let complete =
    email.value != "" &&
    fullName.value != "" &&
    email.isValid->Belt.Option.getWithDefault(false) &&
    modalData->Belt.Option.isSome
  let empty = email.value == "" || fullName.value != ""

  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="ach_bank_debit", ~loggerState)
    None
  }, (empty, complete))

  let submitCallback = React.useCallback3((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if modalData->Belt.Option.isNone {
        setBankError(_ => "Enter bank details and then confirm payment")
      }
      if complete {
        switch modalData {
        | Some(data) =>
          let body = PaymentBody.achBankDebitBody(
            ~email=email.value,
            ~bank=data,
            ~cardHolderName=fullName.value,
            ~line1=line1.value,
            ~line2=line2.value,
            ~country=getCountryCode(country.value).isoAlpha2,
            ~city=city.value,
            ~postalCode=postalCode.value,
            ~state=state.value,
            ~paymentType=list.payment_type,
          )
          intent(~bodyArr=body, ~confirmParam=confirm.confirmParams, ~handleUserError=false, ())
        | None => ()
        }
        ()
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, modalData, fullName))
  submitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
    <FullNamePaymentInput paymentType={paymentType} />
    <EmailPaymentInput paymentType />
    <div className="flex flex-col">
      <AddBankAccount modalData setModalData />
      <RenderIf condition={bankError->Js.String2.length > 0}>
        <div
          className="Error pt-1"
          style={ReactDOMStyle.make(
            ~color=themeObj.colorDangerText,
            ~fontSize=themeObj.fontSizeSm,
            ~alignSelf="start",
            ~textAlign="left",
            (),
          )}>
          {React.string(bankError)}
        </div>
      </RenderIf>
    </div>
    <Surcharge list paymentMethod="bank_debit" paymentMethodType="ach" />
    <Terms mode=ACHBankDebit />
    <FullScreenPortal>
      <BankDebitModal setModalData />
    </FullScreenPortal>
  </div>
}

let default = make
