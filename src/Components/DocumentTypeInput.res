@react.component
let make = (~options) => {
  open RecoilAtoms
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let setSelectedDocumentType = Recoil.useSetRecoilState(RecoilAtoms.userDocumentType)
  let (documentTypeOptionVal, setDocumentTypeOptionVal) = React.useState(_ => "")

  let pixCNPJ = Recoil.useRecoilValueFromAtom(userPixCNPJ)
  let pixCPF = Recoil.useRecoilValueFromAtom(userPixCPF)

  React.useEffect(() => {
    switch documentTypeOptionVal {
    | "CPF" => setSelectedDocumentType(_ => pixCPF)
    | "CNPJ" => setSelectedDocumentType(_ => pixCNPJ)
    | _ => setSelectedDocumentType(_ => RecoilAtoms.defaultFieldValues)
    }
    None
  }, (documentTypeOptionVal, pixCNPJ, pixCPF))

  <div className="flex flex-row gap-2">
    <DropdownField
      appearance=config.appearance
      value=documentTypeOptionVal
      setValue=setDocumentTypeOptionVal
      fieldName=""
      options
      width="w-1/4"
    />
    {switch documentTypeOptionVal {
    | "CPF" => <PixPaymentInput fieldType="pixCPF" />
    | "CNPJ" => <PixPaymentInput fieldType="pixCNPJ" />
    | _ => React.null
    }}
  </div>
}
