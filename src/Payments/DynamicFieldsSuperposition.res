open SuperpositionHelper
open SuperpositionTypes

@react.component
let make = (
  ~componentWiseRequiredFields: array<(string, array<fieldConfig>)>,
  ~cardProps=?,
  ~expiryProps=?,
  ~cvcProps=?,
) => {
  let {config, themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let isSpacedInnerLayout = config.appearance.innerLayout === Spaced

  let submitCallback = (ev: Window.event, form: ReactFinalForm.formApi) => {
    let json = ev.data->Utils.safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      let _ = form.submit()
    }
  }

  let handleFormSubmit = (values, form: ReactFinalForm.formApi) => {
    Console.log2("Form state", form.getState())
    Console.log2("Form values:", values)
    Promise.resolve(Nullable.null)
  }

  <>
    <ReactFinalForm.Form
      key="dynamic-fields-form"
      onSubmit={handleFormSubmit}
      subscription={Dict.fromArray([("submitting", true), ("submitError", true)])}
      render={({form}) => {
        Utils.useSubmitPaymentData(ev => submitCallback(ev, form))
        <form>
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
                let componentType = SuperpositionTypes.stringToComponentType(componentName)
                switch componentType {
                | Card =>
                  fields
                  ->Array.mapWithIndex((field, _fieldIndex) => {
                    <CardFieldRenderer fieldIndex={field.outputPath} field />
                  })
                  ->React.array
                | Billing
                | Shipping
                | Bank
                | Wallet
                | Crypto
                | Upi
                | Voucher
                | GiftCard
                | MobilePayment
                | Other =>
                  fields
                  ->Array.mapWithIndex((field, _fieldIndex) => {
                    <GenericFieldRenderer fieldIndex={field.outputPath} field />
                  })
                  ->React.array
                }
              })
              ->React.array}
              <Utils.FormValuesSpy />
            </div>
          </div>
        </form>
      }}
    />
  </>
}
