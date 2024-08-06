@react.component
let make = (~savedMethods: array<PaymentType.customerMethods>, ~setSavedMethods) => {
  open CardUtils
  open Utils

  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let {config} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let switchToCustomPod = Recoil.useRecoilValueFromAtom(RecoilAtoms.switchToCustomPod)
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let removeSavedMethod = (
    savedMethods: array<OrcaPaymentPage.PaymentType.customerMethods>,
    paymentMethodId,
  ) => {
    savedMethods->Array.filter(savedMethod => {
      savedMethod.paymentMethodId !== paymentMethodId
    })
  }

  let handleDelete = (paymentItem: PaymentType.customerMethods) => {
    handlePostMessage([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
    ])
    open Promise
    PaymentHelpers.deletePaymentMethod(
      ~ephemeralKey=config.ephemeralKey,
      ~paymentMethodId=paymentItem.paymentMethodId,
      ~logger,
      ~switchToCustomPod,
    )
    ->then(res => {
      let dict = res->getDictFromJson
      let paymentMethodId = dict->getString("payment_method_id", "")
      let isDeleted = dict->getBool("deleted", false)

      if isDeleted {
        logger.setLogInfo(
          ~value="Successfully Deleted Saved Payment Method",
          ~eventName=DELETE_SAVED_PAYMENT_METHOD,
        )
        setSavedMethods(prev => prev->removeSavedMethod(paymentMethodId))
      } else {
        logger.setLogError(~value=res->JSON.stringify, ~eventName=DELETE_SAVED_PAYMENT_METHOD)
      }
      handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
      resolve()
    })
    ->catch(err => {
      let exceptionMessage = err->formatException->JSON.stringify
      logger.setLogError(
        ~value=`Error Deleting Saved Payment Method: ${exceptionMessage}`,
        ~eventName=DELETE_SAVED_PAYMENT_METHOD,
      )
      handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
      resolve()
    })
    ->ignore
  }

  savedMethods
  ->Array.mapWithIndex((obj, i) => {
    let brandIcon = obj->getPaymentMethodBrand
    <SavedMethodItem key={i->Int.toString} paymentItem=obj brandIcon handleDelete />
  })
  ->React.array
}
