open RecoilAtoms
@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~cardProps,
  ~expiryProps,
  ~cvcProps,
  ~zipProps,
  ~handleElementFocus,
  ~blurState,
  ~isFocus,
) => {
  let {showLoader} = Recoil.useRecoilValueFromAtom(configAtom)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (
    isCardValid,
    setIsCardValid,
    _,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    _,
    _,
    _,
    maxCardLength,
    _,
  ) = cardProps

  let (
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    _,
    _,
    _,
  ) = expiryProps

  let (
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    _,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    _,
    _,
    _,
  ) = cvcProps

  let blur = blurState ? "blur(2px)" : ""
  let frameRef = React.useRef(Nullable.null)
  <div
    className={`flex flex-col justify-between `}
    style={
      color: themeObj.colorText,
      background: "transparent",
      marginLeft: "4px",
      marginRight: "4px",
      marginTop: "4px",
      fontFamily: themeObj.fontFamily,
      fontSize: themeObj.fontSizeBase,
      filter: blur,
    }
    dir=localeString.localeDirection>
    <div
      ref={frameRef->ReactDOM.Ref.domRef}
      className={`m-auto flex justify-center md:h-auto  w-full h-auto `}>
      <div className="w-full font-medium">
        {switch paymentType {
        | Card =>
          <ReusableReactSuspense
            loaderComponent={<RenderIf condition={showLoader}>
              <CardElementShimmer />
            </RenderIf>}
            componentName="SingleLineCardPaymentLazy">
            <SingleLineCardPaymentLazy
              paymentType cardProps expiryProps cvcProps zipProps handleElementFocus isFocus
            />
          </ReusableReactSuspense>
        | GooglePayElement
        | PayPalElement
        | ApplePayElement
        | KlarnaElement
        | ExpressCheckoutElement
        | Payment =>
          <ReusableReactSuspense
            loaderComponent={<RenderIf condition={showLoader}>
              {paymentType->Utils.getIsWalletElementPaymentType
                ? <WalletShimmer />
                : <PaymentElementShimmer />}
            </RenderIf>}
            componentName="PaymentElementRendererLazy">
            <PaymentElementRendererLazy paymentType cardProps expiryProps cvcProps />
          </ReusableReactSuspense>
        | CardNumberElement =>
          <InputField
            isValid=isCardValid
            setIsValid=setIsCardValid
            value=cardNumber
            onChange=changeCardNumber
            onBlur=handleCardBlur
            onFocus=handleElementFocus
            type_="tel"
            maxLength=maxCardLength
            paymentType
            inputRef=cardRef
            placeholder="1234 1234 1234 1234"
            id="card-number"
            isFocus
          />
        | CardExpiryElement =>
          <InputField
            isValid=isExpiryValid
            setIsValid=setIsExpiryValid
            value=cardExpiry
            onChange=changeCardExpiry
            onBlur=handleExpiryBlur
            onFocus=handleElementFocus
            type_="tel"
            paymentType
            maxLength=7
            inputRef=expiryRef
            placeholder=localeString.expiryPlaceholder
            id="card-expiry"
            isFocus
          />
        | CardCVCElement =>
          <InputField
            isValid=isCVCValid
            setIsValid=setIsCVCValid
            value=cvcNumber
            onChange=changeCVCNumber
            onBlur=handleCVCBlur
            onFocus=handleElementFocus
            paymentType
            type_="tel"
            className={`tracking-widest w-auto`}
            maxLength=4
            inputRef=cvcRef
            placeholder="123"
            id="card-cvc"
            isFocus
          />
        | PaymentMethodsManagement =>
          <ReusableReactSuspense
            loaderComponent={<RenderIf condition={showLoader}>
              <PaymentElementShimmer />
            </RenderIf>}
            componentName="PaymentManagementLazy">
            <PaymentManagementLazy />
          </ReusableReactSuspense>
        | PaymentMethodCollectElement
        | NONE => React.null
        }}
      </div>
    </div>
  </div>
}
