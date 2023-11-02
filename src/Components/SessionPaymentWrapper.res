@react.component
let make = (~children, ~type_: SessionsType.paymentType) => {
  let sessions = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)

  let loader = switch type_ {
  | Others => <PaymentShimmer />
  | Wallet => <WalletShimmer />
  }

  switch sessions {
  | Loading => loader
  | _ => children
  }
}
