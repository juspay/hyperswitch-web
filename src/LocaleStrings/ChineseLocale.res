let localeStrings: LocaleStringTypes.localeStrings = {
  locale: `zh`,
  localeDirection: `ltr`,
  cardNumberLabel: `卡號`,
  inValidCardErrorText: `卡号无效。`,
  inValidExpiryErrorText: `卡片有效期无效。`,
  inCompleteCVCErrorText: `您的卡片安全码不完整。`,
  inCompleteExpiryErrorText: `您的卡片到期日期不完整。`,
  enterValidCardNumberErrorText: `请输入有效的卡号。`,
  pastExpiryErrorText: `您的卡片到期年份已过期。`,
  poweredBy: `由 Hyperswitch 提供技术支持`,
  validThruText: `有效期`,
  sortCodeText: `排序代码`,
  cvcTextLabel: `安全碼`,
  line1Label: `地址行 1`,
  line1Placeholder: `街道地址`,
  line1EmptyText: `地址行 1 不能为空`,
  line2Label: `地址行 2`,
  line2Placeholder: `公寓、单元号等`,
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
  ibanEmptyText: `IBAN 不能为空`,
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
    `通过提供您的支付信息并确认此授权书表格，您授权 (A) ${str}，债权人和/或我们的支付服务提供商向您的银行发送指令以从您的账户中扣款，以及 (B) 您的银行按照 ${str} 的指示从您的账户中扣款。作为您权利的一部分，您有权根据与银行的协议条款和条件从您的银行获得退款。退款请求必须在从您的账户被扣款之日起的 8 周内提出。您的权利在您可以从银行获取的声明中有详细说明。`,
  becsDebitTerms: `通过提供您的银行账户详细信息并确认此付款，您同意此直接借记请求和直接借记请求服务协议，并授权 Hyperswitch Payments Australia Pty Ltd ACN 160 180 343 直接借记用户 ID 号码 507156（“Hyperswitch”）通过批量电子清算系统（BECS）从您的账户中扣款，代表 Hyperswitch Payment Widget（“商户”）处理任何商户单独通知您的金额。您确认您是上述账户的账户持有人或授权签署人。`,
  cardTerms: str =>
    `通过提供您的卡片信息，您允许 ${str} 根据其条款向您的卡片收费。`,
  payNowButton: `立即支付`,
  cardNumberEmptyText: `卡号不能为空`,
  cardExpiryDateEmptyText: `卡片到期日期不能为空`,
  cvcNumberEmptyText: `安全码不能为空`,
  enterFieldsText: `请输入所有字段`,
  enterValidDetailsText: `请输入有效的详细信息`,
  selectPaymentMethodText: `请选择付款方式然后重试`,
  card: `卡片`,
  surchargeMsgAmount: (currency, str) => <>
    {React.string(`此交易将收取${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string({`${Utils.nbsp}的附加费用`})}
  </>,
  shortSurchargeMessage: (currency, amount) => <>
    {React.string(`费用 :${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${amount}`)} </strong>
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
  formFundsInfoText: `资金将记入此账户`,
  formFundsCreditInfoText: pmLabel => `您的资金将以所选的${pmLabel}记入。`,
  formEditText: `编辑`,
  formSaveText: `保存`,
  formSubmitText: `提交`,
  formSubmittingText: `提交中`,
  formSubheaderBillingDetailsText: `输入您的账单地址`,
  formSubheaderCardText: `您的卡信息`,
  formSubheaderAccountText: pmLabel => `您的${pmLabel}`,
  formHeaderReviewText: `审核`,
  formHeaderReviewTabLayoutText: pmLabel => `审核您的${pmLabel}详细信息`,
  formHeaderBankText: bankTransferType => `输入${bankTransferType}银行详细信息`,
  formHeaderWalletText: walletTransferType => `输入${walletTransferType}钱包详细信息`,
  formHeaderEnterCardText: `输入卡信息`,
  formHeaderSelectBankText: `选择一种银行方法`,
  formHeaderSelectWalletText: `选择一个钱包`,
  formHeaderSelectAccountText: `选择一个账户进行付款`,
  formFieldACHRoutingNumberLabel: `路由号码`,
  formFieldSepaIbanLabel: `国际银行账户号码 (IBAN)`,
  formFieldSepaBicLabel: `银行标识码 (可选)`,
  formFieldPixIdLabel: `Pix ID`,
  formFieldBankAccountNumberLabel: `银行账户号码`,
  formFieldPhoneNumberLabel: `电话号码`,
  formFieldCountryCodeLabel: `国家代码 (可选)`,
  formFieldBankNameLabel: `银行名称 (可选)`,
  formFieldBankCityLabel: `银行城市 (可选)`,
  formFieldCardHoldernamePlaceholder: `您的姓名`,
  formFieldBankNamePlaceholder: `银行名称`,
  formFieldBankCityPlaceholder: `银行城市`,
  formFieldEmailPlaceholder: `您的电子邮件`,
  formFieldPhoneNumberPlaceholder: `您的电话`,
  formFieldInvalidRoutingNumber: `路由号码无效。`,
  infoCardRefId: `参考编号`,
  infoCardErrCode: `错误代码`,
  infoCardErrMsg: `错误信息`,
  infoCardErrReason: `原因`,
  linkRedirectionText: seconds => `${seconds->Int.toString}秒后重定向...`,
  linkExpiryInfo: expiry => `链接到期日期：${expiry}`,
  payoutFromText: merchant => `来自${merchant}的付款`,
  payoutStatusFailedMessage: `处理您的付款失败。请与您的提供商联系以获取更多详细信息。`,
  payoutStatusPendingMessage: `您的付款应在2-3个工作日内处理。`,
  payoutStatusSuccessMessage: `您的付款已成功。资金已存入您选择的支付方式。`,
  payoutStatusFailedText: `付款失败`,
  payoutStatusPendingText: `付款处理中`,
  payoutStatusSuccessText: `付款成功`,
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
  destinationBankAccountIdEmptyText: `目标银行账户ID不能为空`,
  sourceBankAccountIdEmptyText: `源银行账户ID不能为空`,
  invalidCardHolderNameError: `持卡人姓名不能包含数字`,
  invalidNickNameError: `昵称不能包含超过2个数字`,
  expiry: `到期`,
}
