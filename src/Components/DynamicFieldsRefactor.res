@react.component
let make = (
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~isSavedCardFlow=false,
  ~savedMethod=PaymentType.defaultCustomerMethods,
  ~cardProps=None,
  ~expiryProps=None,
  ~cvcProps=None,
  ~isBancontact=false,
  ~isSaveDetailsWithClickToPay=false,
) => {
  open DynamicFieldsUtils
  open PaymentTypeContext
  open RecoilAtoms
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let paymentManagementListValue = Recoil.useRecoilValueFromAtom(
    PaymentUtils.paymentManagementListValue,
  )
  let paymentMethodListValueV2 = Recoil.useRecoilValueFromAtom(
    RecoilAtomsV2.paymentMethodListValueV2,
  )
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let contextPaymentType = usePaymentType()
  let listValue = switch contextPaymentType {
  | PaymentMethodsManagement => paymentManagementListValue
  | _ => paymentMethodListValueV2
  }
  React.useEffect(() => {
    setRequiredFieldsBody(_ => Dict.make())
    None
  }, [paymentMethodType])

  let {billingAddress} = Recoil.useRecoilValueFromAtom(optionAtom)

  //<...>//
  let paymentMethodTypes = PaymentUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod,
    ~paymentMethodType,
  )

  let paymentMethodTypesV2 = PaymentUtilsV2.usePaymentMethodTypeFromListV2(
    ~paymentsListValueV2=listValue,
    ~paymentMethod,
    ~paymentMethodType,
  )

  let creditPaymentMethodTypes = PaymentUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod,
    ~paymentMethodType="credit",
  )

  let creditPaymentMethodTypesV2 = PaymentUtilsV2.usePaymentMethodTypeFromListV2(
    ~paymentsListValueV2=listValue,
    ~paymentMethod,
    ~paymentMethodType="credit",
  )

  let requiredFieldsWithBillingDetails = React.useMemo(() => {
    if paymentMethod === "card" {
      switch GlobalVars.sdkVersion {
      | V2 =>
        let creditRequiredFields =
          listValue.paymentMethodsEnabled
          ->Array.filter(item => {
            item.paymentMethodSubtype === "credit" && item.paymentMethodType === "card"
          })
          ->Array.get(0)
          ->Option.getOr(UnifiedHelpersV2.defaultPaymentMethods)

        let finalCreditRequiredFields = creditRequiredFields.requiredFields
        [
          ...paymentMethodTypes.required_fields,
          ...finalCreditRequiredFields,
        ]->removeRequiredFieldsDuplicates

      | V1 =>
        let creditRequiredFields = creditPaymentMethodTypes.required_fields

        [
          ...paymentMethodTypes.required_fields,
          ...creditRequiredFields,
        ]->removeRequiredFieldsDuplicates
      }
    } else if dynamicFieldsEnabledPaymentMethods->Array.includes(paymentMethodType) {
      switch GlobalVars.sdkVersion {
      | V1 => paymentMethodTypes.required_fields
      | V2 => paymentMethodTypesV2.requiredFields
      }
    } else {
      []
    }
  }, (
    paymentMethod,
    paymentMethodTypes.required_fields,
    paymentMethodTypesV2.requiredFields,
    paymentMethodType,
    creditPaymentMethodTypes.required_fields,
    creditPaymentMethodTypesV2.requiredFields,
  ))

  let requiredFields = React.useMemo(() => {
    requiredFieldsWithBillingDetails
    ->removeBillingDetailsIfUseBillingAddress(billingAddress)
    ->removeClickToPayFieldsIfSaveDetailsWithClickToPay(isSaveDetailsWithClickToPay)
  }, (requiredFieldsWithBillingDetails, isSaveDetailsWithClickToPay))

  let isAllStoredCardsHaveName = React.useMemo(() => {
    PaymentType.getIsStoredPaymentMethodHasName(savedMethod)
  }, [savedMethod])

  let defaultCardProps = CardUtils.useDefaultCardProps()
  let defaultExpiryProps = CardUtils.useDefaultExpiryProps()
  let defaultCvcProps = CardUtils.useDefaultCvcProps()

  let cardProps = switch cardProps {
  | Some(props) => props
  | None => defaultCardProps
  }

  let expiryProps = switch expiryProps {
  | Some(props) => props
  | None => defaultExpiryProps
  }

  let cvcProps = switch cvcProps {
  | Some(props) => props
  | None => defaultCvcProps
  }

  let {isCardValid, cardNumber} = cardProps

  let {isExpiryValid, cardExpiry} = expiryProps

  let {isCVCValid, cvcNumber} = cvcProps

  // useRequiredFieldsEmptyAndValid(
  //   ~requiredFields,
  //   ~fieldsArr,
  //   ~countryNames,
  //   ~bankNames,
  //   ~isCardValid,
  //   ~isExpiryValid,
  //   ~isCVCValid,
  //   ~cardNumber,
  //   ~cardExpiry,
  //   ~cvcNumber,
  //   ~isSavedCardFlow,
  // )

  useRequiredFieldsBody(
    ~requiredFields,
    ~paymentMethodType,
    ~cardNumber,
    ~cardExpiry,
    ~cvcNumber,
    ~isSavedCardFlow,
    ~isAllStoredCardsHaveName,
    ~setRequiredFieldsBody,
  )

  // let submitCallback = useSubmitCallback()
  // useSubmitPaymentData(submitCallback)

  React.null
}
