let localeStrings: LocaleStringTypes.localeStrings = {
  locale: `zh`,
  localeDirection: `ltr`,
  cardNumberLabel: `卡号`,
  inValidCardErrorText: `卡号无效。`,
  inCompleteCVCErrorText: `您的卡片安全码不完整。`,
  inCompleteExpiryErrorText: `您的卡片到期日期不完整。`,
  pastExpiryErrorText: `您的卡片到期年份已过期。`,
  poweredBy: `由 Hyperswitch 提供技术支持`,
  validThruText: `有效期`,
  sortCodeText: `排序代码`,
  cvcTextLabel: `CVC`,
  line1Label: `地址行 1`,
  line1Placeholder: `街道地址`,
  line1EmptyText: `地址行 1 不能为空`,
  line2Label: `地址行 2`,
  line2Placeholder: `公寓、单元号等（可选）`,
  line2EmptyText: `地址行 2 不能为空`,
  cityLabel: `城市`,
  cityEmptyText: `城市不能为空`,
  postalCodeLabel: `邮政编码`,
  postalCodeEmptyText: `邮政编码不能为空`,
  postalCodeInvalidText: `无效的邮政编码`,
  stateLabel: `省/州`,
  stateEmptyText: `省/州不能为空`,
  accountNumberText: `账户号码`,
  emailLabel: `电子邮箱`,
  emailEmptyText: `电子邮箱不能为空`,
  emailInvalidText: `无效的电子邮箱地址`,
  fullNameLabel: `全名`,
  fullNamePlaceholder: `名字和姓氏`,
  countryLabel: `国家`,
  currencyLabel: `货币`,
  bankLabel: `选择银行`,
  redirectText: `提交订单后，您将被重定向到安全的页面完成购买。`,
  bankDetailsText: `提交这些信息后，您将获得银行账户信息以进行付款。请确保记录下来。`,
  orPayUsing: `或使用`,
  addNewCard: `添加信用卡/借记卡`,
  useExisitingSavedCards: `使用保存的信用卡/借记卡`,
  saveCardDetails: `保存卡片信息`,
  addBankAccount: `添加银行账户`,
  achBankDebitTerms: _ =>
    `您的 ACH 扣款授权将立即设置，但我们会确认金额并在未来的付款前通知您。`,
  sepaDebitTerms: str =>
    `通过提供您的付款信息并确认此付款，您授权（A）${str} 和 Hyperswitch，我们的支付服务提供商和/或 PPRO，其本地服务提供商，向您的银行发送指示从您的账户中扣款，以及（B）您的银行根据这些指示从您的账户中扣款。作为您的权利的一部分，您有权根据与银行的协议的条款和条件要求银行退款。退款必须在账户扣款之日起的 8 周内申请。您的权利在银行可以获得的声明中有解释。您同意在未来的扣款前最多提前 2 天接收通知。`,
  becsDebitTerms: `通过提供您的银行账户详细信息并确认此付款，您同意此直接借记请求和直接借记请求服务协议，并授权 Hyperswitch Payments Australia Pty Ltd ACN 160 180 343 直接借记用户 ID 号码 507156（“Hyperswitch”）通过批量电子清算系统（BECS）从您的账户中扣款，代表 Hyperswitch Payment Widget（“商户”）处理任何商户单独通知您的金额。您确认您是上述账户的账户持有人或授权签署人。`,
  cardTerms: str =>
    `通过提供您的卡片信息，您允许 ${str} 根据其条款向您的卡片收费。`,
  payNowButton: `立即支付`,
  cardNumberEmptyText: `卡号不能为空`,
  cardExpiryDateEmptyText: `卡片到期日期不能为空`,
  cvcNumberEmptyText: `CVC 号码不能为空`,
  enterFieldsText: `请输入所有字段`,
  enterValidDetailsText: `请输入有效的详细信息`,
  selectPaymentMethodText: `请选择付款方式然后重试`,
  card: `卡片`,
  surchargeMsgAmount: (currency, str) => <>
    {React.string(`此交易将收取${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string({`${Utils.nbsp}的附加费用`})}
  </>,
  surchargeMsgAmountForCard: (currency, str) => <>
    {React.string(`此交易将收取最高${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}的附加费用`)}
  </>,
  surchargeMsgAmountForOneClickWallets: `适用额外费用`,
  billingNameLabel: `适用额外费用`,
  billingNamePlaceholder: `名字和姓氏`,
  cardHolderName: `持卡人姓名`,
  on: `在`,
  \"and": `和`,
  nameEmptyText: str => `请提供您的 ${str}`,
  completeNameEmptyText: str => `请提供您的完整 ${str}`,
  billingDetailsText: `账单详情`,
  socialSecurityNumberLabel: `社会安全号码`,
  saveWalletDetails: `选择后将保存钱包信息`,
  morePaymentMethods: `更多支付方式`,
  useExistingPaymentMethods: `使用保存的支付方式`,
  cardNickname: `卡片昵称`,
  nicknamePlaceholder: `卡片昵称（可选）`,
  cardExpiredText: `此卡已过期`,
  cardHeader: `卡片信息`,
  cardBrandConfiguredErrorText: str => `${str} 目前不支持。`,
  currencyNetwork: `货币网络`,
  expiryPlaceholder: `MM / YY`,
  dateOfBirth: `出生日期`,
  vpaIdLabel: `VPA ID`,
  vpaIdEmptyText: `VPA ID 不能为空`,
  vpaIdInvalidText: `无效的 VPA ID 地址`,
  dateofBirthRequiredText: `出生日期是必填项`,
  dateOfBirthInvalidText: `年龄应大于或等于 18 岁`,
  dateOfBirthPlaceholderText: `输入出生日期`,
  pixCNPJInvalidText: `无效的 Pix CNPJ`,
  pixCNPJEmptyText: `Pix CNPJ 不能为空`,
  pixCNPJLabel: `Pix CNPJ`,
  pixCNPJPlaceholder: `输入 Pix CNPJ`,
  pixCPFInvalidText: `无效的 Pix CPF`,
  pixCPFEmptyText: `Pix CPF 不能为空`,
  pixCPFLabel: `Pix CPF`,
  pixCPFPlaceholder: `输入 Pix CPF`,
  pixKeyEmptyText: `Pix 密钥不能为空`,
  pixKeyPlaceholder: `输入 Pix 密钥`,
  pixKeyLabel: `Pix 密钥`,
}
