@react.component
let make = (~name: string, ~documentNumberName: string, ~options) => {
  open RecoilAtoms
  let {config, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (selectedDocumentType, setSelectedDocumentType) = React.useState(() => "")

  <div className="flex w-full">
    <ReactFinalFormField
      name={name}
      render={field => {
        let value = field.input.value->Option.getOr(selectedDocumentType)
        React.useEffect(() => {
          if value === "" && options->Array.length > 0 {
            let firstOption =
              options
              ->Array.get(0)
              ->Option.map((opt: DropdownField.optionType) => opt.value)
              ->Option.getOr("")
            if firstOption !== "" {
              field.input.onChange(firstOption)
              setSelectedDocumentType(_ => firstOption)
            }
          }
          None
        }, [options])

        React.useEffect(() => {
          if value !== "" && value !== selectedDocumentType {
            setSelectedDocumentType(_ => value)
          }
          None
        }, [value])

        <DropdownField
          appearance=config.appearance
          value
          setValue={setter => {
            let newVal = setter(value)
            field.input.onChange(newVal)
          }}
          fieldName=localeString.documentTypeLabel
          options
          width="w-40 mr-2"
        />
      }}
    />
    {switch selectedDocumentType {
    | "cpf" => <PixPaymentInput name={documentNumberName} fieldType="pixCPF" />
    | "cnpj" => <PixPaymentInput name={documentNumberName} fieldType="pixCNPJ" />
    | _ => React.null
    }}
  </div>
}
