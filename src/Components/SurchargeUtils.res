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

let useSurchargeDetailsForOneClickWallets = (~list) => {
  let areOneClickWalletsRendered = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.areOneClickWalletsRendered,
  )

  React.useMemo(() => {
    oneClickWallets->Array.reduce([], (acc, wallet) => {
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
  }, (areOneClickWalletsRendered, list))
}

let useMessageGetter = () => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let getMessage = (
    ~surchargeDetails: PaymentMethodsRecord.surchargeDetails,
    ~paymentMethod,
    ~list: PaymentMethodsRecord.list,
  ) => {
    let surchargeValue = surchargeDetails.displayTotalSurchargeAmount->Float.toString

    let localeStrForSurcharge = if paymentMethod === "card" {
      localeString.surchargeMsgAmountForCard(list.currency, surchargeValue)
    } else {
      localeString.surchargeMsgAmount(list.currency, surchargeValue)
    }

    Some(localeStrForSurcharge)
  }

  getMessage
}

let useOneClickWalletsMessageGetter = (~list) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let oneClickWalletsArr = useSurchargeDetailsForOneClickWallets(~list)

  let getOneClickWalletsMessage = () => {
    if oneClickWalletsArr->Array.length !== 0 {
      let msg = oneClickWalletsArr->Array.reduceWithIndex(React.null, (acc, wallet, index) => {
        let amount = wallet.surchargeDetails.displayTotalSurchargeAmount->Float.toString
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
