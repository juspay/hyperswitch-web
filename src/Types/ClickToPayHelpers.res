open Promise
let getScriptSrc = () => {
  let clickToPayMastercardBaseUrl = GlobalVars.isProd
    ? "https://src.mastercard.com"
    : "https://sandbox.src.mastercard.com"
  clickToPayMastercardBaseUrl ++ "/srci/integration/2/lib.js"
}

let srcUiKitScriptSrc = "https://src.mastercard.com/srci/integration/components/src-ui-kit/src-ui-kit.esm.js"
let srcUiKitCssHref = "https://src.mastercard.com/srci/integration/components/src-ui-kit/src-ui-kit.css"

let recognitionTokenCookieName = "__mastercard_click_to_pay"

type ctpProviderType = VISA | MASTERCARD | NONE

let loggerProviderOfCtpProvider = provider =>
  switch provider {
  | VISA => Some(ClickToPayLoggerEvents.VisaUctp)
  | MASTERCARD => Some(ClickToPayLoggerEvents.MastercardUctp)
  | NONE => None
  }

type element = {
  mutable innerHTML: string,
  appendChild: Window.element => unit,
  removeChild: Window.element => unit,
  replaceChildren: unit => unit,
  children: array<Window.element>,
}
@send
external getElementById: (Window.elementRef, string) => Nullable.t<element> = "getElementById"

open Window
let clickToPayWindowRef: ref<Nullable.t<Types.window>> = ref(Nullable.null)

let handleCloseClickToPayWindow = () => {
  switch clickToPayWindowRef.contents->Nullable.toOption {
  | Some(window) => {
      window->closeWindow
      clickToPayWindowRef.contents = Nullable.null
    }
  | None => ()
  }
}

let handleOpenClickToPayWindow = () => {
  clickToPayWindowRef.contents = windowOpen("", "ClickToPayWindow", "width=480,height=600")
  LoaderHTML.injectLoader(clickToPayWindowRef.contents)
}

type mastercardCheckoutServices

type responsePayloadStatus = COMPLETE | CANCEL | PAY_V3_CARD | ERROR

type responsePayload = {
  status: responsePayloadStatus,
  payload: JSON.t,
}

type cardBrand = [
  | #visa
  | #mastercard
  | #discover
  | #amex
]

