open RecoilAtoms
open Utils

@react.component
let make = () => {
  let {iframeId, publishableKey, profileId} = Recoil.useRecoilValueFromAtom(keys)
  let nickName = Recoil.useRecoilValueFromAtom(userCardNickName)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let (savedMethodsV2, setSavedMethodsV2) = Recoil.useRecoilState(RecoilAtomsV2.savedMethodsV2)
  let (_, setManagePaymentMethod) = Recoil.useRecoilState(RecoilAtomsV2.managePaymentMethod)

  let updateSavedMethodV2 = (
    savedMethods: array<PMMTypesV2.customerMethods>,
    paymentMethodId,
    updatedCustomerMethod: PMMTypesV2.customerMethods,
  ) => {
    savedMethods->Array.map(savedMethod =>
      savedMethod.id !== paymentMethodId ? savedMethod : updatedCustomerMethod
    )
  }

  let removeSavedMethodV2 = (savedMethods: array<PMMTypesV2.customerMethods>, paymentMethodId) =>
    savedMethods->Array.filter(savedMethod => savedMethod.id !== paymentMethodId)

  let handleUpdate = async (paymentItem: PMMTypesV2.customerMethods) => {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
    ])

    let bodyArr = PaymentManagementBody.updateCardBody(
      ~paymentMethodId=paymentItem.id,
      ~nickName=nickName.value,
      ~cardHolderName=fullName.value,
    )

    try {
      let res = await PaymentHelpersV2.updatePaymentMethod(
        ~bodyArr,
        ~pmClientSecret=config.pmClientSecret,
        ~publishableKey,
        ~profileId,
        ~pmSessionId=config.pmSessionId,
        ~logger,
        ~customPodUri,
      )

      let dict = res->getDictFromJson
      let paymentMethodId = dict->getString("id", "")

      if paymentMethodId != "" {
        setManagePaymentMethod(_ => "")
        let updatedCard = dict->PMMV2Helpers.itemToPaymentDetails
        setSavedMethodsV2(prev => prev->updateSavedMethodV2(paymentMethodId, updatedCard))
      } else {
        Console.error2("Payment Id Empty ", res->JSON.stringify)
      }
    } catch {
    | err =>
      let exceptionMessage = err->formatException->JSON.stringify
      Console.error2("Unable to Update Card ", exceptionMessage)
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
        ~publishableKey,
        ~profileId,
        ~pmClientSecret=config.pmClientSecret,
        ~paymentMethodId=paymentItem.id,
        ~pmSessionId=config.pmSessionId,
        ~logger,
        ~customPodUri,
      )

      let dict = res->getDictFromJson
      let paymentMethodId = dict->getString("id", "")

      if paymentMethodId != "" {
        setSavedMethodsV2(prev => prev->removeSavedMethodV2(paymentMethodId))
      } else {
        Console.error2("Payment Id Empty ", res->JSON.stringify)
      }
    } catch {
    | err =>
      let exceptionMessage = err->formatException->JSON.stringify
      Console.error2("Unable to Delete Card ", exceptionMessage)
    }
    messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
  }

  savedMethodsV2
  ->Array.mapWithIndex((obj, i) => {
    let brandIcon = obj->CardUtilsV2.getPaymentMethodBrand
    <SavedMethodItemV2
      key={i->Int.toString} paymentItem=obj brandIcon handleDeleteV2 handleUpdate
    />
  })
  ->React.array
}
