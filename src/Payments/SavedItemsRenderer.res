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
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let shouldShowAddMethodScreen = showAddMethodsScreen
  let (show, setShow) = React.useState(() => shouldShowAddMethodScreen)
  let selectedOption = Recoil.useRecoilValueFromAtom(RecoilAtoms.selectedOptionAtom)

  React.useEffect(() => {
    selectedOption == "card"
      ? setShow(_ => false)
      : setShow(_ => showAddMethodsScreen || savedCardlength == 0)

    setPaymentToken(_ => {
      let x: RecoilAtomTypes.paymentToken = switch savedMethods->Array.at(0) {
      | Some(paymentItem) => {
          paymentToken: paymentItem.paymentToken,
          customerId: paymentItem.customerId,
        }
      | None => {
          paymentToken: "",
          customerId: "",
        }
      }
      x
    })
    None
  }, [selectedOption])

  Console.log5(
    "SavedItemsRenderer show value: ",
    show,
    showAddMethodsScreen,
    savedCardlength == 0,
    shouldShowAddMethodScreen,
  )

  <>
    {show
      ? <>
          children
          {savedCardlength == 0
            ? React.null
            : <div
                className="Label"
                style={
                  fontSize: "14px",
                  float: "left",
                  fontWeight: themeObj.fontWeightNormal,
                  width: "fit-content",
                  color: themeObj.colorPrimary,
                }
                tabIndex=0
                role="button"
                ariaLabel="Click to use existing payment methods"
                onKeyDown={event => {
                  let key = JsxEvent.Keyboard.key(event)
                  let keyCode = JsxEvent.Keyboard.keyCode(event)
                  if key == "Enter" || keyCode == 13 {
                    setShow(_ => !show)
                  }
                }}
                onClick={_ => {
                  setShow(_ => !show)
                }}>
                <div className="flex gap-3 items-center cursor-pointer mt-4">
                  <Icon name="circle_dots" size=20 width=19 />
                  {React.string("Use saved payment methods")}
                </div>
              </div>}
        </>
      : <>
          <div
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
          </div>
          <div
            className="Label"
            style={
              fontSize: "14px",
              float: "left",
              fontWeight: themeObj.fontWeightNormal,
              width: "fit-content",
              color: themeObj.colorPrimary,
            }
            tabIndex=0
            role="button"
            ariaLabel="Click to use existing payment methods"
            onKeyDown={event => {
              let key = JsxEvent.Keyboard.key(event)
              let keyCode = JsxEvent.Keyboard.keyCode(event)
              if key == "Enter" || keyCode == 13 {
                setShow(_ => !show)
              }
            }}
            onClick={_ => {
              setShow(_ => !show)
            }}>
            <div className="flex items-center gap-3 cursor-pointer mt-4">
              <Icon name="circle-plus" size=22 />
              {React.string("New payment method")}
            </div>
          </div>
        </>}
  </>
}
