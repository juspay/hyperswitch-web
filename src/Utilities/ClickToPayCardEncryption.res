@val
external import_: string => Promise.t<'a> = "import"

type mod = {encryptCard: unit => string}

let getEncryptedCard = async (cardPayloadJson: JSON.t) => {
  try {
    let mod = await import_("./ClickToPayCardEncryptionHelpers")
    let encryptCard = Obj.magic(mod)["encryptMessage"]
    await encryptCard(cardPayloadJson)
  } catch {
  | _ => ""
  }
}
