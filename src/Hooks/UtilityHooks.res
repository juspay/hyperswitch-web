let useIsGuestCustomer = () => {
  let {customerPaymentMethods} = RecoilAtoms.optionAtom->Recoil.useRecoilValueFromAtom

  React.useMemo(() => {
    switch customerPaymentMethods {
    | LoadedSavedCards(_, false)
    | NoResult(false) => false
    | _ => true
    }
  }, [customerPaymentMethods])
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
    let optionalShouldUseTopRedirection =
      paymentOptions
      ->Dict.get("shouldUseTopRedirection")
      ->Option.flatMap(JSON.Decode.bool)
    let optionalShouldRemoveBeforeUnloadEvents =
      paymentOptions
      ->Dict.get("shouldRemoveBeforeUnloadEvents")
      ->Option.flatMap(JSON.Decode.bool)

    switch (optionalShouldUseTopRedirection, optionalShouldRemoveBeforeUnloadEvents) {
    | (None, None) => ()
    | (shouldUseTopRedirection, shouldRemoveBeforeUnloadEvents) =>
      setRedirectionFlags(cv => {
        shouldUseTopRedirection: shouldUseTopRedirection->Option.getOr(cv.shouldUseTopRedirection),
        shouldRemoveBeforeUnloadEvents: shouldRemoveBeforeUnloadEvents->Option.getOr(
          cv.shouldRemoveBeforeUnloadEvents,
        ),
      })
    }
  }
  updateRedirectionFlagsAtom
}
