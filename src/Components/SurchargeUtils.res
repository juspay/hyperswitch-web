type oneClickWallets = {
  paymentMethodType: string,
  displayName: string,
}
let oneClickWallets = [
  {paymentMethodType: "apple_pay", displayName: "ApplePay"},
  {paymentMethodType: "paypal", displayName: "Paypal"},
  {paymentMethodType: "google_pay", displayName: "GooglePay"},
]

type walletSurchargeDetails = {
  name: string,
  surchargeDetails: PaymentMethodsRecord.surchargeDetails,
}

let getSurchargeDetailsForOneClickWallets = (~list) => {
  let areOneClickWalletsRendered = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.areOneClickWalletsRendered,
  )

  oneClickWallets->Js.Array2.reduce((acc, wallet) => {
    let isWalletBtnRendered = switch wallet.paymentMethodType {
    | "apple_pay" => areOneClickWalletsRendered.isApplePay
    | "paypal" => areOneClickWalletsRendered.isPaypal
    | "google_pay" => areOneClickWalletsRendered.isGooglePay
    | _ => false
    }
    if isWalletBtnRendered {
      let paymentMethodType =
        PaymentMethodsRecord.getPaymentMethodTypeFromList(
          ~list,
          ~paymentMethod="wallet",
          ~paymentMethodType=wallet.paymentMethodType,
        )->Belt.Option.getWithDefault(PaymentMethodsRecord.defaultPaymentMethodType)
      switch paymentMethodType.surcharge_details {
      | Some(surchargDetails) =>
        acc->Js.Array2.concat([
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
  }, [])
}

let getMessage = (
  ~surchargeDetails: PaymentMethodsRecord.surchargeDetails,
  ~paymentMethod,
  ~list: PaymentMethodsRecord.list,
) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let surchargeValue = surchargeDetails.displayTotalSurchargeAmount->Js.Float.toString

  let getLocaleStrForSurcharge = (cardLocale, altPaymentLocale) => {
    paymentMethod === "card"
      ? cardLocale(list.currency, surchargeValue)
      : altPaymentLocale(list.currency, surchargeValue)
  }

  Some(
    getLocaleStrForSurcharge(
      localeString.surchargeMsgAmountForCard,
      localeString.surchargeMsgAmount,
    ),
  )
}

let getOneClickWalletsMessage = (~list) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let oneClickWalletsArr = getSurchargeDetailsForOneClickWallets(~list)

  if oneClickWalletsArr->Js.Array2.length !== 0 {
    let msg = oneClickWalletsArr->Js.Array2.reducei((acc, wallet, index) => {
      let amount = wallet.surchargeDetails.displayTotalSurchargeAmount->Js.Float.toString
      let myMsg =
        <>
          <strong> {React.string(`${list.currency} ${amount}`)} </strong>
          {React.string(`${Utils.nbsp}${localeString.on} ${wallet.name}`)}
        </>
      let msgToConcat = if index === 0 {
        myMsg
      } else if index === oneClickWalletsArr->Belt.Array.length - 1 {
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
    }, React.null)
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
