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
    | "cpf" => setDocumentNumber(_ => pixCPF)
    | "cnpj" => setDocumentNumber(_ => pixCNPJ)
    | _ => setDocumentNumber(_ => RecoilAtoms.defaultFieldValues)
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
