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
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
  let paymentMethodsListV2 = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentMethodsListV2)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let setFullName = Recoil.useSetRecoilState(userFullName)
  let setNickName = Recoil.useSetRecoilState(userCardNickName)
  let (_, startTransition) = React.useTransition()

  React.useEffect(() => {
    startTransition(() => {
      setFullName(prev => Utils.validateName("", prev, localeString))
      setNickName(prev => Utils.setNickNameState("", prev, localeString))
    })
    None
  }, [])

  let isLoading = switch (
    GlobalVars.sdkVersion,
    paymentType,
    paymentMethodList,
    paymentManagementList,
    paymentMethodsListV2,
  ) {
  | (V1, Payment, Loading, _, _)
  | (V2, PaymentMethodsManagement, _, LoadingV2, _)
  | (V2, Payment, _, _, LoadingV2) => true
  | _ => false
  }

  let isWalletElement = paymentType->Utils.checkIsWalletElement

  if isLoading {
    <RenderIf condition=showLoader>
      {isWalletElement ? <WalletShimmer /> : <PaymentElementShimmer />}
    </RenderIf>
  } else if isWalletElement {
    <WalletElement paymentType />
  } else {
    switch GlobalVars.sdkVersion {
    | V2 => <PaymentElementV2 cardProps expiryProps cvcProps paymentType />
    | V1 => <PaymentElement cardProps expiryProps cvcProps paymentType />
    }
  }
}

let default = make
