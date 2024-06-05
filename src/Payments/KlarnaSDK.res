open RecoilAtoms
open Utils
open Promise
open KlarnaSDKTypes

@val external klarnaInit: some = "Klarna.Payments.Buttons"

@react.component
let make = (~sessionObj: SessionsType.token) => {
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let setIsShowOrPayUsing = Recoil.useSetRecoilState(RecoilAtoms.isShowOrPayUsing)
  let {publishableKey, sdkHandleOneClickConfirmPayment} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let status = CommonHooks.useScript("https://x.klarnacdn.net/kp/lib/v1/api.js") // Klarna SDK script
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let setAreOneClickWalletsRendered = Recoil.useSetRecoilState(areOneClickWalletsRendered)
  let (stateJson, setStatesJson) = React.useState(_ => JSON.Encode.null)

  let (_, _, _, heightType) = options.wallets.style.height
  let height = switch heightType {
  | Klarna(val) => val
  | _ => 48
  }

  let handleCloseLoader = () => {
    Utils.handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
  }

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="pay_later",
    ~paymentMethodType="klarna",
  )

  PaymentUtils.useStatesJson(setStatesJson)

  React.useEffect(() => {
    if (
      status === "ready" &&
      stateJson !== JSON.Encode.null &&
      paymentMethodTypes !== PaymentMethodsRecord.defaultPaymentMethodType
    ) {
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
            makeOneClickHandlerPromise(sdkHandleOneClickConfirmPayment)->then(
              result => {
                let result = result->JSON.Decode.bool->Option.getOr(false)
                if result {
                  Utils.handlePostMessage([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", "paymentloader"->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                  ])
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
                        ~statesList=stateJson,
                      )

                      let klarnaSDKBody = PaymentBody.klarnaSDKbody(
                        ~token=res.authorization_token,
                        ~connectors,
                      )

                      let body = {
                        klarnaSDKBody
                        ->getJsonFromArrayOfJson
                        ->flattenObject(true)
                        ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
                        ->getArrayOfTupleFromDict
                      }

                      res.approved
                        ? intent(
                            ~bodyArr=body,
                            ~confirmParam={
                              return_url: options.wallets.walletReturnUrl,
                              publishableKey,
                            },
                            ~handleUserError=false,
                            (),
                          )
                        : handleCloseLoader()
                    },
                  )
                }
                resolve()
              },
            )
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
  }, (status, stateJson, paymentMethodTypes))

  <div style={height: `${height->Belt.Int.toString}px`} id="klarna-payments" className="w-full" />
}

let default = make
