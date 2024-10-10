type patterns = {
  issuer: string,
  pattern: Js.Re.t,
  cvcLength: array<int>,
  length: array<int>,
  maxCVCLenth: int,
  pincodeRequired: bool,
}
type card = {details: array<patterns>}
let defaultCardPattern = {
  issuer: "",
  pattern: %re("/^[0-9]/"),
  cvcLength: [3],
  maxCVCLenth: 3,
  length: [16],
  pincodeRequired: false,
}
let cardPatterns = [
  {
    issuer: "Maestro",
    pattern: %re(
      "/^(5018|5081|5044|504681|504993|5020|502260|5038|603845|603123|6304|6759|676[1-3]|6220|504834|504817|504645|504775|600206|627741)/"
    ),
    cvcLength: [3, 4],
    length: [12, 13, 14, 15, 16, 17, 18, 19],
    maxCVCLenth: 4,
    pincodeRequired: true,
  },
  {
    issuer: "RuPay",
    pattern: %re(
      "/^(508227|508[5-9]|603741|60698[5-9]|60699|607[0-8]|6079[0-7]|60798[0-4]|60800[1-9]|6080[1-9]|608[1-4]|608500|6521[5-9]|652[2-9]|6530|6531[0-4]|817290|817368|817378|353800)/"
    ),
    cvcLength: [3],
    length: [16],
    maxCVCLenth: 3,
    pincodeRequired: false,
  },
  {
    issuer: "DinersClub",
    pattern: %re("/^(36|38|30[0-5])/"),
    cvcLength: [3],
    maxCVCLenth: 3,
    length: [14, 15, 16, 17, 18, 19],
    pincodeRequired: false,
  },
  {
    issuer: "Discover",
    pattern: %re("/^(6011|65|64[4-9]|622)/"),
    cvcLength: [3],
    length: [16],
    maxCVCLenth: 3,
    pincodeRequired: true,
  },
  {
    issuer: "Mastercard",
    pattern: %re("/^5[1-5]/"),
    cvcLength: [3],
    maxCVCLenth: 3,
    length: [16],
    pincodeRequired: true,
  },
  {
    issuer: "AmericanExpress",
    pattern: %re("/^3[47]/"),
    cvcLength: [3, 4],
    length: [14, 15],
    maxCVCLenth: 4,
    pincodeRequired: true,
  },
  {
    issuer: "Visa",
    pattern: %re("/^4/"),
    cvcLength: [3],
    length: [13, 14, 15, 16, 19],
    maxCVCLenth: 3,
    pincodeRequired: true,
  },
  {
    issuer: "SODEXO",
    pattern: %re("/^(637513)/"),
    cvcLength: [3],
    length: [16],
    maxCVCLenth: 3,
    pincodeRequired: false,
  },
  {
    issuer: "BAJAJ",
    pattern: %re("/^(203040)/"),
    cvcLength: [3],
    maxCVCLenth: 3,
    length: [16],
    pincodeRequired: true,
  },
  {
    issuer: "JCB",
    pattern: %re("/^35/"),
    cvcLength: [3],
    maxCVCLenth: 3,
    length: [16],
    pincodeRequired: false,
  },
]
