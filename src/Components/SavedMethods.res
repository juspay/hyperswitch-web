@react.component
let make = (
  ~paymentToken,
  ~setPaymentToken,
  ~savedMethods: array<PaymentType.customerMethods>,
  ~loadSavedCards: PaymentType.savedCardsLoadState,
  ~cvcProps,
  ~paymentType,
) => {
  open CardUtils
  open Utils
  open UtilityHooks
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (showFields, setShowFields) = Recoil.useRecoilState(RecoilAtoms.showCardFieldsAtom)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
    loggerState.setLogError(~value=message, ~eventName=INVALID_FORMAT, ())
  }
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ => false)
  let {displaySavedPaymentMethodsCheckbox} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let isGuestCustomer = useIsGuestCustomer()

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let (token, _) = paymentToken
  let savedCardlength = savedMethods->Array.length
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let getWalletBrandIcon = (obj: PaymentType.customerMethods) => {
    switch obj.paymentMethodType {
    | Some("apple_pay") => <Icon size=brandIconSize name="apple_pay_saved" />
    | Some("google_pay") => <Icon size=brandIconSize name="google_pay_saved" />
    | Some("paypal") => <Icon size=brandIconSize name="paypal" />
    | _ => <Icon size=brandIconSize name="default-card" />
    }
  }

  let isCustomerAcceptanceRequired = useIsCustomerAcceptanceRequired(
    ~displaySavedPaymentMethodsCheckbox,
    ~isSaveCardsChecked,
    ~isGuestCustomer,
  )

  let bottomElement = {
    savedMethods
    ->Array.mapWithIndex((obj, i) => {
      let brandIcon = switch obj.paymentMethod {
      | "wallet" => getWalletBrandIcon(obj)
      | _ =>
        getCardBrandIcon(
          switch obj.card.scheme {
          | Some(ele) => ele
          | None => ""
          }->getCardType,
          ""->CardThemeType.getPaymentMode,
        )
      }
      let isActive = token == obj.paymentToken
      <SavedCardItem
        key={i->Belt.Int.toString}
        setPaymentToken
        isActive
        paymentItem=obj
        brandIcon
        index=i
        savedCardlength
        cvcProps
        paymentType
        setRequiredFieldsBody
      />
    })
    ->React.array
  }

  let (isCVCValid, _, cvcNumber, _, _, _, _, _, _, setCvcError) = cvcProps
  let complete = switch isCVCValid {
  | Some(val) => token !== "" && val
  | _ => false
  }
  let empty = cvcNumber == ""
  let (token, customerId) = paymentToken
  let customerMethod =
    savedMethods
    ->Array.filter(savedMethod => {
      savedMethod.paymentToken === token
    })
    ->Array.get(0)
    ->Option.getOr(PaymentType.defaultCustomerMethods)
  let isUnknownPaymentMethod = customerMethod.paymentMethod === ""
  let isCardPaymentMethod = customerMethod.paymentMethod === "card"
  let isCardPaymentMethodValid = !customerMethod.requiresCvv || (complete && !empty)

  let complete =
    areRequiredFieldsValid &&
    !isUnknownPaymentMethod &&
    (!isCardPaymentMethod || isCardPaymentMethodValid)

  let paymentType = customerMethod.paymentMethodType->Option.getOr(customerMethod.paymentMethod)

  useHandlePostMessages(~complete, ~empty, ~paymentType, ~savedMethod=true)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    let savedPaymentMethodBody = switch customerMethod.paymentMethod {
    | "card" =>
      PaymentBody.savedCardBody(
        ~paymentToken=token,
        ~customerId,
        ~cvcNumber,
        ~requiresCvv=customerMethod.requiresCvv,
        ~isCustomerAcceptanceRequired,
      )
    | _ => {
        let paymentMethodType = switch customerMethod.paymentMethodType {
        | Some("")
        | None => JSON.Encode.null
        | Some(paymentMethodType) => paymentMethodType->JSON.Encode.string
        }
        PaymentBody.savedPaymentMethodBody(
          ~paymentToken=token,
          ~customerId,
          ~paymentMethod=customerMethod.paymentMethod,
          ~paymentMethodType,
          ~isCustomerAcceptanceRequired,
        )
      }
    }

    if confirm.doSubmit {
      if (
        areRequiredFieldsValid &&
        !isUnknownPaymentMethod &&
        (!isCardPaymentMethod || isCardPaymentMethodValid) &&
        confirm.confirmTimestamp >= confirm.readyTimestamp
      ) {
        intent(
          ~bodyArr=savedPaymentMethodBody
          ->Dict.fromArray
          ->JSON.Encode.object
          ->flattenObject(true)
          ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->getArrayOfTupleFromDict,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          (),
        )
      } else {
        if isUnknownPaymentMethod || confirm.confirmTimestamp < confirm.readyTimestamp {
          setUserError(localeString.selectPaymentMethodText)
        }
        if !isUnknownPaymentMethod && cvcNumber === "" {
          setCvcError(_ => localeString.cvcNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if !(isCVCValid->Option.getOr(false)) {
          setUserError(localeString.enterValidDetailsText)
        }
        if !areRequiredFieldsValid {
          setUserError(localeString.enterValidDetailsText)
        }
      }
    }
  }, (
    areRequiredFieldsValid,
    requiredFieldsBody,
    empty,
    complete,
    customerMethod,
    isCustomerAcceptanceRequired,
  ))
  useSubmitPaymentData(submitCallback)

  let conditionsForShowingSaveCardCheckbox = React.useMemo(() => {
    !isGuestCustomer &&
    paymentMethodListValue.payment_type === NEW_MANDATE &&
    displaySavedPaymentMethodsCheckbox
  }, (isGuestCustomer, paymentMethodListValue.payment_type, displaySavedPaymentMethodsCheckbox))

  <div className="flex flex-col overflow-auto h-auto no-scrollbar animate-slowShow">
    {if savedCardlength === 0 && (loadSavedCards === PaymentType.LoadingSavedCards || !showFields) {
      <div
        className="Label flex flex-row gap-3 items-end cursor-pointer"
        style={ReactDOMStyle.make(
          ~fontSize="14px",
          ~color=themeObj.colorPrimary,
          ~fontWeight="400",
          ~marginTop="25px",
          (),
        )}>
        <PaymentElementShimmer.Shimmer>
          <div className="animate-pulse w-full h-12 rounded bg-slate-200">
            <div className="flex flex-row my-auto">
              <div className="w-10 h-5 rounded-full m-3 bg-white bg-opacity-70" />
              <div className="my-auto w-24 h-2 rounded m-3 bg-white bg-opacity-70" />
            </div>
          </div>
        </PaymentElementShimmer.Shimmer>
      </div>
    } else {
      <RenderIf condition={!showFields}> {bottomElement} </RenderIf>
    }}
    <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
      <div className="pt-4 pb-2 flex items-center justify-start">
        <SaveDetailsCheckbox isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked />
      </div>
    </RenderIf>
    <RenderIf condition={paymentMethodListValue.payment_type === SETUP_MANDATE}>
      <div
        className="opacity-50 text-xs mb-2 text-left"
        style={ReactDOMStyle.make(
          ~color=themeObj.colorText,
          ~marginTop=themeObj.spacingGridColumn,
          (),
        )}>
        <Terms mode={Card} />
      </div>
    </RenderIf>
    <RenderIf condition={!showFields}>
      <div
        className="Label flex flex-row gap-3 items-end cursor-pointer"
        style={ReactDOMStyle.make(
          ~fontSize="14px",
          ~float="left",
          ~marginTop="14px",
          ~fontWeight="500",
          ~width="fit-content",
          ~color=themeObj.colorPrimary,
          (),
        )}
        onClick={_ => setShowFields(_ => true)}>
        <Icon name="circle-plus" size=22 />
        {React.string(localeString.morePaymentMethods)}
      </div>
    </RenderIf>
  </div>
}
