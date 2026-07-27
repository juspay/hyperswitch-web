open Utils

// Hyperswitch-vault card collector. Public card flows are hosted by
// ParentCardComponent; this component only validates and tokenises fields inside
// the nested paymentMethodsSDK iframe. It reports private, non-sensitive field
// state to the host; the host is the single owner of merchant-facing events.
@react.component
let make = (
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let vaultCredentials = Recoil.useRecoilValueFromAtom(RecoilAtoms.vaultCredentials)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let {parentURL} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let {
    isCardValid,
    isCardSupported,
    cardNumber,
    setCardError,
    cardBrand,
    eligibilitySurchargeDetails,
    isEligibilityPending,
  } = cardProps
  let {isExpiryValid, cardExpiry, setExpiryError} = expiryProps
  let {isCVCValid, cvcNumber, setCvcError} = cvcProps

  let complete = isAllValid(
    isCardValid,
    isCardSupported,
    isCVCValid,
    isExpiryValid,
    true,
    "payment",
  )
  let empty = cardNumber === "" || cardExpiry === "" || cvcNumber === ""
  let _ = CardCollectorBridge.useEmitCardState(
    ~cardNumber,
    ~cardExpiry,
    ~cvcNumber,
    ~cardBrand,
    ~complete,
    ~empty,
    ~isCardValid,
    ~isExpiryValid,
    ~isCvcValid=isCVCValid,
  )

  let reportCardFieldErrors = () => {
    CardCollectorBridge.reportValidationErrors(
      ~cardNumber,
      ~cardExpiry,
      ~cvcNumber,
      ~cardBrand,
      ~isCardSupported,
      ~isFormValid=complete,
      ~setCardError,
      ~setExpiryError,
      ~setCvcError,
      ~localeString,
    )
  }

  let handleSaveCard = async () => {
    messageParentWindow(
      [("fullscreen", true->JSON.Encode.bool), ("param", "paymentloader"->JSON.Encode.string)],
      ~targetOrigin=parentURL,
    )
    let (pmSessionId, sdkAuthorization) = switch vaultCredentials {
    | HyperswitchVault(credentials) => (credentials.pmSessionId, credentials.sdkAuthorization)
    | _ => ("", "")
    }
    let (month, year) = CardUtils.getExpiryDates(cardExpiry)
    try {
      let response = await PaymentHelpersV2.savePaymentMethod(
        ~bodyArr=PaymentBody.cardTokenizationBody(~cardNumber, ~cvcNumber, ~month, ~year),
        ~pmSessionId,
        ~sdkAuthorization,
        ~logger=loggerState,
      )
      messageParentWindow(
        [("cardTokenEvent", true->JSON.Encode.bool), ("vaultResponse", response)],
        ~targetOrigin=parentURL,
      )
    } catch {
    | error =>
      messageParentWindow([("cardTokenFail", true->JSON.Encode.bool)], ~targetOrigin=parentURL)
      Console.error2("Unable to Save Card ", error->formatException->JSON.stringify)
    }
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let isOuterValid = json->getDictFromJson->getBool("isOuterValid", true)
    if confirm.doSubmit {
      if complete && isOuterValid {
        handleSaveCard()->ignore
      } else {
        reportCardFieldErrors()
      }
    }
  }, (cardNumber, cardExpiry, cvcNumber, cardBrand, complete, vaultCredentials, loggerState))
  useSubmitPaymentDataFromParent(submitCallback, ~parentOrigin=parentURL)

  <div className="animate-slowShow">
    <div className="flex flex-col" style={gridGap: themeObj.spacingGridColumn}>
      <div className="flex flex-col w-full" style={gridGap: themeObj.spacingGridColumn}>
        <CardFields cardProps expiryProps cvcProps />
        <SurchargeEligibilityNotice
          eligibilitySurchargeDetails
          eligibilityError=None
          isEligibilityPending={isEligibilityPending && paymentMethodListValue.should_block_confirm}
        />
      </div>
    </div>
  </div>
}
