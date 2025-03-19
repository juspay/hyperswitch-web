@val
external import_: string => Js.Promise.t<'a> = "import"

type mod = {encryptCard: unit => string}

let getEncryptedCard = async (cardPayloadJson: Js.Json.t) => {
  try {
    let mod = await import_("./ClickToPayCardEncryptionHelpers")
    let encryptCard = Obj.magic(mod)["encryptMessage"]
    await encryptCard(cardPayloadJson)
  } catch {
  | _ => ""
  }
}
