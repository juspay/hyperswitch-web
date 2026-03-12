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
  let {showLoader} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let paymentMethodList = Jotai.useAtomValue(JotaiAtoms.paymentMethodList)
  let paymentManagementList = Jotai.useAtomValue(JotaiAtomsV2.paymentManagementList)
  let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let setFullName = Jotai.useSetAtom(JotaiAtoms.userFullName)
  let setNickName = Jotai.useSetAtom(JotaiAtoms.userCardNickName)
  let (_, startTransition) = React.useTransition()

  React.useEffect(() => {
    startTransition(() => {
      setFullName(prev => Utils.validateName("", prev, localeString))
      setNickName(prev => Utils.setNickNameState("", prev, localeString))
    })
    None
  }, [])

  let isLoading = switch (paymentType, paymentMethodList, paymentManagementList) {
  | (Payment, Loading, _)
  | (PaymentMethodsManagement, _, LoadingV2) => true
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
    switch paymentType {
    | PaymentMethodsManagement => <PaymentElementV2 cardProps expiryProps cvcProps paymentType />
    | _ => <PaymentElement cardProps expiryProps cvcProps paymentType />
    }
  }
}

let default = make
