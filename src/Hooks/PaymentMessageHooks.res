let useSubmitPaymentData = callback => {
  let {parentURL} = Jotai.useAtomValue(JotaiAtoms.keys)
  let isSectionActive = PaymentSectionContext.useIsActive()
  let activeCallback = React.useCallback((ev: Window.event) => {
    if isSectionActive {
      callback(ev)
    }
  }, (callback, isSectionActive))
  Utils.useSubmitPaymentDataFromParent(activeCallback, ~parentOrigin=parentURL)
}

// Pin the browser-provided origin only on an initialization from the direct parent.
let useParentMessageCheck = (~isInitialization) => {
  let origin = React.useRef(None)
  (ev: Window.event) => {
    if ev.source === Utils.iframeParent && PaymentMessageSecurity.isConcreteOrigin(ev.origin) {
      switch origin.current {
      | Some(expected) => ev.origin === expected
      | None =>
        let dict = ev.data->Utils.safeParse->Utils.getDictFromJson
        if isInitialization(dict) {
          origin.current = Some(ev.origin)
          true
        } else {
          false
        }
      }
    } else {
      false
    }
  }
}

// Fullscreen documents are initialized directly by their merchant parent.
let useFullscreenParentCheck = () =>
  useParentMessageCheck(~isInitialization=dict =>
    dict->Utils.getBool("fullScreenIframeMounted", false)
  )
