@react.component
let make = (~options) => {
  open JotaiAtoms
  let {config, localeString} = Jotai.useAtomValue(configAtom)
  let (documentType, setSelectedDocumentType) = Jotai.useAtom(JotaiAtoms.userDocumentType)
  let setDocumentNumber = Jotai.useSetAtom(JotaiAtoms.userDocumentNumber)

  let pixCNPJ = Jotai.useAtomValue(userPixCNPJ)
  let pixCPF = Jotai.useAtomValue(userPixCPF)

  React.useEffect(() => {
    switch documentType {
    | "cpf" => setDocumentNumber(_ => pixCPF)
    | "cnpj" => setDocumentNumber(_ => pixCNPJ)
    | _ => setDocumentNumber(_ => JotaiAtoms.defaultFieldValues)
    }
    None
  }, (documentType, pixCNPJ, pixCPF))

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
    | "cpf" => <PixPaymentInput fieldType="pixCPF" />
    | "cnpj" => <PixPaymentInput fieldType="pixCNPJ" />
    | _ => React.null
    }}
  </div>
}