type authenticationPreferences = {payloadRequested: [#AUTHENTICATED | #NON_AUTHENTICATED]}

type dynamicDataTypeValue =
  CARD_APPLICATION_CRYPTOGRAM_SHORT_FORM | CARD_APPLICATION_CRYPTOGRAM_LONG_FORM | NONE

type paymentOption = {
  dpaDynamicDataTtlMinutes: int,
  dynamicDataType: dynamicDataTypeValue,
}

type transactionAmount = {
  transactionAmount: float,
  transactionCurrencyCode: string,
}

type dpaTransactionOptions = {
  dpaLocale: string,
  authenticationPreferences: authenticationPreferences,
  paymentOptions: array<paymentOption>,
  transactionAmount: transactionAmount,
  acquirerBIN: string,
  acquirerMerchantId: string,
  merchantCategoryCode: string,
  merchantCountryCode: string,
}

type dpaData = {dpaName: string}

type params = {
  srcDpaId: string,
  dpaData: dpaData,
  dpaTransactionOptions: dpaTransactionOptions,
  cardBrands: array<string>,
  recognitionToken?: string,
  checkoutExperience: [#WITHIN_CHECKOUT | #PAYMENT_SETTINGS],
}

type country = {
  code: string,
  countryISO: string,
}

let defaultCountry: country = {code: "", countryISO: ""}

let setLocalStorage = (~key: string, ~value: string) => {
  Window.LocalStorage.setItem(key, value)
}

let getLocalStorage = (~key: string) => {
  Window.LocalStorage.getItem(key)
}

let deleteLocalStorage = (~key: string) => {
  Window.LocalStorage.removeItem(key)
}

type mobileNumber = {
  phoneNumber: string,
  countryCode: string,
}

type savedCardInfo = {
  panBin: string,
  cardBrand: string,
}

type identityType = EMAIL_ADDRESS | MOBILE_PHONE_NUMBER

let getIdentityType = identityType => {
  switch identityType {
  | EMAIL_ADDRESS => "EMAIL_ADDRESS"
  | MOBILE_PHONE_NUMBER => "MOBILE_PHONE_NUMBER"
  }
}

type consumerIdentity = {
  identityProvider?: string,
  identityType: identityType,
  identityValue: string,
}

type accountReference = {consumerIdentity: consumerIdentity}

type authenticatePayload = {
  windowRef: Types.window,
  requestRecognitionToken: bool,
  accountReference: accountReference,
}

type encryptCardPayload = {
  primaryAccountNumber: string,
  panExpirationMonth: string,
  panExpirationYear: string,
  cardSecurityCode: string,
}

type checkoutWithCardPayload = {
  windowRef: Types.window,
  srcDigitalCardId: string,
  rememberMe: bool,
}

type digitalCardData = {descriptorName: string}

type clickToPayCard = {
  srcDigitalCardId: string,
  panLastFour: string,
  panExpirationMonth: string,
  panExpirationYear: string,
  paymentCardDescriptor: string,
  digitalCardData: digitalCardData,
  panBin: string,
}

let clickToPayCardItemToObjMapper = (json: JSON.t): clickToPayCard => {
  let dict = json->Utils.getDictFromJson
  {
    srcDigitalCardId: dict->Utils.getString("srcDigitalCardId", ""),
    panLastFour: dict->Utils.getString("panLastFour", ""),
    panExpirationMonth: dict->Utils.getString("panExpirationMonth", ""),
    panExpirationYear: dict->Utils.getString("panExpirationYear", ""),
    paymentCardDescriptor: dict->Utils.getString("paymentCardDescriptor", ""),
    digitalCardData: {
      descriptorName: dict
      ->Utils.getDictFromDict("digitalCardData")
      ->Utils.getString("descriptorName", ""),
    },
    panBin: dict->Utils.getString("panBin", ""),
  }
}

type clickToPayToken = {
  dpaId: string,
  dpaName: string,
  locale: string,
  transactionAmount: float,
  transactionCurrencyCode: string,
  acquirerBIN: string,
  acquirerMerchantId: string,
  merchantCategoryCode: string,
  merchantCountryCode: string,
  cardBrands: array<string>,
  email: string,
  provider: string,
}

let clickToPayTokenItemToObjMapper = (json: JSON.t) => {
  let dict = json->Utils.getDictFromJson
  {
    dpaId: dict->Utils.getString("dpa_id", ""),
    dpaName: dict->Utils.getString("dpa_name", ""),
    locale: dict->Utils.getString("locale", ""),
    transactionAmount: dict->Utils.getFloat("transaction_amount", 0.0),
    transactionCurrencyCode: dict->Utils.getString("transaction_currency_code", ""),
    acquirerBIN: dict->Utils.getString("acquirer_bin", ""),
    acquirerMerchantId: dict->Utils.getString("acquirer_merchant_id", ""),
    merchantCategoryCode: dict->Utils.getString("merchant_category_code", ""),
    merchantCountryCode: dict->Utils.getString("merchant_country_code", ""),
    cardBrands: dict
    ->Utils.getArray("card_brands")
    ->Array.map(item => item->JSON.Decode.string->Option.getOr("")),
    email: dict->Utils.getString("email", ""),
    provider: dict->Utils.getString("provider", "mastercard"),
  }
}

@send
external getCards: (mastercardCheckoutServices, unit) => promise<array<clickToPayCard>> = "getCards"

@send
external authenticate: (mastercardCheckoutServices, authenticatePayload) => promise<JSON.t> =
  "authenticate"

@send
external checkoutWithCard: (
  mastercardCheckoutServices,
  checkoutWithCardPayload,
) => promise<JSON.t> = "checkoutWithCard"

@send
external encryptCard: (mastercardCheckoutServices, encryptCardPayload) => promise<JSON.t> =
  "encryptCard"

type consumer = {
  fullName?: string,
  emailAddress: string,
  mobileNumber: mobileNumber,
}

type complianceSettingsData = {
  acceptedVersion: string,
  latestVersion: string,
  latestVersionUri: string,
}

type complianceSettings = {
  privacy: complianceSettingsData,
  tnc: complianceSettingsData,
  cookie: complianceSettingsData,
}

type checkoutWithNewCardPayload = {
  windowRef: Types.window,
  cardBrand: string,
  encryptedCard: JSON.t,
  rememberMe: bool,
  consumer?: consumer,
  complianceSettings: complianceSettings,
}

let mcCheckoutService: ref<option<mastercardCheckoutServices>> = ref(None)

type clickToPayOptions = {
  dpaId: string,
  dpaName: string,
  locale?: string,
  transactionAmount: float,
  transactionCurrencyCode: string,
  acquirerBIN: string,
  acquirerMerchantId: string,
  merchantCategoryCode: string,
  merchantCountryCode: string,
  cardBrands: array<string>,
}

@send
external init: (mastercardCheckoutServices, params) => promise<JSON.t> = "init"

@val @scope("window")
external getOptionMastercardCheckoutServices: option<unit => mastercardCheckoutServices> =
  "MastercardCheckoutServices"

@new @scope("window")
external getMastercardCheckoutServices: unit => mastercardCheckoutServices =
  "MastercardCheckoutServices"

let initializeMastercardCheckout = (clickToPayToken: clickToPayToken) => {
  switch getOptionMastercardCheckoutServices {
  | Some(_) => {
      mcCheckoutService := Some(getMastercardCheckoutServices())

      let recognitionToken = getLocalStorage(~key=recognitionTokenCookieName)
      let params = {
        srcDpaId: clickToPayToken.dpaId,
        dpaData: {
          dpaName: clickToPayToken.dpaName,
        },
        dpaTransactionOptions: {
          dpaLocale: clickToPayToken.locale,
          authenticationPreferences: {
            payloadRequested: #AUTHENTICATED,
          },
          paymentOptions: [
            {
              dpaDynamicDataTtlMinutes: 15,
              dynamicDataType: CARD_APPLICATION_CRYPTOGRAM_SHORT_FORM,
            },
          ],
          transactionAmount: {
            transactionAmount: clickToPayToken.transactionAmount,
            transactionCurrencyCode: clickToPayToken.transactionCurrencyCode,
          },
          acquirerBIN: clickToPayToken.acquirerBIN,
          acquirerMerchantId: clickToPayToken.acquirerMerchantId,
          merchantCategoryCode: clickToPayToken.merchantCategoryCode,
          merchantCountryCode: clickToPayToken.merchantCountryCode,
        },
        checkoutExperience: #WITHIN_CHECKOUT,
        cardBrands: clickToPayToken.cardBrands,
      }

      let params = switch recognitionToken->Nullable.toOption {
      | Some(token) => {
          ClickToPayLogger.logLifecycle(~event=RecognitionTokenFound({provider: MastercardUctp}))
          {...params, recognitionToken: token}
        }
      | None => params
      }

      try {
        switch mcCheckoutService.contents {
        | Some(service) =>
          ClickToPayLogger.observeFunction(~event=Init({provider: MastercardUctp}), ~call=() =>
            service->init(params)
          )
          ->then(resp => {
            ClickToPayLogger.logLifecycle(~event=ProviderReady({provider: MastercardUctp}))
            resolve(resp)
          })
          ->catch(err => reject(err))
        | None => {
            ClickToPayLogger.logLifecycle(~event=ProviderUnavailable({provider: MastercardUctp}))
            reject(JsExn.anyToExnInternal("Mastercard Checkout Service not initialized"))
          }
        }
      } catch {
      | error => reject(error)
      }
    }
  | None => {
      ClickToPayLogger.logLifecycle(~event=ProviderUnavailable({provider: MastercardUctp}))
      reject(JsExn.anyToExnInternal("MastercardCheckoutServices is not available"))
    }
  }
}

let getCards = async () => {
  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        let cards = await ClickToPayLogger.observeFunction(
          ~event=GetCards({provider: MastercardUctp}),
          ~call=() => service->getCards(),
        )
        Ok(cards)
      }
    | None => {
        ClickToPayLogger.logLifecycle(~event=ProviderUnavailable({provider: MastercardUctp}))
        Ok([])
      }
    }
  } catch {
  | _ => Ok([])
  }
}

