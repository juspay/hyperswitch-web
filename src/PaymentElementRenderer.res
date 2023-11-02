let cardsToRender = width => {
  (width - 40) / 110
}
open RecoilAtoms
@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~cardProps,
  ~expiryProps,
  ~cvcProps,
  ~countryProps,
) => {
  let {showLoader} = Recoil.useRecoilValueFromAtom(configAtom)
  let sessions = Recoil.useRecoilValueFromAtom(sessions)
  let list = Recoil.useRecoilValueFromAtom(list)
  switch (sessions, list) {
  | (_, Loading) => <RenderIf condition=showLoader> <PaymentElementShimmer /> </RenderIf>
  | _ => <PaymentElement cardProps expiryProps cvcProps countryProps paymentType />
  }
}

let default = make
