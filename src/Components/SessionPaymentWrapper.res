@react.component
let make = (~children, ~type_: SessionsType.paymentType) => {
  let sessions = Jotai.useAtomValue(JotaiAtoms.sessions)

  let loader = switch type_ {
  | Others => <PaymentShimmer />
  | Wallet => <WalletShimmer />
  }

  switch sessions {
  | Loading => loader
  | _ => children
  }
}