type authenticateInputPayload = {
  windowRef: Types.window,
  consumerIdentity: consumerIdentity,
}

let authenticate = async (payload: authenticateInputPayload) => {
  let authenticatePayload = {
    windowRef: payload.windowRef,
    requestRecognitionToken: true,
    accountReference: {
      consumerIdentity: {
        identityType: payload.consumerIdentity.identityType,
        identityValue: payload.consumerIdentity.identityValue,
      },
    },
  }

  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        let authentication = await ClickToPayLogger.observeFunction(
          ~event=Authenticate({provider: MastercardUctp}),
          ~call=() => service->authenticate(authenticatePayload),
        )

        let recognitionToken =
          authentication->Utils.getDictFromJson->Utils.getString("recognitionToken", "")

        if recognitionToken !== "" {
          setLocalStorage(~key=recognitionTokenCookieName, ~value=recognitionToken)
        }

        Ok(authentication)
      }
    | None => {
        ClickToPayLogger.logLifecycle(~event=ProviderUnavailable({provider: MastercardUctp}))
        Error(JsExn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => Error(error)
  }
}

let checkoutWithCard = async (~windowRef: Types.window, ~srcDigitalCardId: string) => {
  let checkoutPayload = {
    windowRef,
    srcDigitalCardId,
    rememberMe: true,
  }

  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        let checkoutResp = await ClickToPayLogger.observeFunction(
          ~event=CheckoutWithCard({provider: MastercardUctp}),
          ~call=() => service->checkoutWithCard(checkoutPayload),
        )
        Ok(checkoutResp)
      }
    | None => {
        ClickToPayLogger.logLifecycle(~event=ProviderUnavailable({provider: MastercardUctp}))
        Error(JsExn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => Error(error)
  }
}

