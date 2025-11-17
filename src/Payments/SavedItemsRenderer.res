@react.component
let make = (
  ~savedMethods: array<PaymentType.customerMethods>,
  ~setPaymentToken,
  ~paymentTokenVal,
  ~cvcProps,
  ~setRequiredFieldsBody,
  ~showAddMethodsScreen=false,
  ~children,
  ~paymentToken,
  ~isClickToPayRememberMe,
  ~requiredFieldsBody,
  ~sessions,
) => {
  let savedCardlength = savedMethods->Array.length
  Console.log2(showAddMethodsScreen, savedCardlength)
  SavedMethodsSubmit.useSavedMethodsPayment(
    ~savedMethods,
    ~paymentToken,
    ~cvcProps,
    ~isClickToPayRememberMe,
    ~requiredFieldsBody,
    ~sessions,
  )

  <>
    {showAddMethodsScreen || savedCardlength == 0
      ? children
      : <div
          className="PickerItemContainer"
          tabIndex={0}
          role="region"
          ariaLabel="Saved payment methods">
          {savedMethods
          ->Array.mapWithIndex((obj, i) =>
            <SavedCardItem
              key={i->Int.toString}
              setPaymentToken
              isActive={paymentTokenVal == obj.paymentToken}
              paymentItem=obj
              brandIcon={obj->CardUtils.getPaymentMethodBrand}
              index=i
              savedCardlength
              cvcProps
              setRequiredFieldsBody
            />
          )
          ->React.array}
        </div>}
  </>
}
