let useIsGuestCustomer = () => {
  let paymentMethodList = Jotai.useAtomValue(JotaiAtoms.paymentMethodList)
  let {customerPaymentMethods} = JotaiAtoms.optionAtom->Jotai.useAtomValue

  React.useMemo(() => {
    switch paymentMethodList {
    | Loaded(val) =>
      let pList = val->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapperFromClientList
      let guestCustomerValue = pList.isGuestCustomer
      if guestCustomerValue->Option.isNone {
        switch customerPaymentMethods {
        | LoadedSavedCards(_, false)
        | NoResult(false) => false
        | _ => true
        }
      } else {
        guestCustomerValue->Option.getOr(true)
      }
    | _ => true
    }
  }, (paymentMethodList, customerPaymentMethods))
}

let useHandlePostMessages = (
  ~complete,
  ~empty,
  ~paymentType,
  ~savedMethod=false,
  ~enabled=true,
) => {
  open JotaiAtoms

  let loggerState = Jotai.useAtomValue(loggerAtom)

  React.useEffect(() => {
    if enabled {
      Utils.handlePostMessageEvents(~complete, ~empty, ~paymentType, ~loggerState, ~savedMethod)
    }
    None
  }, (complete, empty, paymentType, savedMethod, enabled))
}

let useIsCustomerAcceptanceRequired = (
  ~displaySavedPaymentMethodsCheckbox,
  ~isSaveCardsChecked,
  ~isGuestCustomer,
) => {
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)

  React.useMemo(() => {
    if displaySavedPaymentMethodsCheckbox {
      isSaveCardsChecked || paymentMethodListValue.payment_type === SETUP_MANDATE
    } else {
      !(isGuestCustomer || paymentMethodListValue.payment_type === NORMAL)
    }
  }, (
    isSaveCardsChecked,
    paymentMethodListValue.payment_type,
    isGuestCustomer,
    displaySavedPaymentMethodsCheckbox,
  ))
}

let useSendEventsToParent = (~isTrustedChild, eventsToSendToParent) => {
  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      let eventDataObject = ev.data->Identity.anyTypeToJson
      let eventsDict = eventDataObject->Utils.getDictFromJson

      let isFromChildFrame =
        Window.querySelectorAll("iframe")->Array.some(iframe =>
          ev.source === iframe->Window.contentWindow
        )
      let allowedEvents =
        eventsDict
        ->Dict.toArray
        ->Array.filter(((key, _)) => eventsToSendToParent->Array.includes(key))

      if isFromChildFrame && isTrustedChild(ev) && allowedEvents->Array.length > 0 {
        Utils.messageParentWindow(allowedEvents)
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  }, [isTrustedChild])
}

let useUpdateRedirectionFlags = () => {
  let setRedirectionFlags = Jotai.useSetAtom(JotaiAtoms.redirectionFlagsAtom)
  let updateRedirectionFlagsAtom = paymentOptions => {
    let topRedirection =
      paymentOptions
      ->Dict.get("shouldUseTopRedirection")
      ->Option.flatMap(JSON.Decode.bool)
    let removeBeforeUnloadEvents =
      paymentOptions
      ->Dict.get("shouldRemoveBeforeUnloadEvents")
      ->Option.flatMap(JSON.Decode.bool)

    setRedirectionFlags(cv => {
      shouldUseTopRedirection: topRedirection->Option.getOr(cv.shouldUseTopRedirection),
      shouldRemoveBeforeUnloadEvents: removeBeforeUnloadEvents->Option.getOr(
        cv.shouldRemoveBeforeUnloadEvents,
      ),
    })
  }
  updateRedirectionFlagsAtom
}
