@react.component
let make = () => {
  open Utils
  open ResizeObserver
  open RecoilAtoms
  open RecoilAtomsV2

  let (configAtom, setConfig) = Recoil.useRecoilState(configAtom)
  let (keys, setKeys) = Recoil.useRecoilState(keys)
  let (customPodUri, setCustomPodUri) = Recoil.useRecoilState(customPodUri)
  let {localeString} = configAtom

  let (vaultPublishableKey, setVaultPublishableKey) = Recoil.useRecoilState(vaultPublishableKey)
  let (vaultProfileId, setVaultProfileId) = Recoil.useRecoilState(vaultProfileId)
  let setPaymentMethodsList = Recoil.useSetRecoilState(paymentMethodsListV2)

  let contentRef = React.useRef(Nullable.null)

  let observer = ResizeObserver.newResizerObserver(entries => {
    entries->Array.forEach(entry => {
      let newHeight = entry.contentRect.height
      Utils.messageParentWindow([("cardIframeContentHeight", newHeight->JSON.Encode.float)])
    })
  })

  switch contentRef.current->Nullable.toOption {
  | Some(val) => observer.observe(val)
  | None => ()
  }

  let (logger, _initTimestamp) = React.useMemo0(() => {
    (HyperLogger.make(~source=Elements(PaymentMethodsManagement)), Date.now())
  })

  let setUserError = message => {
    postFailedSubmitResponseTop(~errortype="validation_error", ~message)
  }

  let {cardProps, expiryProps, cvcProps} = CommonCardProps.useCardForm(
    ~logger,
    ~paymentType=Payment,
  )

  let {isCardValid, isCardSupported, cardNumber, setCardError, cardBrand} = cardProps

  let {isExpiryValid, cardExpiry, setExpiryError} = expiryProps

  let {isCVCValid, cvcNumber, setCvcError} = cvcProps

  React.useEffect0(() => {
    messageParentWindow([("innerIframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let handleIframeValues = async () => {
        try {
          let json = ev.data->safeParse
          let dict = json->Utils.getDictFromJson

          if dict->Dict.get("innerIframeMounted")->Option.isSome {
            let metadata = dict->getJsonObjectFromDict("metadata")
            let metadataDict = metadata->Utils.getDictFromJson

            setPaymentMethodsList(_ => {
              metadataDict->UnifiedHelpersV2.createPaymentsObjArr("paymentList")
            })

            let {
              config,
              pmSessionId,
              pmClientSecret,
              vaultPublishableKey,
              vaultProfileId,
              endpoint,
              customPodUri,
            } = HyperVaultHelpers.extractVaultMetadata(metadataDict)

            setCustomPodUri(_ => customPodUri)
            ApiEndpoint.setApiEndPoint(endpoint)

            setKeys(prev => {
              ...prev,
              pmSessionId,
              pmClientSecret,
            })

            setVaultPublishableKey(_ => vaultPublishableKey)
            setVaultProfileId(_ => vaultProfileId)

            let configValue = config->getDictFromJson

            let {
              appearance,
              locale,
              fonts,
              clientSecret,
              ephemeralKey,
              pmSessionId: themePmSessionId,
              pmClientSecret: themePmClientSecret,
              loader,
              sdkAuthorization,
            } = CardTheme.itemToObjMapper(
              configValue,
              DefaultTheme.default,
              DefaultTheme.defaultRules,
              logger,
            )

            let localeObject = await CardTheme.getLocaleObject(locale == "" ? "auto" : locale)
            let constantString = await CardTheme.getConstantStringsObject()

            setConfig(_ => {
              config: {
                appearance,
                locale: locale === "auto" ? Window.Navigator.language : locale,
                fonts,
                clientSecret,
                ephemeralKey,
                pmClientSecret: themePmClientSecret,
                pmSessionId: themePmSessionId,
                loader,
                sdkAuthorization,
              },
              themeObj: appearance.variables,
              localeString: localeObject,
              constantString,
              showLoader: loader == Auto || loader == Always,
            })
          }
        } catch {
        | Exn.Error(_) => Console.error("Error in handling - handleIframeValues")
        }
      }

      handleIframeValues()->ignore
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  let handleSaveCard = async (ev: Types.event) => {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
    ])
    let (month, year) = CardUtils.getExpiryDates(cardExpiry)

    let cardNetwork = [
      ("card_network", cardBrand != "" ? cardBrand->JSON.Encode.string : JSON.Encode.null),
    ]
    let defaultCardBody = PaymentManagementBody.saveCardBody(
      ~cardNumber,
      ~month,
      ~year,
      ~cardHolderName=None,
      ~cvcNumber,
      ~cardBrand=cardNetwork,
    )
    try {
      let res = await PaymentHelpersV2.savePaymentMethod(
        ~bodyArr=defaultCardBody,
        ~pmSessionId=keys.pmSessionId->Option.getOr(""),
        ~pmClientSecret=keys.pmClientSecret->Option.getOr(""),
        ~publishableKey=vaultPublishableKey,
        ~profileId=vaultProfileId,
        ~customPodUri,
      )

      let dict = res->getDictFromJson
      let sessionResponse = dict->getStrArray("associated_payment_methods")
      let paymentToken = sessionResponse->Array.get(0)
      if paymentToken->Option.isSome {
        let msg =
          [("paymentToken", paymentToken->Option.getOr("")->JSON.Encode.string)]->Dict.fromArray

        ev.source->Window.sendPostMessage(msg)
      } else {
        let msg = [("errorMsg", "Payment token not found"->JSON.Encode.string)]->Dict.fromArray
        ev.source->Window.sendPostMessage(msg)
        Console.error("Payment token not found ")
      }
    } catch {
    | Exn.Error(err) =>
      let errorMsg = err->Exn.message->Option.getOr("Something went wrong")->JSON.Encode.string
      let msg = [("errorMsg", errorMsg)]->Dict.fromArray
      ev.source->Window.sendPostMessage(msg)
      let exceptionMessage = err->Exn.anyToExnInternal->formatException->JSON.stringify
      Console.error2("Unable to Save Card ", exceptionMessage)
    }
  }

  React.useEffect(() => {
    let handle = (ev: Types.event) => {
      let json = ev.data->Identity.anyTypeToJson->getStringFromJson("")->safeParse
      let dict = json->getDictFromJson
      if dict->Dict.get("generateToken")->Option.isSome {
        let isCardDetailsValid =
          isCVCValid->Option.getOr(false) &&
          isCardValid->Option.getOr(false) &&
          isCardSupported->Option.getOr(false) &&
          isExpiryValid->Option.getOr(false)

        let validFormat = isCardDetailsValid
        if validFormat {
          handleSaveCard(ev)->ignore
        } else {
          if cardNumber === "" {
            setCardError(_ => localeString.cardNumberEmptyText)
            setUserError(localeString.enterFieldsText)
          } else if isCardSupported->Option.getOr(true)->not {
            if cardBrand == "" {
              setCardError(_ => localeString.enterValidCardNumberErrorText)
              setUserError(localeString.enterValidDetailsText)
            } else {
              setCardError(_ => localeString.cardBrandConfiguredErrorText(cardBrand))
              setUserError(localeString.cardBrandConfiguredErrorText(cardBrand))
            }
          }
          if cardExpiry === "" {
            setExpiryError(_ => localeString.cardExpiryDateEmptyText)
            setUserError(localeString.enterFieldsText)
          }
          if cvcNumber === "" {
            setCvcError(_ => localeString.cvcNumberEmptyText)
            setUserError(localeString.enterFieldsText)
          }
          if !validFormat {
            setUserError(localeString.enterValidDetailsText)
          }
        }
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  }, (cardNumber, cardExpiry, cvcNumber))

  <div ref={contentRef->ReactDOM.Ref.domRef}>
    <CardPayment cardProps expiryProps cvcProps isVault=Some(true) />
  </div>
}

let default = make
