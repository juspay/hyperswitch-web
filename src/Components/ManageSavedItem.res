open RecoilAtoms

@react.component
let make = (
  ~paymentItem: UnifiedPaymentsTypesV2.customerMethods,
  ~managePaymentMethod,
  ~isCardExpired,
  ~expiryMonth,
  ~expiryYear,
) => {
  let (_, startTransition) = React.useTransition()
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {innerLayout} = config.appearance
  let setFullName = Recoil.useSetRecoilState(userFullName)
  let setNickName = Recoil.useSetRecoilState(userCardNickName)

  let cardHolderName = switch paymentItem.paymentMethodData.card.cardHolderName {
  | Some(val) => val
  | _ => ""
  }

  let nickname = switch paymentItem.paymentMethodData.card.nickname {
  | Some(val) => val
  | _ => ""
  }

  React.useEffect(() => {
    startTransition(() => {
      setFullName(prev => Utils.validateName(cardHolderName, prev, localeString))
      setNickName(prev => Utils.setNickNameState(nickname, prev, localeString))
    })
    None
  }, [])

  <div
    className="flex flex-col gap-3 items-stretch animate-slowShow"
    style={
      minWidth: "150px",
      width: "100%",
      padding: "0 0 1rem 0",
      borderBottom: managePaymentMethod === paymentItem.paymentToken
        ? `1px solid ${themeObj.borderColor}`
        : "none",
      borderTop: "none",
      borderLeft: "none",
      borderRight: "none",
      borderRadius: "0px",
      background: "transparent",
      color: themeObj.colorTextSecondary,
      boxShadow: "none",
      opacity: {isCardExpired ? "0.7" : "1"},
    }>
    <div
      className="flex flex-row w-full place-content-between"
      style={
        gridColumnGap: {innerLayout === Spaced ? themeObj.spacingGridRow : ""},
      }>
      <div className={innerLayout === Spaced ? "w-[70%]" : "w-[50%]"}>
        <PaymentInputField
          fieldName=localeString.cardNumberLabel
          value={`**** **** **** ${paymentItem.paymentMethodData.card.last4Digits}`}
          onChange={_ => ()}
          paymentType=CardThemeType.Card
          type_="tel"
          inputRef={React.useRef(Nullable.null)}
          name=TestUtils.cardNoInputTestId
          isDisabled=true
        />
      </div>
      <div className={innerLayout === Spaced ? "w-[30%]" : "w-[50%]"}>
        <PaymentInputField
          fieldName=localeString.validThruText
          value={`${expiryMonth} / ${expiryYear->CardUtils.formatExpiryToTwoDigit}`}
          onChange={_ => ()}
          paymentType=CardThemeType.Card
          type_="tel"
          inputRef={React.useRef(Nullable.null)}
          placeholder=localeString.expiryPlaceholder
          name=TestUtils.expiryInputTestId
          isDisabled=true
        />
      </div>
    </div>
    <FullNamePaymentInput customFieldName=Some(localeString.cardHolderName) />
    <NicknamePaymentInput />
  </div>
}