let encryptCardForClickToPay = async (~cardNumber, ~expiryMonth, ~expiryYear, ~cvcNumber) => {
  let card: encryptCardPayload = {
    primaryAccountNumber: cardNumber,
    panExpirationMonth: expiryMonth,
    panExpirationYear: expiryYear,
    cardSecurityCode: cvcNumber,
  }
  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        let encryptedCard = await ClickToPayLogger.observeFunction(
          ~event=EncryptCard({provider: MastercardUctp}),
          ~call=() => service->encryptCard(card),
        )
        Ok(encryptedCard)
      }
    | None => {
        ClickToPayLogger.logLifecycle(~event=ProviderUnavailable({provider: MastercardUctp}))
        Error(JsExn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => Error(error)
  }
}

@send
external checkoutWithNewCard: (
  mastercardCheckoutServices,
  checkoutWithNewCardPayload,
) => promise<JSON.t> = "checkoutWithNewCard"

let checkoutWithNewCard = async (payload: checkoutWithNewCardPayload) => {
  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        let checkoutResp = await ClickToPayLogger.observeFunction(
          ~event=CheckoutWithNewCard({provider: MastercardUctp}),
          ~call=() => service->checkoutWithNewCard(payload->Obj.magic),
        )
        Ok(checkoutResp)
      }
    | None => {
        ClickToPayLogger.logLifecycle(~event=ProviderUnavailable({provider: MastercardUctp}))
        Error(JsExn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => Error(error)
  }
}

let loadClickToPayScripts = () =>
  Promise.make((resolve, _) => {
    let pending = ref(2)

    let settle = () => {
      pending := pending.contents - 1
      pending.contents === 0 ? resolve() : ()
    }
    ClickToPayLogger.observeResource(
      ~event=UiKitScript,
      ~url=srcUiKitScriptSrc,
      ~attributes=[("type", "module")],
      ~onLoad=settle,
      ~onError=_ => settle(),
    )
    ClickToPayLogger.observeResource(
      ~event=UiKitStylesheet,
      ~url=srcUiKitCssHref,
      ~onLoad=settle,
      ~onError=_ => settle(),
    )
  })

let loadMastercardScript = clickToPayToken =>
  Promise.make((resolve, reject) =>
    ClickToPayLogger.observeResource(
      ~event=MastercardSdkScript,
      ~url=getScriptSrc(),
      ~onLoad=() =>
        initializeMastercardCheckout(clickToPayToken)
        ->Promise.thenResolve(resolve)
        ->Promise.catch(error => {
          reject(error)
          Promise.resolve()
        })
        ->ignore,
      ~onError=reject,
    )
  )

type srcMarkProps = {
  @as("card-brands") cardBrands?: string,
  height?: string,
  width?: string,
  className?: string,
}

type srcLoaderProps = {
  className?: string,
  size?: string,
}

type srcLearnMoreProps = {
  @as("card-brands") cardBrands: string,
  className?: string,
}

module SrcMark = {
  @val
  external makeOrig: (@as("src-mark") _, srcMarkProps) => React.element = "React.createElement"

  let make = React.memo(makeOrig)
}

module SrcLoader = {
  @val
  external make: (@as("src-loader") _, srcLoaderProps) => React.element = "React.createElement"
}

module SrcLearnMore = {
  @val
  external make: (@as("src-learn-more") _, srcLearnMoreProps) => React.element =
    "React.createElement"
}

@send
external signOutMastercard: mastercardCheckoutServices => promise<JSON.t> = "signOut"

