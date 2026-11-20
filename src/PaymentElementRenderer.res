open JotaiAtoms
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
  let {showLoader} = Jotai.useAtomValue(configAtom)
  let paymentMethodList = Jotai.useAtomValue(paymentMethodList)
  let sdkConfigs = Jotai.useAtomValue(sdkConfigs)
  let paymentManagementList = Jotai.useAtomValue(JotaiAtomsV2.paymentManagementList)
  let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let logger = Jotai.useAtomValue(loggerAtom)
  let setFullName = Jotai.useSetAtom(userFullName)
  let setNickName = Jotai.useSetAtom(userCardNickName)
  let (_, startTransition) = React.useTransition()

  React.useEffect(() => {
    startTransition(() => {
      setFullName(prev => Utils.validateName("", prev, localeString))
      setNickName(prev => Utils.setNickNameState("", prev, localeString))
    })
    None
  }, [])

  let divRef = React.useRef(Nullable.null)

  let loadingReason = switch (paymentType, paymentMethodList, sdkConfigs, paymentManagementList) {
  | (Payment, Loading, _, _) => Some("payment_methods")
  | (Payment, _, Loading, _) => Some("sdk_configs")
  | (PaymentMethodsManagement, _, _, LoadingV2) => Some("payment_management_list")
  | _ => None
  }
  let isLoading = loadingReason->Option.isSome

  React.useEffect(() => {
    switch loadingReason {
    | Some(reason) if showLoader && logger !== LoggerUtils.defaultLoggerConfig =>
      LoggerUtils.logElementLoading(~logger, ~reason)
    | _ => ()
    }
    None
  }, (loadingReason, showLoader, logger))

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
