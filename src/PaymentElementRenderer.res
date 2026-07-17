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
  let sdkConfigs = Recoil.useRecoilValueFromAtom(sdkConfigs)
  let paymentManagementList = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.paymentManagementList)
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

  let divRef = React.useRef(Nullable.null)

  let isLoading = switch (paymentType, paymentMethodList, sdkConfigs, paymentManagementList) {
  | (Payment, Loading, _, _)
  | (Payment, _, Loading, _)
  | (PaymentMethodsManagement, _, _, LoadingV2) => true
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
    | _ =>
      // clientList and sdkConfigs are both critical APIs on this V1 payment path.
      // If either fails, render a single error in place of PaymentElement, so the
      // error never coexists with PaymentElement's own shimmer/form. Scoped to
      // this branch so it can never gate the V2 (PaymentElementV2) path, which
      // has its own critical API (paymentManagementList) and error handling.
      switch (paymentMethodList, sdkConfigs) {
      | (LoadError(_), _)
      | (_, LoadError(_)) =>
        <ErrorBoundary.ErrorTextAndImage divRef level={ErrorBoundary.Top} />
      | _ => <PaymentElement cardProps expiryProps cvcProps paymentType />
      }
    }
  }
}

let default = make
