let useIsGuestCustomer = () => {
  let paymentMethodList = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)

  React.useMemo(() => {
    switch paymentMethodList {
    | Loaded(val) =>
      let pList = val->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper
      pList.isGuestCustomer
    | _ => true
    }
  }, [paymentMethodList])
}

let useHandlePostMessages = (~complete, ~empty, ~paymentType, ~savedMethod=false) => {
  open RecoilAtoms

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  React.useEffect(() => {
    Utils.handlePostMessageEvents(~complete, ~empty, ~paymentType, ~loggerState, ~savedMethod)
    None
  }, (complete, empty, paymentType))
}

let useIsCustomerAcceptanceRequired = (
  ~displaySavedPaymentMethodsCheckbox,
  ~isSaveCardsChecked,
  ~isGuestCustomer,
) => {
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

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
  let setRedirectionFlags = Recoil.useSetRecoilState(RecoilAtoms.redirectionFlagsAtom)
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
