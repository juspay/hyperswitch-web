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
  ~loggedPaymentMethod: option<LoggerPaymentMethod.paymentMethod>=?,
) => {
  let wasComplete = React.useRef(false)

  React.useEffect(() => {
    if enabled {
      Utils.handlePostMessageEvents(~complete, ~empty, ~paymentType)
    }
    None
  }, (complete, empty, paymentType, enabled))

  let sawIncomplete = React.useRef(false)

  React.useEffect(() => {
    if enabled {
      if !complete {
        sawIncomplete.current = true
      } else if !wasComplete.current && sawIncomplete.current {
        SdkLogger.logState(
          ~event=PaymentFormCompleted({savedMethod: savedMethod}),
          ~paymentMethod=?loggedPaymentMethod,
        )
      }
    }
    wasComplete.current = complete
    None
  }, (complete, paymentType, savedMethod, enabled))
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

let useSendEventsToParent = eventsToSendToParent => {
  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let eventDataObject = ev.data->Identity.anyTypeToJson
      let eventsDict = eventDataObject->Utils.getDictFromJson

      let events = eventsDict->Dict.keysToArray

      let shouldSendToParent =
        events->Array.some(event => eventsToSendToParent->Array.includes(event))

      if shouldSendToParent {
        Utils.messageParentWindow(eventsDict->Dict.toArray)
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })
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
