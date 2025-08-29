open SuperpositionHelper

@react.component
let make = (
  ~componentWiseRequiredFields: array<(string, array<fieldConfig>)>,
  ~cardProps=?,
  ~expiryProps=?,
  ~cvcProps=?,
) => {
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let (cardBrand, setCardBrand) = React.useState(_ => "")
  let (isCardValid, setIsCardValid) = React.useState(_ => None)
  let (isExpiryValid, setIsExpiryValid) = React.useState(_ => None)
  let (isCVCValid, setIsCVCValid) = React.useState(_ => None)
  let (currentCVC, setCurrentCVC) = React.useState(_ => "")

  let validateField = (value, field) => {
    switch value {
    | Some(val) =>
      switch field.fieldType {
      | "email_input" =>
        Console.log2("Validating email:", val)
        if val->EmailValidation.isEmailValid->Option.getOr(false) {
          Promise.resolve(Nullable.null)
        } else {
          Promise.resolve(Nullable.make(localeString.emailInvalidText))
        }
      | _ => Promise.resolve(Nullable.null)
      }
    | None => Promise.resolve(Nullable.null)
    }
  }

  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

  let submitCallback = (ev: Window.event, form: ReactFinalForm.formApi) => {
    let json = ev.data->Utils.safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      let _ = form.submit()
    }
  }

  let handleFormSubmit = (values, form) => {
    Console.log2("Form values:", values)
    Console.log2("Form api:", form)
    Promise.resolve(Nullable.null)
  }

  <>
    <ReactFinalForm.Form
      key="dynamic-fields-form"
      onSubmit={handleFormSubmit}
      render={({handleSubmit, form}) => {
        Utils.useSubmitPaymentData(ev => submitCallback(ev, form))
        <form onSubmit={handleSubmit}>
          <div
            className="flex flex-col w-full place-content-between"
            style={
              gridColumnGap: themeObj.spacingGridRow,
            }>
            <div
              className={`flex flex-col`}
              style={
                gap: isSpacedInnerLayout ? themeObj.spacingGridRow : "",
              }>
              {componentWiseRequiredFields
              ->Array.mapWithIndex((componentWithField, _index) => {
                let (componentName, fields) = componentWithField
                switch componentName {
                | "card" =>
                  fields
                  ->Array.mapWithIndex((field, _fieldIndex) => {
                    <CardFieldRenderer
                      fieldIndex={field.outputPath}
                      field
                      cardBrand
                      setCardBrand
                      isCardValid
                      setIsCardValid
                      isExpiryValid
                      setIsExpiryValid
                      isCVCValid
                      setIsCVCValid
                      currentCVC
                      setCurrentCVC
                    />
                  })
                  ->React.array
                | "billing"
                | "shipping" =>
                  fields
                  ->Array.mapWithIndex((field, _fieldIndex) => {
                    <GenericFieldRenderer fieldIndex={field.outputPath} field validateField />
                  })
                  ->React.array
                | "bank"
                | "wallet"
                | "crypto"
                | "upi"
                | "voucher"
                | "gift_card"
                | "mobile_payment"
                | "other" =>
                  fields
                  ->Array.mapWithIndex((field, _fieldIndex) => {
                    <GenericFieldRenderer fieldIndex={field.outputPath} field validateField />
                  })
                  ->React.array
                | _ => React.null
                }
              })
              ->React.array}
              <ReactFinalForm.FormValuesSpy />
            </div>
          </div>
        </form>
      }}
    />
  </>
}
