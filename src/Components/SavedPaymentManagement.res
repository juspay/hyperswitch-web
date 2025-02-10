@react.component
let make = (
  ~savedMethods: array<PaymentType.customerMethods>,
  ~setSavedMethods,
  ~savedMethodsV2: array<PMMTypesV2.customerMethods>,
  ~setSavedMethodsV2,
) => {
  open CardUtils
  open Utils
  open RecoilAtoms

  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)

  let removeSavedMethod = (savedMethods: array<PaymentType.customerMethods>, paymentMethodId) =>
    savedMethods->Array.filter(savedMethod => savedMethod.paymentMethodId !== paymentMethodId)

  let removeSavedMethodV2 = (savedMethods: array<PMMTypesV2.customerMethods>, paymentMethodId) =>
    savedMethods->Array.filter(savedMethod => savedMethod.id !== paymentMethodId)

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

  let handleDeleteV2 = async (paymentItem: PMMTypesV2.customerMethods) => {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
    ])

    try {
      let res = await PaymentHelpersV2.deletePaymentMethodV2(
        ~pmSessionId=config.pmSessionId,
        ~pmClientSecret=config.pmClientSecret,
        ~paymentMethodId=paymentItem.id,
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
        setSavedMethodsV2(prev => prev->removeSavedMethodV2(paymentMethodId))
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

  switch GlobalVars.sdkVersionEnum {
  | V2 =>
    savedMethodsV2
    ->Array.mapWithIndex((obj, i) => {
      let brandIcon = obj->CardUtilsV2.getPaymentMethodBrand
      <SavedMethodItemV2 key={i->Int.toString} paymentItem=obj brandIcon handleDeleteV2 />
    })
    ->React.array
  | V1 =>
    savedMethods
    ->Array.mapWithIndex((obj, i) => {
      let brandIcon = obj->getPaymentMethodBrand
      <SavedMethodItem key={i->Int.toString} paymentItem=obj brandIcon handleDelete />
    })
    ->React.array
  }
}
