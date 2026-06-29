@val
external import_: string => Promise.t<'a> = "import"

type mod = {encryptCard: unit => string}

let getEncryptedCard = async (
  cardPayloadJson: JSON.t,
  ~logger: option<HyperLoggerTypes.loggerMake>=None,
) => {
  try {
    let mod = await import_("./ClickToPayCardEncryptionHelpers")
    let encryptCard = Obj.magic(mod)["encryptMessage"]
    await encryptCard(cardPayloadJson)
  } catch {
  | err =>
    switch logger {
    | Some(logger) =>
      logger.setLogError(
        ~value=`Click to Pay card encryption failed: ${err->Utils.formatException->JSON.stringify}`,
        ~eventName=CLICK_TO_PAY_FLOW,
        ~logType=ERROR,
        ~logCategory=USER_ERROR,
      )
    | None => ()
    }
    ""
  }
}
