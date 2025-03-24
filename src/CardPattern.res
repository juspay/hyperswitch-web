type patterns = {
  issuer: string,
  pattern: Re.t,
  cvcLength: array<int>,
  length: array<int>,
  maxCVCLength: int,
  pincodeRequired: bool,
}
type card = {details: array<patterns>}
let defaultCardPattern = {
  issuer: "",
  pattern: %re("/^[0-9]/"),
  cvcLength: [3, 4],
  maxCVCLength: 4,
  length: [13, 14, 15, 16, 17, 18, 19],
  pincodeRequired: false,
}
let cardPatterns = [
  {
    issuer: "Maestro",
    pattern: %re(
      "/^(5018|5081|5044|504681|504993|5020|502260|5038|5893|603845|603123|6304|6759|676[1-3]|6220|504834|504817|504645|504775|600206|627741)/"
    ),
    cvcLength: [3, 4],
    length: [12, 13, 14, 15, 16, 17, 18, 19],
    maxCVCLength: 4,
    pincodeRequired: true,
  },
  {
    issuer: "UnionPay",
    pattern: %re("/^(6[27]|81)/"),
    cvcLength: [3],
    length: [16, 17, 18, 19],
    maxCVCLength: 3,
    pincodeRequired: true,
  },
  {
    issuer: "Interac",
    pattern: %re("/^(4506|4724|4761|0012)/"),
    cvcLength: [3],
    length: [16],
    maxCVCLength: 3,
    pincodeRequired: true,
  },
  {
    issuer: "RuPay",
    pattern: %re(
      "/^(508227|508[5-9]|603741|60698[5-9]|60699|607[0-8]|6079[0-7]|60798[0-4]|60800[1-9]|6080[1-9]|608[1-4]|608500|6521[5-9]|652[2-9]|6530|6531[0-4]|817290|817368|817378|353800|82)/"
    ),
    cvcLength: [3],
    length: [16],
    maxCVCLength: 3,
    pincodeRequired: false,
  },
  {
    issuer: "DinersClub",
    pattern: %re("/^(36|38|39|30[0-5])/"),
    cvcLength: [3],
    maxCVCLength: 3,
    length: [14, 15, 16, 17, 18, 19],
    pincodeRequired: false,
  },
  {
    issuer: "Discover",
    pattern: %re("/^(6011|64[4-9]|65|622126|622[1-9][0-9][0-9]|6229[0-1][0-9]|622925)/"),
    cvcLength: [3],
    length: [16],
    maxCVCLength: 3,
    pincodeRequired: true,
  },
  {
    issuer: "Mastercard",
    pattern: %re("/^(222[1-9]|22[3-9][0-9]|2[3-6][0-9]{2}|27[0-1][0-9]|2720|5[1-5])/"),
    cvcLength: [3],
    maxCVCLength: 3,
    length: [16],
    pincodeRequired: true,
  },
  {
    issuer: "AmericanExpress",
    pattern: %re("/^3[47]/"),
    cvcLength: [3, 4],
    length: [14, 15],
    maxCVCLength: 4,
    pincodeRequired: true,
  },
  {
    issuer: "Visa",
    pattern: %re("/^4/"),
    cvcLength: [3],
    length: [13, 14, 15, 16, 19],
    maxCVCLength: 3,
    pincodeRequired: true,
  },
  {
    issuer: "CartesBancaires",
    pattern: %re(
      "/^(401(005|006|581)|4021(01|02)|403550|405936|406572|41(3849|4819|50(56|59|62|71|74)|6286|65(37|79)|71[7])|420110|423460|43(47(21|22)|50(48|49|50|51|52)|7875|95(09|11|15|39|98)|96(03|18|19|20|22|72))|4424(48|49|50|51|52|57)|448412|4505(19|60)|45(33|56[6-8]|61|62[^3]|6955|7452|7717|93[02379])|46(099|54(76|77)|6258|6575|98[023])|47(4107|71(73|74|86)|72(65|93)|9619)|48(1091|3622|6519)|49(7|83[5-9]|90(0[1-6]|1[0-6]|2[0-3]|3[0-3]|4[0-3]|5[0-2]|68|9[256789]))|5075(89|90|93|94|97)|51(0726|3([0-7]|8[56]|9(00|38))|5214|62(07|36)|72(22|43)|73(65|66)|7502|7647|8101|9920)|52(0993|1662|3718|7429|9227|93(13|14|31)|94(14|21|30|40|47|55|56|[6-9])|9542)|53(0901|10(28|30)|1195|23(4[4-7])|2459|25(09|34|54|56)|3801|41(02|05|11)|50(29|66)|5324|61(07|15)|71(06|12)|8011)|54(2848|5157|9538|98(5[89]))|55(39(79|93)|42(05|60)|4965|7008|88(67|82)|89(29|4[23])|9618|98(09|10))|56(0408|12(0[2-6]|4[134]|5[04678]))|58(17(0[0123457]|15|2[14]|3[16789]|4[0-9]|5[016]|6[269]|7[3789]|8[012467]|9[017])|55(0[2-5]|7[7-9]|8[0-2])))/"
    ),
    cvcLength: [3],
    length: [16, 17, 18, 19],
    maxCVCLength: 3,
    pincodeRequired: true,
  },
  {
    issuer: "SODEXO",
    pattern: %re("/^(637513)/"),
    cvcLength: [3],
    length: [16],
    maxCVCLength: 3,
    pincodeRequired: false,
  },
  {
    issuer: "BAJAJ",
    pattern: %re("/^(203040)/"),
    cvcLength: [3],
    maxCVCLength: 3,
    length: [16],
    pincodeRequired: true,
  },
  {
    issuer: "JCB",
    pattern: %re("/^35(2[89]|[3-8][0-9])/"),
    cvcLength: [3],
    maxCVCLength: 3,
    length: [16],
    pincodeRequired: false,
  },
]
