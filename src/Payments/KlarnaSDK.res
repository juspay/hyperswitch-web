open RecoilAtoms
open Utils
open Promise
open KlarnaSDKTypes

@val external klarnaInit: some = "Klarna.Payments.Buttons"

@react.component
let make = (~sessionObj: SessionsType.token) => {
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(isShowOrPayUsing)
  let sdkHandleIsThere = Recoil.useRecoilValueFromAtom(isPaymentButtonHandlerProvidedAtom)
  let updateSession = Recoil.useRecoilValueFromAtom(updateSession)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let status = CommonHooks.useScript("https://x.klarnacdn.net/kp/lib/v1/api.js") // Klarna SDK script
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let (isCompleted, setIsCompleted) = React.useState(_ => false)
  let isTestMode = Recoil.useRecoilValueFromAtom(RecoilAtoms.isTestModeAtom)

  let setAreOneClickWalletsRendered = Recoil.useSetRecoilState(areOneClickWalletsRendered)

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
    ~paymentMethod="pay_later",
    ~paymentMethodType="klarna",
  )

  UtilityHooks.useHandlePostMessages(
    ~complete=isCompleted,
    ~empty=!isCompleted,
    ~paymentType="klarna",
  )
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
              Console.warn("Klarna checkout button clicked in test mode - interaction disabled")
              loggerState.setLogInfo(
                ~value="Klarna checkout button clicked in test mode - interaction disabled",
                ~eventName=PAYPAL_FLOW,
                ~paymentMethod="PAYPAL",
              )
              resolve()
            } else {
              PaymentUtils.emitPaymentMethodInfo(
                ~paymentMethod="wallet",
                ~paymentMethodType="klarna",
                ~country,
                ~state,
                ~pinCode,
              )
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
                        let (connectors, _) =
                          paymentMethodListValue->PaymentUtils.getConnectors(PayLater(Klarna(SDK)))

                        let shippingContact =
                          res.collected_shipping_address->Option.getOr(
                            defaultCollectedShippingAddress,
                          )

                        let requiredFieldsBody = DynamicFieldsUtils.getKlarnaRequiredFields(
                          ~shippingContact,
                          ~paymentMethodTypes,
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
  }, (status, paymentMethodTypes))

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
