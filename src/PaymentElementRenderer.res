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
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let setFullName = Recoil.useLoggedSetRecoilState(userFullName, "fullName", loggerState)
  let setNickName = Recoil.useSetRecoilState(userCardNickName)
  let (_, startTransition) = React.useTransition()

  React.useEffect(() => {
    startTransition(() => {
      setFullName(prev => Utils.validateName("", prev, localeString))
      setNickName(prev => Utils.setNickNameState("", prev, localeString))
    })
    None
  }, [])

  switch GlobalVars.sdkVersionEnum {
  | V2 =>
    switch (sessions, paymentManagementList) {
    | (_, LoadingV2) =>
      <RenderIf condition=showLoader>
        {paymentType->Utils.getIsWalletElementPaymentType
          ? <WalletShimmer />
          : <PaymentElementShimmer />}
      </RenderIf>
    | _ =>
      paymentType->Utils.getIsWalletElementPaymentType
        ? <WalletElement paymentType />
        : <PaymentElementV2 cardProps expiryProps cvcProps paymentType />
    }
  | V1 =>
    switch (sessions, paymentMethodList) {
    | (_, Loading) =>
      <RenderIf condition=showLoader>
        {paymentType->Utils.getIsWalletElementPaymentType
          ? <WalletShimmer />
          : <PaymentElementShimmer />}
      </RenderIf>
    | _ =>
      paymentType->Utils.getIsWalletElementPaymentType
        ? <WalletElement paymentType />
        : <PaymentElement cardProps expiryProps cvcProps paymentType />
    }
  }
}

let default = make
