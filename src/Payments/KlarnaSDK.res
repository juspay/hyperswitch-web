open JotaiAtoms
open Utils
open Promise
open KlarnaSDKTypes

@val external klarnaInit: some = "Klarna.Payments.Buttons"

@react.component
let make = (~sessionObj: SessionsType.token) => {
  let paymentMethod = "pay_later"
  let paymentMethodType = "klarna"
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let setIsShowOrPayUsing = Jotai.useSetAtom(isShowOrPayUsing)
  let sdkHandleIsThere = Jotai.useAtomValue(isPaymentButtonHandlerProvidedAtom)
  let updateSession = Jotai.useAtomValue(updateSession)
  let {publishableKey, iframeId, sdkAuthorization} = Jotai.useAtomValue(keys)
  let options = Jotai.useAtomValue(optionAtom)
  let isManualRetryEnabled = Jotai.useAtomValue(isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let status = CommonHooks.useScript("https://x.klarnacdn.net/kp/lib/v1/api.js") // Klarna SDK script
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let sdkConfigsValue = Jotai.useAtomValue(PaymentUtils.sdkConfigsValue)
  let (isCompleted, setIsCompleted) = React.useState(_ => false)
  let isTestMode = Jotai.useAtomValue(JotaiAtoms.isTestMode)

  let setAreOneClickWalletsRendered = Jotai.useSetAtom(areOneClickWalletsRendered)

  let (_, _, _, heightType, _) = options.wallets.style.height
  let height = switch heightType {
  | Klarna(val) => val
  | _ => 48
  }

  let handleCloseLoader = () => {
    Utils.messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
  }

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod,
    ~paymentMethodType,
  )

  let (requiredFields, _, _, resolutionContext) = DynamicFieldsUtils.useSuperpositionRequiredFields(
    ~paymentMethod,
    ~paymentMethodType,
  )

  DynamicFieldsUtils.useLogDynamicFieldsRendered(
    ~fields=requiredFields,
    ~paymentMethod,
    ~resolutionContext,
  )

  UtilityHooks.useHandlePostMessages(
    ~complete=isCompleted,
    ~empty=!isCompleted,
    ~paymentType=paymentMethodType,
  )
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  let {country, state, pinCode} = PaymentUtils.useNonPiiAddressData()

  React.useEffect(() => {
    if status === "ready" && paymentMethodTypes !== PaymentMethodsRecord.defaultPaymentMethodType {
      let klarnaWrapper = GooglePayType.getElementById(Utils.document, "klarna-payments")
      klarnaWrapper.innerHTML = ""
      klarnaInit.init({
        client_token: sessionObj.token,
      })

      klarnaInit.load(
        {
          container: "#klarna-payments",
          theme: options.wallets.style.theme == Dark ? "default" : "outlined",
          shape: "default",
          on_click: authorize => {
            if isTestMode {
              Console.warn("Klarna SDK button clicked in test mode - interaction disabled")
              loggerState.setLogInfo(
                ~value="Klarna SDK button clicked in test mode - interaction disabled",
                ~eventName=KLARNA_SDK_FLOW,
                ~paymentMethod="KLARNA",
              )
              resolve()
            } else {
              loggerState.setLogInfo(
                ~value="Klarna SDK Button Clicked",
                ~eventName=KLARNA_SDK_FLOW,
                ~paymentMethod="KLARNA",
              )
              PaymentUtils.emitPaymentMethodInfo(
                ~paymentMethod="wallet",
                ~paymentMethodType,
                ~country,
                ~state,
                ~pinCode,
              )
              emitter.emitPaymentMethodStatus(
                ~paymentMethod="wallet",
                ~paymentMethodType,
                ~isSavedPaymentMethod=false,
                ~isOneClickWallet=true,
              )
              emitter.emitBillingAddress(~country, ~state, ~postalCode=pinCode)
              makeOneClickHandlerPromise(sdkHandleIsThere)->then(
                result => {
                  let result = result->JSON.Decode.bool->Option.getOr(false)
                  if result {
                    Utils.messageParentWindow([
                      ("fullscreen", true->JSON.Encode.bool),
                      ("param", "paymentloader"->JSON.Encode.string),
                      ("iframeId", iframeId->JSON.Encode.string),
                    ])
                    setIsCompleted(_ => true)
                    authorize(
                      {collect_shipping_address: componentName->getIsExpressCheckoutComponent},
                      Dict.make()->JSON.Encode.object,
                      (res: res) => {
                        let connectors = SdkConfigParser.getEligibleConnectorsFromPaymentMethods(
                          sdkConfigsValue.payment_methods,
                          paymentMethod,
                          paymentMethodType,
                        )

                        let shippingContact =
                          res.collected_shipping_address->Option.getOr(
                            defaultCollectedShippingAddress,
                          )

                        let requiredFieldsBody = DynamicFieldsUtils.getKlarnaRequiredFields(
                          ~shippingContact,
                          ~requiredFields,
                        )

                        let klarnaSDKBody = PaymentBody.klarnaSDKbody(
                          ~token=res.authorization_token,
                          ~connectors,
                        )

                        let body = {
                          klarnaSDKBody->mergeAndFlattenToTuples(requiredFieldsBody)
                        }

                        res.approved
                          ? intent(
                              ~bodyArr=body,
                              ~confirmParam={
                                return_url: options.wallets.walletReturnUrl,
                                publishableKey,
                              },
                              ~handleUserError=false,
                              ~manualRetry=isManualRetryEnabled,
                            )
                          : handleCloseLoader()
                      },
                    )
                  }
                  resolve()
                },
              )
            }
          },
        },
        _ => {
          setAreOneClickWalletsRendered(
            prev => {
              ...prev,
              isKlarna: true,
            },
          )
          setIsShowOrPayUsing(_ => true)
        },
      )
    }
    None
  }, (status, paymentMethodTypes, sdkAuthorization))

  <div
    style={
      height: `${height->Int.toString}px`,
      pointerEvents: updateSession ? "none" : "auto",
      opacity: updateSession ? "0.5" : "1.0",
    }
    id="klarna-payments"
    className="w-full"
  />
}

let default = make
