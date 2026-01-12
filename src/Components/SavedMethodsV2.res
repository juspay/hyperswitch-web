open RecoilAtoms
open Utils

@react.component
let make = (~cvcProps: CardUtils.cvcProps) => {
  let (paymentTokenAtom, setPaymentTokenAtom) = Recoil.useRecoilState(RecoilAtoms.paymentTokenAtom)
  let {iframeId, publishableKey, profileId} = Recoil.useRecoilValueFromAtom(keys)
  let nickName = Recoil.useRecoilValueFromAtom(userCardNickName)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let {config, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let (savedMethodsV2, setSavedMethodsV2) = Recoil.useRecoilState(RecoilAtomsV2.savedMethodsV2)
  let (_, setManagePaymentMethod) = Recoil.useRecoilState(RecoilAtomsV2.managePaymentMethod)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let updateCard = PaymentHelpersV2.useSaveOrUpdateCard(Some(loggerState), Card, ~isUpdate=true)
  let {isCVCValid, cvcNumber, setCvcError} = cvcProps
  let complete = isCVCValid->Option.getOr(false) && paymentTokenAtom.paymentToken !== ""
  let isEmpty = cvcNumber == ""

  let setUserError = message => postFailedSubmitResponse(~errortype="validation_error", ~message)

  let updateSavedMethodV2 = (
    savedMethods: array<UnifiedPaymentsTypesV2.customerMethods>,
    paymentMethodToken,
    updatedCustomerMethod: UnifiedPaymentsTypesV2.customerMethods,
  ) => {
    savedMethods->Array.map(savedMethod =>
      savedMethod.paymentToken !== paymentMethodToken ? savedMethod : updatedCustomerMethod
    )
  }

  let removeSavedMethodV2 = (
    savedMethods: array<UnifiedPaymentsTypesV2.customerMethods>,
    paymentMethodToken,
  ) => savedMethods->Array.filter(savedMethod => savedMethod.paymentToken !== paymentMethodToken)

  let handleUpdate = async (paymentItem: UnifiedPaymentsTypesV2.customerMethods) => {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
    ])

    let bodyArr = PaymentManagementBody.updateCardBody(
      ~paymentMethodToken=paymentItem.paymentToken,
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
      let paymentMethodToken = dict->getString("payment_method_token", "")

      if paymentMethodToken != "" {
        setManagePaymentMethod(_ => "")
        let updatedCard = dict->UnifiedHelpersV2.itemToPaymentDetails
        setSavedMethodsV2(prev => prev->updateSavedMethodV2(paymentMethodToken, updatedCard))
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

  let handleDeleteV2 = async (paymentItem: UnifiedPaymentsTypesV2.customerMethods) => {
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
        ~paymentMethodToken=paymentItem.paymentToken,
        ~pmSessionId=config.pmSessionId,
        ~logger,
        ~customPodUri,
      )

      let dict = res->getDictFromJson
      let paymentMethodToken = dict->getString("payment_method_token", "")

      if paymentMethodToken != "" {
        setSavedMethodsV2(prev => prev->removeSavedMethodV2(paymentMethodToken))
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

  React.useEffect(() => {
    messageParentWindow([("ready", true->JSON.Encode.bool)])
    None
  }, [])

  React.useEffect(() => {
    let defaultSelectedPaymentMethod = savedMethodsV2->Array.get(0)

    let isSavedMethodsEmpty = savedMethodsV2->Array.length === 0

    let tokenObj = switch (isSavedMethodsEmpty, defaultSelectedPaymentMethod) {
    | (false, Some(defaultSelectedPaymentMethod)) => Some(defaultSelectedPaymentMethod)
    | (false, None) =>
      Some(savedMethodsV2->Array.get(0)->Option.getOr(UnifiedHelpersV2.defaultCustomerMethods))
    | _ => None
    }

    switch tokenObj {
    | Some(obj) =>
      setPaymentTokenAtom(_ => {
        paymentToken: obj.paymentToken,
        customerId: obj.customerId,
      })
    | None => ()
    }
    None
  }, [savedMethodsV2])

  let customerMethod = React.useMemo(_ =>
    savedMethodsV2
    ->Array.filter(savedMethod => savedMethod.paymentToken === paymentTokenAtom.paymentToken)
    ->Array.get(0)
    ->Option.getOr(UnifiedHelpersV2.defaultCustomerMethods)
  , (paymentTokenAtom, savedMethodsV2))

  let isCardPaymentMethodValid = !customerMethod.requiresCvv || (complete && !isEmpty)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    let savedPaymentMethodBody = PaymentManagementBody.updateCVVBody(
      ~paymentMethodToken=paymentTokenAtom.paymentToken,
      ~cvcNumber,
    )

    if confirm.doSubmit {
      if isCardPaymentMethodValid && confirm.confirmTimestamp >= confirm.readyTimestamp {
        updateCard(
          ~bodyArr=savedPaymentMethodBody,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=true,
        )
      } else {
        if confirm.confirmTimestamp < confirm.readyTimestamp {
          setUserError(localeString.selectPaymentMethodText)
        }
        if cvcNumber === "" {
          setCvcError(_ => localeString.cvcNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if !(isCVCValid->Option.getOr(false)) {
          setUserError(localeString.enterValidDetailsText)
        }
      }
    }
  }, (areRequiredFieldsValid, isEmpty, complete, customerMethod, isManualRetryEnabled))
  useSubmitPaymentData(submitCallback)

  savedMethodsV2
  ->Array.mapWithIndex((obj, i) => {
    let brandIcon = obj->CardUtilsV2.getPaymentMethodBrand
    <SavedMethodItemV2
      key={i->Int.toString}
      paymentItem=obj
      brandIcon
      handleDeleteV2
      handleUpdate
      setPaymentTokenAtom
      isActive={paymentTokenAtom.paymentToken == obj.paymentToken}
      cvcProps
    />
  })
  ->React.array
}
