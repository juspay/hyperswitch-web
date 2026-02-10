open RecoilAtoms
@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~zipProps: CardUtils.zipProps,
  ~handleElementFocus,
  ~blurState,
  ~isFocus,
) => {
  let {showLoader} = Recoil.useRecoilValueFromAtom(configAtom)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {
    isCardValid,
    setIsCardValid,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    maxCardLength,
  } = cardProps

  let {
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
  } = expiryProps

  let {isCVCValid, setIsCVCValid, cvcNumber, changeCVCNumber, handleCVCBlur, cvcRef} = cvcProps

  let blur = blurState ? "blur(2px)" : ""
  let frameRef = React.useRef(Nullable.null)
  <div
    className={`flex flex-col justify-between PaymentMethodContainer`}
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
        | SamsungPayElement
        | KlarnaElement
        | PazeElement
        | ExpressCheckoutElement
        | Payment =>
          <ReusableReactSuspense
            loaderComponent={<RenderIf condition={showLoader}>
              {paymentType->Utils.checkIsWalletElement
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
            inputRef=cardRef
            placeholder="1234 1234 1234 1234"
            id="card-number-input"
            isFocus
            autocomplete="cc-number"
            ariaPlaceholder=""
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
            maxLength=7
            inputRef=expiryRef
            placeholder=localeString.expiryPlaceholder
            id="card-expiry-input"
            isFocus
            autocomplete="cc-exp"
          />
        | CardCVCElement =>
          <InputField
            isValid=isCVCValid
            setIsValid=setIsCVCValid
            value=cvcNumber
            onChange=changeCVCNumber
            onBlur=handleCVCBlur
            onFocus=handleElementFocus
            type_="tel"
            className={`tracking-widest w-auto`}
            maxLength=4
            inputRef=cvcRef
            placeholder="123"
            id="card-cvc-input"
            isFocus
            autocomplete="cc-csc"
            ariaPlaceholder=""
          />
        | PaymentMethodsManagement =>
          <ReusableReactSuspense
            loaderComponent={<RenderIf condition={showLoader}>
              <PaymentElementShimmer />
            </RenderIf>}
            componentName="PaymentManagementLazy">
            <PaymentManagementLazy paymentType cardProps cvcProps expiryProps />
          </ReusableReactSuspense>
        | PaymentMethodCollectElement
        | NONE => React.null
        }}
      </div>
    </div>
  </div>
}
