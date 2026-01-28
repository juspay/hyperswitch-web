open Promise
let scriptId = "mastercard-external-script"

let getScriptSrc = () => {
  let clickToPayMastercardBaseUrl = GlobalVars.isProd
    ? "https://src.mastercard.com"
    : "https://sandbox.src.mastercard.com"
  clickToPayMastercardBaseUrl ++ "/srci/integration/2/lib.js"
}

let srcUiKitScriptSrc = "https://src.mastercard.com/srci/integration/components/src-ui-kit/src-ui-kit.esm.js"
let srcUiKitCssHref = "https://src.mastercard.com/srci/integration/components/src-ui-kit/src-ui-kit.css"

let recognitionTokenCookieName = "__mastercard_click_to_pay"
let manualCardId = "click_to_pay_manual_card"
let savedCardId = "click_to_pay_saved_card_"

let orderIdRef = ref("")

type ctpProviderType = VISA | MASTERCARD | NONE

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

// Global window extensions
type mastercardCheckoutServices

@val
external mastercardCheckoutServices: mastercardCheckoutServices =
  "window.MastercardCheckoutServices"

// Response types
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

// Cookie helpers
@val external document: {..} = "document"

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

type ctpLogType = {
  ctpProvider: string,
  message: string,
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

// Update the previously defined mastercardCheckoutServices type
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

// Add the CheckoutWithNewCardPayload type
type checkoutWithNewCardPayload = {
  windowRef: Types.window,
  cardBrand: string,
  encryptedCard: JSON.t,
  rememberMe: bool,
  consumer?: consumer,
  complianceSettings: complianceSettings,
}

let mcCheckoutService: ref<option<mastercardCheckoutServices>> = ref(None)

// First, let's add the ClickToPayOptions type
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

// Add the init external
@send
external init: (mastercardCheckoutServices, params) => promise<JSON.t> = "init"

// First add this external to check window property
@val @scope("window")
external getOptionMastercardCheckoutServices: option<unit => mastercardCheckoutServices> =
  "MastercardCheckoutServices"

@new @scope("window")
external getMastercardCheckoutServices: unit => mastercardCheckoutServices =
  "MastercardCheckoutServices"

// Then update the initialization function
let initializeMastercardCheckout = (
  clickToPayToken: clickToPayToken,
  logger: HyperLoggerTypes.loggerMake,
) => {
  switch getOptionMastercardCheckoutServices {
  | Some(_) => {
      logger.setLogInfo(
        ~value={
          "message": "MastercardCheckoutServices constructor found",
          "scheme": "MASTERCARD",
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      // Create new instance by calling the constructor
      mcCheckoutService := Some(getMastercardCheckoutServices())

      // Get recognition token
      let recognitionToken = getLocalStorage(~key=recognitionTokenCookieName)
      logger.setLogInfo(
        ~value={
          "message": "Recognition token fetched",
          "scheme": "MASTERCARD",
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      // Construct params
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

      // Add recognition token if exists
      let params = switch recognitionToken->Nullable.toOption {
      | Some(token) => {...params, recognitionToken: token}
      | None => params
      }

      try {
        switch mcCheckoutService.contents {
        | Some(service) => {
            logger.setLogInfo(
              ~value={
                "message": "Mastercard Checkout Service initialized",
                "scheme": "MASTERCARD",
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
            service
            ->init(params)
            ->then(resp => {
              logger.setLogInfo(
                ~value={
                  "message": "Mastercard Checkout initialized",
                  "scheme": "MASTERCARD",
                }
                ->JSON.stringifyAny
                ->Option.getOr(""),
                ~eventName=CLICK_TO_PAY_FLOW,
              )
              resolve(resp)
            })
            ->catch(err => {
              logger.setLogError(
                ~value={
                  "message": `Error initializing Mastercard Checkout - ${err
                    ->Utils.formatException
                    ->JSON.stringify}`,
                  "scheme": "MASTERCARD",
                }
                ->JSON.stringifyAny
                ->Option.getOr(""),
                ~eventName=CLICK_TO_PAY_FLOW,
              )
              reject(err)
            })
          }
        | None => {
            logger.setLogError(
              ~value={
                "message": "Mastercard Checkout Service not initialized",
                "scheme": "MASTERCARD",
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
            reject(Exn.anyToExnInternal("Mastercard Checkout Service not initialized"))
          }
        }
      } catch {
      | error => {
          logger.setLogError(
            ~value={
              "message": `Error initializing Mastercard Checkout - ${error
                ->Utils.formatException
                ->JSON.stringify}`,
              "scheme": "MASTERCARD",
            }
            ->JSON.stringifyAny
            ->Option.getOr(""),
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          reject(error)
        }
      }
    }
  | None => {
      logger.setLogError(
        ~value={
          "message": "MastercardCheckoutServices is not available",
          "scheme": "MASTERCARD",
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      reject(Exn.anyToExnInternal("MastercardCheckoutServices is not available"))
    }
  }
}

let getCards = async (logger: HyperLoggerTypes.loggerMake) => {
  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        let cards = await service->getCards()
        logger.setLogInfo(
          ~value={
            "message": "Cards returned from API",
            "scheme": "MASTERCARD",
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        Ok(cards)
      }
    | None => {
        logger.setLogError(
          ~value={
            "message": "Mastercard Checkout Service not initialized",
            "scheme": "MASTERCARD",
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        Ok([])
      }
    }
  } catch {
  | error => {
      logger.setLogError(
        ~value={
          "message": `Error getting cards - ${error->Utils.formatException->JSON.stringify}`,
          "scheme": "MASTERCARD",
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      Ok([])
    }
  }
}

// First, let's define the AuthenticatePayload type
type authenticateInputPayload = {
  windowRef: Types.window,
  consumerIdentity: consumerIdentity,
}

// Add this external for getting hostname
@val @scope(("window", "location"))
external hostname: string = "hostname"

let authenticate = async (
  payload: authenticateInputPayload,
  logger: HyperLoggerTypes.loggerMake,
) => {
  // Construct the authenticate payload
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
        let authentication = await service->authenticate(authenticatePayload)

        // Check and set recognition token if present
        let recognitionToken =
          authentication->Utils.getDictFromJson->Utils.getString("recognitionToken", "")

        if recognitionToken !== "" {
          setLocalStorage(~key=recognitionTokenCookieName, ~value=recognitionToken)
        }

        Ok(authentication)
      }
    | None => {
        logger.setLogError(
          ~value={
            "message": "Mastercard Checkout Service not initialized",
            "scheme": "MASTERCARD",
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        Error(Exn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => {
      logger.setLogError(
        ~value={
          "message": `Error during authentication - ${error
            ->Utils.formatException
            ->JSON.stringify}`,
          "scheme": "MASTERCARD",
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      Error(error)
    }
  }
}

let checkoutWithCard = async (
  ~windowRef: Types.window,
  ~srcDigitalCardId: string,
  ~logger: HyperLoggerTypes.loggerMake,
) => {
  let checkoutPayload = {
    windowRef,
    srcDigitalCardId,
    rememberMe: true,
  }

  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        let checkoutResp = await service->checkoutWithCard(checkoutPayload)
        Ok(checkoutResp)
      }
    | None => {
        logger.setLogError(
          ~value={
            "message": "Mastercard Checkout Service not initialized",
            "scheme": "MASTERCARD",
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        Error(Exn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => {
      logger.setLogError(
        ~value={
          "message": `Error during checkout with card - ${error
            ->Utils.formatException
            ->JSON.stringify}`,
          "scheme": "MASTERCARD",
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      Error(error)
    }
  }
}

let encryptCardForClickToPay = async (
  ~cardNumber,
  ~expiryMonth,
  ~expiryYear,
  ~cvcNumber,
  ~logger: HyperLoggerTypes.loggerMake,
) => {
  let card: encryptCardPayload = {
    primaryAccountNumber: cardNumber,
    panExpirationMonth: expiryMonth,
    panExpirationYear: expiryYear,
    cardSecurityCode: cvcNumber,
  }
  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        logger.setLogError(
          ~value={
            "message": "Encrypting card for Click to Pay",
            "scheme": "MASTERCARD",
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        let encryptedCard = await service->encryptCard(card)
        Ok(encryptedCard)
      }
    | None => {
        logger.setLogError(
          ~value={
            "message": "Mastercard Checkout Service not initialized",
            "scheme": "MASTERCARD",
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        Error(Exn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => {
      logger.setLogError(
        ~value={
          "message": `Error encrypting card - ${error->Utils.formatException->JSON.stringify}`,
          "scheme": "MASTERCARD",
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      Error(error)
    }
  }
}

@send
external checkoutWithNewCard: (
  mastercardCheckoutServices,
  checkoutWithNewCardPayload,
) => promise<JSON.t> = "checkoutWithNewCard"

let checkoutWithNewCard = async (
  payload: checkoutWithNewCardPayload,
  ~logger: HyperLoggerTypes.loggerMake,
) => {
  try {
    switch mcCheckoutService.contents {
    | Some(service) => {
        let checkoutResp = await service->checkoutWithNewCard(payload->Obj.magic)
        Ok(checkoutResp)
      }
    | None => {
        logger.setLogError(
          ~value={
            "message": "Mastercard Checkout Service not initialized",
            "scheme": "MASTERCARD",
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
        Error(Exn.anyToExnInternal("Mastercard Checkout Service not initialized"))
      }
    }
  } catch {
  | error => {
      logger.setLogError(
        ~value={
          "message": `Error during checkout with new card - ${error
            ->Utils.formatException
            ->JSON.stringify}`,
          "scheme": "MASTERCARD",
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      Error(error)
    }
  }
}

// Add these externals at the top with other DOM-related externals
@val @scope("document")
external querySelector: string => Nullable.t<Dom.element> = "querySelector"

@val @scope("document")
external createElement: string => Dom.element = "createElement"

@val @scope(("document", "head"))
external appendChild: Dom.element => unit = "appendChild"

@set external setType: (Dom.element, string) => unit = "type"
@set external setSrc: (Dom.element, string) => unit = "src"
@set external setRel: (Dom.element, string) => unit = "rel"
@set external setHref: (Dom.element, string) => unit = "href"
@set external setOnload: (Dom.element, unit => unit) => unit = "onload"
@val @scope(("top", "location"))
external topLocationHref: string = "href"

// Add these externals for script events
@set external setOnError: (Dom.element, unit => unit) => unit = "onerror"

// Add the function at the end of the file
let loadClickToPayScripts = (logger: HyperLoggerTypes.loggerMake) => {
  Promise.make((clickToPayScriptsPromiseResolve, _) => {
    let scriptSelector = `script[src="${srcUiKitScriptSrc}"]`
    let linkSelector = `link[href="${srcUiKitCssHref}"]`

    // Add script if not exists
    let srcUiKitScriptPromise = Promise.make((scriptPromiseResolve, _) => {
      switch querySelector(scriptSelector)->Nullable.toOption {
      | None => {
          let script = createElement("script")
          script->setType("module")
          script->setSrc(srcUiKitScriptSrc)
          script->setOnload(
            () => {
              logger.setLogInfo(
                ~value="ClickToPay UI Kit Script Loaded",
                ~eventName=CLICK_TO_PAY_SCRIPT,
              )
              scriptPromiseResolve()
            },
          )
          appendChild(script)
        }
      | Some(_) => scriptPromiseResolve()
      }
    })

    // Add link if not exists
    let srcUiKitCssPromise = Promise.make((cssPromiseResolve, _) => {
      switch querySelector(linkSelector)->Nullable.toOption {
      | None => {
          let link = createElement("link")
          link->setRel("stylesheet")
          link->setHref(srcUiKitCssHref)
          link->setOnload(
            () => {
              logger.setLogInfo(
                ~value="ClickToPay UI Kit CSS Loaded",
                ~eventName=CLICK_TO_PAY_SCRIPT,
              )
              cssPromiseResolve()
            },
          )
          appendChild(link)
        }
      | Some(_) => cssPromiseResolve()
      }
    })

    Promise.all([srcUiKitScriptPromise, srcUiKitCssPromise])
    ->then(_ => {
      clickToPayScriptsPromiseResolve()
      resolve()
    })
    ->catch(_ => {
      logger.setLogError(~value="ClickToPay UI Kit CSS Load Error", ~eventName=CLICK_TO_PAY_SCRIPT)
      resolve()
    })
    ->ignore
  })
}

// Add this function at the end of the file
let loadMastercardScript = (clickToPayToken, logger: HyperLoggerTypes.loggerMake) => {
  let scriptSrc = getScriptSrc()
  Promise.make((resolve, reject) => {
    let scriptSelector = `script[src="${scriptSrc}"]`

    switch querySelector(scriptSelector)->Nullable.toOption {
    | Some(_) => {
        logger.setLogInfo(~value="Mastercard Script Already Exists", ~eventName=CLICK_TO_PAY_SCRIPT)
        // Script already exists, just initialize
        initializeMastercardCheckout(clickToPayToken, logger)
        ->then(resp => {
          resp->resolve
          Promise.resolve()
        })
        ->catch(err => {
          err->reject
          Promise.resolve()
        })
        ->ignore
      }
    | None => {
        let script = createElement("script")
        script->setType("text/javascript")
        script->setSrc(scriptSrc)

        // Set onload handler
        script->setOnload(() => {
          logger.setLogInfo(
            ~value="Script loaded, initializing Mastercard Checkout",
            ~eventName=CLICK_TO_PAY_SCRIPT,
          )
          // Initialize after script loads
          initializeMastercardCheckout(clickToPayToken, logger)
          ->then(
            resp => {
              resp->resolve
              Promise.resolve()
            },
          )
          ->catch(
            err => {
              err->reject
              Promise.resolve()
            },
          )
          ->ignore
        })

        // Set onerror handler
        script->setOnError(() => {
          logger.setLogError(
            ~value="Error loading Mastercard script",
            ~eventName=CLICK_TO_PAY_SCRIPT,
          )
          let exn = Exn.anyToExnInternal("Failed to load Mastercard script")
          exn->reject
        })

        appendChild(script)
      }
    }
  })
}

// Define props types for each component
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

// Components in modules with capitalized names (React convention)
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

type paramUrl = {
  key: string,
  value: string,
}

let defaultParamUrl = {
  key: "",
  value: "",
}

let urlToParamUrlItemToObjMapper = url => {
  let params = url->String.replace("?", "")->String.split("&")
  params
  ->Array.filter(param => param !== "")
  ->Array.map(param => {
    let paramValues = param->String.split("=")
    {
      key: paramValues->Array.get(0)->Option.getOr(""),
      value: paramValues->Array.get(1)->Option.getOr(""),
    }
  })
}

// First add the external binding for signOut
@send
external signOutMastercard: mastercardCheckoutServices => promise<JSON.t> = "signOut"

// Then add the signOut function implementation
let signOut = async () => {
  try {
    deleteLocalStorage(~key=recognitionTokenCookieName)

    switch mcCheckoutService.contents {
    | Some(service) => {
        let signOutResp = await service->signOutMastercard
        Ok(signOutResp)
      }
    | None => {
        Console.error("Mastercard Checkout Service not initialized")
        Error(Exn.anyToExnInternal("Mastercard Checkout Service not initialized"))
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

let getStrFromActionCode = actionCode => {
  switch actionCode {
  | SUCCESS => "SUCCESS"
  | PENDING_CONSUMER_IDV => "PENDING_CONSUMER_IDV"
  | FAILED => "FAILED"
  | ERROR => "ERROR"
  | ADD_CARD => "ADD_CARD"
  }
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

let getCardsVisaUnified = (~getCardsConfig) => vsdk.getCards(getCardsConfig)
let signOutVisaUnified = () => vsdk.unbindAppInstance()

let loadVisaScript = (clickToPayToken: clickToPayToken, onLoadCallback, onErrorCallback) => {
  let cardBrands = clickToPayToken.cardBrands->Array.join(",")
  let scriptSrc = GlobalVars.isProd
    ? `https://secure.checkout.visa.com/checkout-widget/resources/js/integration/v2/sdk.js?dpaId=${clickToPayToken.dpaId}&locale=${clickToPayToken.locale}&cardBrands=${cardBrands}&dpaClientId=${clickToPayToken.dpaName}`
    : `https://sandbox.secure.checkout.visa.com/checkout-widget/resources/js/integration/v2/sdk.js?dpaId=${clickToPayToken.dpaId}&locale=${clickToPayToken.locale}&cardBrands=${cardBrands}&dpaClientId=${clickToPayToken.dpaName}`
  let script = createElement("script")
  script->setType("text/javascript")
  script->setSrc(scriptSrc)
  script->setOnload(onLoadCallback)
  script->setOnError(onErrorCallback)
  body->Window.appendChild(script)
}

let loadClickToPayUIScripts = (
  logger: HyperLoggerTypes.loggerMake,
  scriptLoadedCallback: unit => unit,
  scriptErrorCallback: unit => unit,
) => {
  let scriptSelector = `script[src="${srcUiKitScriptSrc}"]`
  let linkSelector = `link[href="${srcUiKitCssHref}"]`

  // Add script if not exists
  switch querySelector(scriptSelector)->Nullable.toOption {
  | None => {
      let script = createElement("script")
      script->setType("module")
      script->setSrc(srcUiKitScriptSrc)
      appendChild(script)
      script->setOnload(() => {
        scriptLoadedCallback()
      })
      script->setOnError(() => {
        scriptErrorCallback()
      })
      logger.setLogInfo(~value="ClickToPay UI Kit Script Loaded", ~eventName=CLICK_TO_PAY_SCRIPT)
    }
  | Some(_) => ()
  }

  // Add link if not exists
  switch querySelector(linkSelector)->Nullable.toOption {
  | None => {
      let link = createElement("link")
      link->setRel("stylesheet")
      link->setHref(srcUiKitCssHref)
      appendChild(link)
      logger.setLogInfo(~value="ClickToPay UI Kit CSS Loaded", ~eventName=CLICK_TO_PAY_SCRIPT)
    }
  | Some(_) => ()
  }
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
  await vsdk.checkout(checkoutConfig)
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
  ~logger,
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
        let checkoutResp = await checkoutWithCard(~windowRef=window, ~srcDigitalCardId, ~logger)
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
                logger.setLogInfo(
                  ~value={
                    "message": "Checkout successfull",
                    "scheme": clickToPayProvider,
                  }
                  ->JSON.stringifyAny
                  ->Option.getOr(""),
                  ~eventName=CLICK_TO_PAY_FLOW,
                )
                closeWindow(COMPLETE, checkoutResp)
              }
            | _ => {
                logger.setLogError(
                  ~value={
                    "message": `Visa checkout failed with card, Action Code -> ${actionCode}`,
                    "scheme": clickToPayProvider,
                  }
                  ->JSON.stringifyAny
                  ->Option.getOr(""),
                  ~eventName=CLICK_TO_PAY_FLOW,
                )
                closeWindow(ERROR, JSON.Encode.null)
              }
            }
          }
        | None => closeWindow(ERROR, JSON.Encode.null)
        }
      } catch {
      | err => {
          logger.setLogError(
            ~value={
              "message": `Visa checkout failed with card - ${err
                ->Utils.formatException
                ->JSON.stringify}`,
              "scheme": clickToPayProvider,
            }
            ->JSON.stringifyAny
            ->Option.getOr(""),
            ~eventName=CLICK_TO_PAY_FLOW,
          )
          closeWindow(ERROR, JSON.Encode.null)
        }
      }
    | NONE => closeWindow(ERROR, JSON.Encode.null)
    }
  | None => {
      logger.setLogError(
        ~value={
          "message": "Click to Pay window reference is null",
          "scheme": clickToPayProvider,
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
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
  ~logger: HyperLoggerTypes.loggerMake,
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
          let checkoutResp = await checkoutWithNewCard(payload, ~logger)

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
                  logger.setLogInfo(
                    ~value={
                      "message": "Checkout successfull",
                      "scheme": clickToPayProvider,
                    }
                    ->JSON.stringifyAny
                    ->Option.getOr(""),
                    ~eventName=CLICK_TO_PAY_FLOW,
                  )
                  closeWindow(COMPLETE, checkoutResp)
                }
              | _ => {
                  logger.setLogError(
                    ~value={
                      "message": `Visa checkout failed with new card, Action Code -> ${actionCode}`,
                      "scheme": clickToPayProvider,
                    }
                    ->JSON.stringifyAny
                    ->Option.getOr(""),
                    ~eventName=CLICK_TO_PAY_FLOW,
                  )
                  closeWindow(ERROR, JSON.Encode.null)
                }
              }
            }
          | None => closeWindow(ERROR, JSON.Encode.null)
          }
        } catch {
        | err => {
            logger.setLogError(
              ~value={
                "message": `Visa checkout failed with new card - ${err
                  ->Utils.formatException
                  ->JSON.stringify}`,
                "scheme": clickToPayProvider,
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
            closeWindow(ERROR, JSON.Encode.null)
          }
        }
      | NONE => closeWindow(ERROR, JSON.Encode.null)
      }
    | None => {
        logger.setLogError(
          ~value={
            "message": "Click to Pay window reference is null",
            "scheme": clickToPayProvider,
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
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
        ~logger,
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
  | err => {
      logger.setLogError(
        ~value={
          "message": `Error during checkout - ${err->Utils.formatException->JSON.stringify}`,
          "scheme": clickToPayProvider,
        }
        ->JSON.stringifyAny
        ->Option.getOr(""),
        ~eventName=CLICK_TO_PAY_FLOW,
      )
      closeWindow(ERROR, JSON.Encode.null)
    }
  }
}
