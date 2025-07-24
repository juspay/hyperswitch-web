type oneClickWallets = {
  paymentMethodType: string,
  displayName: string,
}
let oneClickWallets = (~localeString: LocaleStringTypes.localeStrings) => [
  {
    paymentMethodType: "apple_pay",
    displayName: localeString.payment_methods_apple_pay,
  },
  {
    paymentMethodType: "samsung_pay",
    displayName: localeString.payment_methods_samsung_pay,
  },
  {
    paymentMethodType: "paypal",
    displayName: localeString.payment_methods_paypal,
  },
  {
    paymentMethodType: "google_pay",
    displayName: localeString.payment_methods_google_pay,
  },
  {paymentMethodType: "klarna", displayName: localeString.payment_methods_klarna},
]

type walletSurchargeDetails = {
  name: string,
  surchargeDetails: PaymentMethodsRecord.surchargeDetails,
}

let useSurchargeDetailsForOneClickWallets = (~paymentMethodListValue) => {
  let areOneClickWalletsRendered = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.areOneClickWalletsRendered,
  )
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  React.useMemo(() => {
    oneClickWallets(~localeString)->Array.reduce([], (acc, wallet) => {
      let (isWalletBtnRendered, paymentMethod) = switch wallet.paymentMethodType {
      | "apple_pay" => (areOneClickWalletsRendered.isApplePay, "wallet")
      | "samsung_pay" => (areOneClickWalletsRendered.isSamsungPay, "wallet")
      | "paypal" => (areOneClickWalletsRendered.isPaypal, "wallet")
      | "google_pay" => (areOneClickWalletsRendered.isGooglePay, "wallet")
      | "klarna" => (areOneClickWalletsRendered.isKlarna, "pay_later")
      | _ => (false, "")
      }
      if isWalletBtnRendered {
        let paymentMethodType =
          PaymentMethodsRecord.getPaymentMethodTypeFromList(
            ~paymentMethodListValue,
            ~paymentMethod,
            ~paymentMethodType=wallet.paymentMethodType,
          )->Option.getOr(PaymentMethodsRecord.defaultPaymentMethodType)
        switch paymentMethodType.surcharge_details {
        | Some(surchargDetails) =>
          acc->Array.concat([
            {
              name: wallet.displayName,
              surchargeDetails: surchargDetails,
            },
          ])
        | None => acc
        }
      } else {
        acc
      }
    })
  }, (areOneClickWalletsRendered, paymentMethodListValue))
}

let useMessageGetter = () => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {showShortSurchargeMessage} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  let getMessage = (
    ~surchargeDetails: PaymentMethodsRecord.surchargeDetails,
    ~paymentMethod,
    ~paymentMethodListValue: PaymentMethodsRecord.paymentMethodList,
  ) => {
    let currency = paymentMethodListValue.currency
    let surchargeValue = surchargeDetails.displayTotalSurchargeAmount->Float.toString

    if showShortSurchargeMessage {
      Some(localeString.shortSurchargeMessage(currency, surchargeValue))
    } else {
      let message = if paymentMethod === "card" {
        localeString.surchargeMsgAmountForCard(currency, surchargeValue)
      } else {
        localeString.surchargeMsgAmount(currency, surchargeValue)
      }

      Some(message)
    }
  }
  getMessage
}

let useOneClickWalletsMessageGetter = (~paymentMethodListValue) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let oneClickWalletsArr = useSurchargeDetailsForOneClickWallets(~paymentMethodListValue)

  let getOneClickWalletsMessage = () => {
    if oneClickWalletsArr->Array.length !== 0 {
      let msg = oneClickWalletsArr->Array.reduceWithIndex(React.null, (acc, wallet, index) => {
        let amount = wallet.surchargeDetails.displayTotalSurchargeAmount->Float.toString
        let myMsg =
          <>
            <strong> {React.string(`${paymentMethodListValue.currency} ${amount}`)} </strong>
            {React.string(`${Utils.nbsp}${localeString.on} ${wallet.name}`)}
          </>
        let msgToConcat = if index === 0 {
          myMsg
        } else if index === oneClickWalletsArr->Array.length - 1 {
          <>
            {React.string(`${Utils.nbsp}${localeString.\"and"}${Utils.nbsp}`)}
            {myMsg}
          </>
        } else {
          <>
            {React.string(`,${Utils.nbsp}`)}
            {myMsg}
          </>
        }
        <>
          {acc}
          {msgToConcat}
        </>
      })
      let finalElement =
        <>
          {React.string(`${localeString.surchargeMsgAmountForOneClickWallets}:${Utils.nbsp}`)}
          {msg}
        </>
      Some(finalElement)
    } else {
      None
    }
  }

  getOneClickWalletsMessage
}
