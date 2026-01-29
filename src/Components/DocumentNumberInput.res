@react.component
let make = (~options) => {
  open RecoilAtoms
  let {config, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let (documentType, setSelectedDocumentType) = Recoil.useRecoilState(RecoilAtoms.userDocumentType)
  let setDocumentNumber = Recoil.useSetRecoilState(RecoilAtoms.userDocumentNumber)

  let pixCNPJ = Recoil.useRecoilValueFromAtom(userPixCNPJ)
  let pixCPF = Recoil.useRecoilValueFromAtom(userPixCPF)

  React.useEffect(() => {
    switch documentType {
    | "CPF" => setDocumentNumber(_ => pixCPF)
    | "CNPJ" => setDocumentNumber(_ => pixCNPJ)
    | _ => setDocumentNumber(_ => RecoilAtoms.defaultFieldValues)
    }
    None
  }, (documentType, pixCNPJ, pixCPF))

  <div className="flex flex-row gap-2">
    <DropdownField
      appearance=config.appearance
      value=documentType
      setValue=setSelectedDocumentType
      fieldName=localeString.documentTypeLabel
      options
      width="w-1/4"
    />
    {switch documentType {
    | "CPF" => <PixPaymentInput fieldType="pixCPF" />
    | "CNPJ" => <PixPaymentInput fieldType="pixCNPJ" />
    | _ => React.null
    }}
  </div>
}