let signOut = async () => {
  try {
    deleteLocalStorage(~key=recognitionTokenCookieName)

    switch mcCheckoutService.contents {
    | Some(service) => {
        let signOutResp = await ClickToPayLogger.observeFunction(
          ~event=SignOut({provider: MastercardUctp}),
          ~call=() => service->signOutMastercard,
        )
        Ok(signOutResp)
      }
    | None => {
        Console.error("Mastercard Checkout Service not initialized")
        Error(JsExn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => {
      Console.error2("Error during signOut:", error)
      Error(error)
    }
  }
}

type srcOtpInputProps = {
  @as("display-header") header?: bool,
  @as("display-cancel-option") displayCancelOption?: bool,
  @as("display-remember-me") displayRememberMe?: bool,
  @as("disable-elements") disableElements?: bool,
  @as("is-successful") isOtpValid?: bool,
  @as("hide-loader") hideLoader?: bool,
  @as("otp-resend-loading") isOtpResendLoading?: bool,
  @as("error-reason") errorReason?: string,
  locale: string,
  id?: string,
  @as("type") typeName?: string,
  @as("card-brands") cardBrand?: string,
  @as("masked-identity-value") maskedIdentityValue?: string,
  @as("network-id") network: string,
  @as("auto-submit") isAutoSubmit?: bool,
}

module SrcOtpInput = {
  @val
  external makeOrig: (@as("src-otp-input") _, srcOtpInputProps) => React.element =
    "React.createElement"
  let make = React.memo(makeOrig)
}

type actionCode = SUCCESS | PENDING_CONSUMER_IDV | FAILED | ERROR | ADD_CARD
type visaTransactionAmount = {
  transactionAmount: string,
  transactionCurrencyCode: string,
}
type authenticationmethodAttributes = {challengeIndicator: string}

type authenticationMethodsVisa = {
  authenticationMethodType: string,
  authenticationSubject: string,
  methodAttributes: authenticationmethodAttributes,
}
type authenticationPreferencesVisa = {
  authenticationMethods: array<authenticationMethodsVisa>,
  payloadRequested: string,
}

type dpaTransactionOptionsVisa = {
  dpaLocale?: string,
  authenticationPreferences?: authenticationPreferencesVisa,
  dpaBillingPreference?: string,
  paymentOptions?: array<paymentOption>,
  transactionAmount?: visaTransactionAmount,
  payloadTypeIndicator?: string,
  merchantCountryCode?: string,
  consumerNationalIdentifierRequested?: bool,
  merchantCategoryCode?: string,
  acquirerBIN: string,
  acquirerMerchantId: string,
  merchantName?: string,
  merchantOrderId?: string,
}
type visaConsumer = {
  consumerIdentity: consumerIdentity,
  fullName: string,
  emailAddress: string,
  mobileNumber: mobileNumber,
  countryCode?: string,
  locale?: string,
  firstName?: string,
  lastName?: string,
}
type complianceType = PRIVACY_POLICY | REMEMBER_ME | TERMS_AND_CONDITIONS

type complianceResource = {
  complianceType: complianceType,
  uri: string,
}

type visaComplianceSettings = {complianceResources: array<complianceResource>}

type checkoutConfig = {
  srcDigitalCardId?: string,
  encryptedCard?: string,
  consumer?: visaConsumer,
  complianceSettings?: visaComplianceSettings,
  payloadTypeIndicatorCheckout?: string,
  windowRef?: Types.window,
  dpaTransactionOptions: dpaTransactionOptionsVisa,
}
type visaInitConfig = {dpaTransactionOptions: dpaTransactionOptionsVisa}
type getCardsConfig = {consumerIdentity: consumerIdentity, validationData?: string}
type errorObj = {reason?: string, message?: string}
type profile = {maskedCards: array<clickToPayCard>}
type getCardsResultType = {
  actionCode: actionCode,
  error?: errorObj,
  profiles?: array<profile>,
  maskedValidationChannel?: string,
}

type unbindAppInstanceResultType = {error?: errorObj}

type vsdk = {
  initialize: visaInitConfig => promise<{.}>,
  getCards: getCardsConfig => promise<getCardsResultType>,
  checkout: checkoutConfig => promise<JSON.t>,
  unbindAppInstance: unit => promise<unbindAppInstanceResultType>,
}

type mastercardDirectDpaTransactionOptions = {dpaLocale: string}

type c2pDirectInitData = {
  srciTransactionId: string,
  srcInitiatorId: string,
  srciDpaId: string,
  dpaTransactionOptions?: mastercardDirectDpaTransactionOptions,
}

type mastercardDirect = {
  init: c2pDirectInitData => promise<{.}>,
  identityLookup: accountReference => promise<JSON.t>,
}

type visaDirect = {
  init: c2pDirectInitData => promise<{.}>,
  identityLookup: consumerIdentity => promise<JSON.t>,
}

let defaultProfile = {
  maskedCards: [],
}

type visaComponentState = CARDS_LOADING | OTP_INPUT | NONE

type visaEncryptCardPayload = {
  primaryAccountNumber: string,
  panExpirationMonth: string,
  panExpirationYear: string,
  cardSecurityCode: string,
  cardHolderName: string,
}

@val external vsdk: vsdk = "window.VSDK"
@val @scope("window") external initializedVSDK: Nullable.t<bool> = "initializedVSDK"
@val @scope("window") external windowVisaDirectSdk: Nullable.t<visaDirect> = "visaDirectSdk"

@val external mastercardDirectSdk: mastercardDirect = "window.SRCSDK_MASTERCARD"
@new external createVisaDirectSRCIAdapter: unit => visaDirect = "window.vAdapters.VisaSRCI"

let getCardsVisaUnified = (~getCardsConfig) =>
  ClickToPayLogger.observeFunction(~event=GetCards({provider: VisaUctp}), ~call=() =>
    vsdk.getCards(getCardsConfig)
  )

let signOutVisaUnified = () =>
  ClickToPayLogger.observeFunction(~event=UnbindAppInstance({provider: VisaUctp}), ~call=() =>
    vsdk.unbindAppInstance()
  )

let loadVisaScript = (clickToPayToken: clickToPayToken, onLoadCallback, onErrorCallback) => {
  let cardBrands = clickToPayToken.cardBrands->Array.join(",")
  let scriptSrc = GlobalVars.isProd
    ? `https://secure.checkout.visa.com/checkout-widget/resources/js/integration/v2/sdk.js?dpaId=${clickToPayToken.dpaId}&locale=${clickToPayToken.locale}&cardBrands=${cardBrands}&dpaClientId=${clickToPayToken.dpaName}`
    : `https://sandbox.secure.checkout.visa.com/checkout-widget/resources/js/integration/v2/sdk.js?dpaId=${clickToPayToken.dpaId}&locale=${clickToPayToken.locale}&cardBrands=${cardBrands}&dpaClientId=${clickToPayToken.dpaName}`
  ClickToPayLogger.observeResource(
    ~event=VisaSdkScript,
    ~url=scriptSrc,
    ~matchQuery=true,
    ~onLoad=onLoadCallback,
    ~onError=_ => onErrorCallback(),
  )
}

let loadClickToPayUIScripts = (scriptLoadedCallback, scriptErrorCallback) => {
  ClickToPayLogger.observeResource(
    ~event=UiKitScript,
    ~url=srcUiKitScriptSrc,
    ~attributes=[("type", "module")],
    ~onLoad=scriptLoadedCallback,
    ~onError=_ => scriptErrorCallback(),
  )
  ClickToPayLogger.observeResource(~event=UiKitStylesheet, ~url=srcUiKitCssHref)
}

let formatOrderId = orderId =>
  orderId
  ->String.replace("pay_", "")
  ->String.split("_secret_")
  ->Array.at(0)
  ->Option.getOr("")
  ->String.slice(~start=0, ~end=40)

let getVisaInitConfig = (token: clickToPayToken, clientSecret) => {
  {
    dpaTransactionOptions: {
      dpaLocale: token.locale,
      paymentOptions: [
        {
          dpaDynamicDataTtlMinutes: 15,
          dynamicDataType: CARD_APPLICATION_CRYPTOGRAM_LONG_FORM,
        },
      ],
      transactionAmount: {
        transactionAmount: token.transactionAmount->Float.toString,
        transactionCurrencyCode: token.transactionCurrencyCode,
      },
      dpaBillingPreference: "NONE",
      consumerNationalIdentifierRequested: false,
      payloadTypeIndicator: "FULL",
      acquirerBIN: token.acquirerBIN,
      acquirerMerchantId: token.acquirerMerchantId,
      merchantCategoryCode: token.merchantCategoryCode,
      merchantCountryCode: token.merchantCountryCode,
      merchantOrderId: clientSecret->Option.getOr("")->formatOrderId,
    },
  }
}

type visaCheckoutResponse = {
  actionCode: actionCode,
  checkoutResponse: string,
}

let checkoutVisaUnified = async (
  ~srcDigitalCardId="",
  ~encryptedCard="",
  ~windowRef,
  ~newCard=false,
  ~rememberMe=false,
  ~clickToPayToken: clickToPayToken,
  ~orderId,
  ~consumer: consumer,
  ~request3DSAuthentication=true,
) => {
  let baseDpaTransactionOptions = {
    acquirerBIN: clickToPayToken.acquirerBIN,
    acquirerMerchantId: clickToPayToken.acquirerMerchantId,
    merchantName: clickToPayToken.dpaName,
    merchantOrderId: orderId->formatOrderId,
  }

  let dpaTransactionOptions = request3DSAuthentication
    ? {
        ...baseDpaTransactionOptions,
        authenticationPreferences: {
          authenticationMethods: [
            {
              authenticationMethodType: "3DS",
              authenticationSubject: "CARDHOLDER",
              methodAttributes: {
                challengeIndicator: "01",
              },
            },
          ],
          payloadRequested: "AUTHENTICATED",
        },
      }
    : baseDpaTransactionOptions

  let defaultConfig = {
    payloadTypeIndicatorCheckout: "FULL",
    windowRef,
    dpaTransactionOptions,
  }

  let complianceSettings = {
    complianceResources: [
      {
        complianceType: PRIVACY_POLICY,
        uri: "https://www.visa.com/en_us/checkout/legal/global-privacy-notice.html",
      },
      {
        complianceType: REMEMBER_ME,
        uri: "https://www.visa.com/en_us/checkout/legal/global-privacy-notice/cookie-notice.html",
      },
      {
        complianceType: TERMS_AND_CONDITIONS,
        uri: "https://www.visa.com/en_us/checkout/legal/terms-of-service.html",
      },
    ],
  }

  let checkoutConfig = switch newCard {
  | false =>
    switch rememberMe {
    | false => {
        ...defaultConfig,
        srcDigitalCardId,
      }
    | true => {
        ...defaultConfig,
        srcDigitalCardId,
        complianceSettings,
      }
    }
  | true => {
      open Utils
      let clientCountry = getClientCountry(dateTimeFormat().resolvedOptions().timeZone)
      {
        ...defaultConfig,
        encryptedCard,
        consumer: {
          consumerIdentity: {
            identityProvider: "SRC",
            identityType: EMAIL_ADDRESS,
            identityValue: consumer.emailAddress,
          },
          fullName: consumer.fullName->Option.getOr(""),
          emailAddress: consumer.emailAddress,
          mobileNumber: {
            countryCode: consumer.mobileNumber.countryCode,
            phoneNumber: consumer.mobileNumber.phoneNumber,
          },
          countryCode: clientCountry.isoAlpha2,
          locale: clickToPayToken.locale->String.split("_")->Array.at(0)->Option.getOr(""),
        },
        complianceSettings,
      }
    }
  }
  await ClickToPayLogger.observeFunction(~event=Checkout({provider: VisaUctp}), ~call=() =>
    vsdk.checkout(checkoutConfig)
  )
}

let closeWindow = (status, payload: JSON.t) => {
  handleCloseClickToPayWindow()

  {
    status,
    payload,
  }
}

let handleSuccessResponse = response => {
  let checkoutActionCode =
    response->Utils.getDictFromJson->Utils.getString("checkoutActionCode", "")

  switch checkoutActionCode {
  | "COMPLETE" => closeWindow(COMPLETE, response)
  | "ERROR" => closeWindow(ERROR, response)
  | "CANCEL" => closeWindow(CANCEL, response)
  | "PAY_V3_CARD" => closeWindow(PAY_V3_CARD, response)
  | _ => closeWindow(ERROR, response)
  }
}

let handleCheckoutWithCard = async (
  ~clickToPayProvider,
  ~srcDigitalCardId,
  ~fullName,
  ~email,
  ~phoneNumber,
  ~countryCode,
  ~clickToPayToken,
  ~isClickToPayRememberMe,
  ~orderId,
  ~request3DSAuthentication=true,
) => {
  switch clickToPayWindowRef.contents->Nullable.toOption {
  | Some(window) =>
    switch clickToPayProvider {
    | MASTERCARD => {
        let checkoutResp = await checkoutWithCard(~windowRef=window, ~srcDigitalCardId)
        switch checkoutResp {
        | Ok(response) => response->handleSuccessResponse
        | Error(_) => closeWindow(ERROR, JSON.Encode.null)
        }
      }
    | VISA =>
      try {
        let consumer: consumer = {
          fullName,
          emailAddress: email,
          mobileNumber: {
            phoneNumber,
            countryCode,
          },
        }
        switch clickToPayToken {
        | Some(token) => {
            let checkoutResp = await checkoutVisaUnified(
              ~srcDigitalCardId,
              ~clickToPayToken=token,
              ~windowRef=window,
              ~rememberMe=isClickToPayRememberMe,
              ~orderId,
              ~consumer,
              ~request3DSAuthentication,
            )
            let actionCode = checkoutResp->Utils.getDictFromJson->Utils.getString("actionCode", "")
            switch actionCode {
            | "SUCCESS" => {
                ClickToPayLogger.logLifecycle(~event=CheckoutCompleted({provider: VisaUctp}))
                closeWindow(COMPLETE, checkoutResp)
              }
            | "CHANGE_CARD"
            | "SWITCH_CONSUMER" => {
                ClickToPayLogger.logLifecycle(
                  ~event=CheckoutCancelled({provider: VisaUctp, code: actionCode}),
                )
                closeWindow(ERROR, JSON.Encode.null)
              }
            | _ => {
                ClickToPayLogger.logLifecycle(
                  ~event=CheckoutDeclined({provider: VisaUctp, code: actionCode}),
                )
                closeWindow(ERROR, JSON.Encode.null)
              }
            }
          }
        | None => {
            ClickToPayLogger.logLifecycle(~event=CheckoutFailed({provider: VisaUctp}))
            closeWindow(ERROR, JSON.Encode.null)
          }
        }
      } catch {
      | exn => {
          ClickToPayLogger.logLifecycle(~event=CheckoutFailed({provider: VisaUctp}), ~exn)
          closeWindow(ERROR, JSON.Encode.null)
        }
      }
    | NONE => closeWindow(ERROR, JSON.Encode.null)
    }
  | None => {
      ClickToPayLogger.logLifecycle(~event=PopupBlocked({provider: VisaUctp}))
      closeWindow(ERROR, JSON.Encode.null)
    }
  }
}

let handleProceedToPay = async (
  ~srcDigitalCardId: string="",
  ~encryptedCard: JSON.t=JSON.Encode.null,
  ~isCheckoutWithNewCard: bool=false,
  ~isUnrecognizedUser: bool=false,
  ~email: string="",
  ~phoneNumber: string="",
  ~countryCode: string="",
  ~rememberMe: bool=false,
  ~visaEncryptedCard: string="",
  ~clickToPayProvider,
  ~isClickToPayRememberMe=false,
  ~clickToPayToken,
  ~orderId="",
  ~fullName="",
) => {
  let handleCheckoutWithNewCard = async () => {
    switch clickToPayWindowRef.contents->Nullable.toOption {
    | Some(window) =>
      switch clickToPayProvider {
      | MASTERCARD => {
          let cardBrand = encryptedCard->Utils.getDictFromJson->Utils.getString("cardBrand", "")
          let encryptedCard =
            encryptedCard
            ->Utils.getDictFromJson
            ->Utils.getJsonFromDict("encryptedCard", JSON.Encode.null)
          let consumer = {
            emailAddress: email,
            mobileNumber: {
              phoneNumber,
              countryCode,
            },
          }
          let complianceSettings = {
            privacy: {
              acceptedVersion: "LATEST",
              latestVersion: "LATEST",
              latestVersionUri: "https://www.mastercard.com/global/click-to-pay/country-listing/privacy.html",
            },
            tnc: {
              acceptedVersion: "LATEST",
              latestVersion: "LATEST",
              latestVersionUri: "https://www.mastercard.com/global/click-to-pay/country-listing/terms.html",
            },
            cookie: {
              acceptedVersion: "LATEST",
              latestVersion: "LATEST",
              latestVersionUri: "https://www.mastercard.com/global/click-to-pay/en-us/privacy-notice.html",
            },
          }
          let payload = if isUnrecognizedUser {
            {
              windowRef: window,
              cardBrand,
              encryptedCard,
              rememberMe,
              complianceSettings,
              consumer,
            }
          } else {
            {
              windowRef: window,
              cardBrand,
              encryptedCard,
              rememberMe,
              complianceSettings,
            }
          }
          let checkoutResp = await checkoutWithNewCard(payload)

          switch checkoutResp {
          | Ok(response) => response->handleSuccessResponse
          | Error(_) => closeWindow(ERROR, JSON.Encode.null)
          }
        }
      | VISA =>
        let consumer = {
          fullName,
          emailAddress: email,
          mobileNumber: {
            phoneNumber,
            countryCode,
          },
        }
        try {
          switch clickToPayToken {
          | Some(token) => {
              let checkoutResp = await checkoutVisaUnified(
                ~encryptedCard=visaEncryptedCard,
                ~windowRef=window,
                ~newCard=true,
                ~clickToPayToken=token,
                ~orderId,
                ~consumer,
              )
              let actionCode =
                checkoutResp->Utils.getDictFromJson->Utils.getString("actionCode", "")
              switch actionCode {
              | "SUCCESS" => {
                  ClickToPayLogger.logLifecycle(~event=CheckoutCompleted({provider: VisaUctp}))
                  closeWindow(COMPLETE, checkoutResp)
                }
              | "CHANGE_CARD"
              | "SWITCH_CONSUMER" => {
                  ClickToPayLogger.logLifecycle(
                    ~event=CheckoutCancelled({provider: VisaUctp, code: actionCode}),
                  )
                  closeWindow(ERROR, JSON.Encode.null)
                }
              | _ => {
                  ClickToPayLogger.logLifecycle(
                    ~event=CheckoutDeclined({provider: VisaUctp, code: actionCode}),
                  )
                  closeWindow(ERROR, JSON.Encode.null)
                }
              }
            }
          | None => {
              ClickToPayLogger.logLifecycle(~event=CheckoutFailed({provider: VisaUctp}))
              closeWindow(ERROR, JSON.Encode.null)
            }
          }
        } catch {
        | exn => {
            ClickToPayLogger.logLifecycle(~event=CheckoutFailed({provider: VisaUctp}), ~exn)
            closeWindow(ERROR, JSON.Encode.null)
          }
        }
      | NONE => closeWindow(ERROR, JSON.Encode.null)
      }
    | None => {
        ClickToPayLogger.logLifecycle(~event=PopupBlocked({provider: VisaUctp}))
        closeWindow(ERROR, JSON.Encode.null)
      }
    }
  }

  try {
    if clickToPayWindowRef.contents->Nullable.toOption->Option.isNone {
      handleOpenClickToPayWindow()
    }
    if isCheckoutWithNewCard {
      await handleCheckoutWithNewCard()
    } else {
      await handleCheckoutWithCard(
        ~clickToPayProvider,
        ~srcDigitalCardId,
        ~fullName,
        ~email,
        ~phoneNumber,
        ~countryCode,
        ~clickToPayToken,
        ~isClickToPayRememberMe,
        ~orderId,
      )
    }
  } catch {
  | exn => {
      ClickToPayLogger.logLifecycle(~event=CheckoutFailed({provider: VisaUctp}), ~exn)
      closeWindow(ERROR, JSON.Encode.null)
    }
  }
}
