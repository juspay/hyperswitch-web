open RecoilAtoms
open Utils
open CardUtils

@react.component
let make = (~savedMethods: array<PaymentType.customerMethods>, ~setSavedMethods) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)

  let removeSavedMethod = (savedMethods: array<PaymentType.customerMethods>, paymentMethodId) =>
    savedMethods->Array.filter(savedMethod => savedMethod.paymentMethodId !== paymentMethodId)

  let handleDelete = async (paymentItem: PaymentType.customerMethods) => {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
    ])

    try {
      let res = await PaymentHelpers.deletePaymentMethod(
        ~ephemeralKey=config.ephemeralKey,
        ~paymentMethodId=paymentItem.paymentMethodId,
        ~logger,
        ~customPodUri,
      )

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
    } catch {
    | err =>
      let exceptionMessage = err->formatException->JSON.stringify
      logger.setLogError(
        ~value=`Error Deleting Saved Payment Method: ${exceptionMessage}`,
        ~eventName=DELETE_SAVED_PAYMENT_METHOD,
      )
    }
    messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
  }

  savedMethods
  ->Array.mapWithIndex((obj, i) => {
    let brandIcon = obj->getPaymentMethodBrand
    <SavedMethodItem key={i->Int.toString} paymentItem=obj brandIcon handleDelete />
  })
  ->React.array
}
