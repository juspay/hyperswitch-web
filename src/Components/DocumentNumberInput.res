@react.component
let make = (~name: string, ~options) => {
  open RecoilAtoms
  let {config, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (documentType, setSelectedDocumentType) = Recoil.useRecoilState(RecoilAtoms.userDocumentType)

  <div className="flex w-full">
    <DropdownField
      appearance=config.appearance
      value=documentType
      setValue=setSelectedDocumentType
      fieldName=localeString.documentTypeLabel
      options
      width="w-40 mr-2"
    />
    {switch documentType {
    | "cpf" => <PixPaymentInput name fieldType="pixCPF" />
    | "cnpj" => <PixPaymentInput name fieldType="pixCNPJ" />
    | _ => React.null
    }}
  </div>
}
