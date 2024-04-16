open RecoilAtoms
@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
) => {
  let _cardsToRender = width => {
    (width - 40) / 110
  }
  let {showLoader} = Recoil.useRecoilValueFromAtom(configAtom)
  let sessions = Recoil.useRecoilValueFromAtom(sessions)
  let list = Recoil.useRecoilValueFromAtom(list)
  switch (sessions, list) {
  | (_, Loading) =>
    <RenderIf condition=showLoader>
      <PaymentElementShimmer />
    </RenderIf>
  | _ => <PaymentElement cardProps expiryProps cvcProps paymentType />
  }
}

let default = make
