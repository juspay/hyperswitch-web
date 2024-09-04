type patterns = {
  issuer: string,
  pattern: Re.t,
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
  {
    issuer: "PagoBancomat",
    pattern: %re(
      "/^(10051\d{5}|10053\d{5}|10108\d{5}|10150\d{5}|10258\d{5}|10300\d{5}|10309\d{5}|20083\d{5}|20084\d{5}|20085\d{5}|20089\d{5}|30150\d{5}|30190\d{5}|30320\d{5}|30430\d{5}|30439\d{5}|30480\d{5}|30583\d{5}|30589\d{5}|30590\d{5}|30620\d{5}|30670\d{5}|30690\d{5}|30750\d{5}|30830\d{5}|30836\d{5}|30870\d{5}|31040\d{5}|31110\d{5}|31240\d{5}|31260\d{5}|31270\d{5}|31380\d{5}|31580\d{5}|31599\d{5}|31850\d{5}|32040\d{5}|32050\d{5}|32115\d{5}|32390\d{5}|32400\d{5}|32420\d{5}|32440\d{5}|32500\d{5}|32630\d{5}|32681\d{5}|32682\d{5}|32685\d{5}|32968\d{5}|33320\d{5}|33870\d{5}|33990\d{5}|34000\d{5}|34029\d{5}|34030\d{5}|34253\d{5}|34310\d{5}|34400\d{5}|34420\d{5}|34880\d{5}|34938\d{5}|35000\d{5}|35899\d{5}|35980\d{5}|35990\d{5})$/"
    ),
    cvcLength: [3],
    maxCVCLenth: 3,
    length: [16],
    pincodeRequired: false,
  },
]
