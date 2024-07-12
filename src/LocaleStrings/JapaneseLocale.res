let localeStrings: LocaleStringTypes.localeStrings = {
  locale: "ja",
  localeDirection: "ltr",
  cardNumberLabel: `カード番号`,
  inValidCardErrorText: `カード番号が無効です`,
  inCompleteCVCErrorText: `カードのセキュリティ コードが不完全です`,
  inCompleteExpiryErrorText: `カードの有効期限が不完全です`,
  pastExpiryErrorText: `カードの有効期限が過ぎています`,
  poweredBy: `ハイパースイッチ搭載`,
  validThruText: `を通じて有効`,
  sortCodeText: `ソートコード`,
  cvcTextLabel: `セキュリティコード`,
  accountNumberText: `口座番号`,
  emailLabel: `Eメール`,
  emailEmptyText: `電子メールを空にすることはできません`,
  emailInvalidText: `無効なメールアドレス`,
  fullNameLabel: `フルネーム`,
  fullNamePlaceholder: `名前と苗字`,
  line1Label: `住所1`,
  line1Placeholder: `住所`,
  line1EmptyText: `住所行 1 を空にすることはできません`,
  line2Label: `住所2`,
  postalCodeLabel: `郵便番号`,
  postalCodeEmptyText: `郵便番号を空白にすることはできません`,
  postalCodeInvalidText: `郵便番号が無効です`,
  stateLabel: `州`,
  stateEmptyText: `状態を空にすることはできません`,
  cityLabel: `街`,
  line2Placeholder: `アパート、ユニット番号など（任意）`,
  line2EmptyText: `住所行 2 を空にすることはできません`,
  countryLabel: `国`,
  cityEmptyText: `都市を空にすることはできません`,
  currencyLabel: `通貨`,
  bankLabel: `バンクを選択`,
  redirectText: `注文を送信すると、安全に購入を完了するためにリダイレクトされます。`,
  bankDetailsText: `これらの詳細を送信すると、支払いを行うための銀行口座情報が表示されます。必ずメモを取ってください。`,
  orPayUsing: `またはを使用して支払う`,
  addNewCard: `新しいカードを追加`,
  useExisitingSavedCards: `既存の保存済みカードを使用する`,
  saveCardDetails: `カードの詳細を保存`,
  addBankAccount: `銀行口座を追加`,
  achBankDebitTerms: str =>
    `口座番号を提供し、この支払いを確認することにより、${str} および支払いサービス プロバイダーである Hyperswitch が、銀行に口座からの引き落としの指示を送信し、その指示に従って口座からの引き落としの銀行に指示を送信することを承認したことになります。お客様は、銀行との契約条件に基づいて、銀行から返金を受ける権利があります。払い戻しは、アカウントが引き落とされた日から 8 週間以内に請求する必要があります。`,
  sepaDebitTerms: str =>
    `支払い情報を提供し、この支払いを確認することにより、お客様は、(A) 当社の支払いサービス プロバイダーである ${str} および Hyperswitch および/またはそのローカル サービス プロバイダーである PPRO が、お客様の銀行にお客様の口座から引き落とされる指示を送信すること、および (B) 銀行がその指示に従って口座から引き落としを行います。 お客様の権利の一部として、お客様は銀行との契約条件に基づいて銀行から返金を受ける権利があります。 払い戻しは、アカウントの引き落とし日から 8 週間以内に請求する必要があります。 お客様の権利については、銀行から入手できる明細書で説明されています。 お客様は、将来の引き落としに関する通知を、発生の 2 日前までに受け取ることに同意するものとします。`,
  becsDebitTerms: `銀行口座の詳細を提供し、この支払いを確認することにより、お客様は、この口座振替リクエストおよび口座振替リクエストのサービス契約に同意し、Hyperswitch Payments Australia Pty Ltd ACN 160 180 343 口座振替ユーザー ID 番号 507156 (「ストライプ」) に口座振替を許可することになります。 Hyperswitch Payment Widget (以下「マーチャント」) に代わって、バルク電子決済システム (BECS) を通じて、マーチャントから別途通知された金額についてのアカウントを作成します。あなたは、自分がアカウント所有者であるか、上記のアカウントの承認された署名者のいずれかであることを証明します。`,
  cardTerms: str =>
    `カード情報を提供することにより、${str} が規約に従って将来の支払いをカードに請求できるようになります。`,
  payNowButton: `今払う`,
  cardNumberEmptyText: `カード番号を空にすることはできません`,
  cardExpiryDateEmptyText: `カードの有効期限を空にすることはできません`,
  cvcNumberEmptyText: `CVC 番号を空にすることはできません`,
  enterFieldsText: `すべてのフィールドに入力してください`,
  enterValidDetailsText: `有効な詳細を入力してください`,
  selectPaymentMethodText: `支払い方法を選択して、もう一度お試しください`,
  card: `カード`,
  surchargeMsgAmount: (currency, str) => <>
    {React.string(`この取引には${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}の追加料金が適用されます`)}
  </>,
  surchargeMsgAmountForCard: (currency, str) => <>
    {React.string(`この取引には${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}までの追加料金が適用されます`)}
  </>,
  surchargeMsgAmountForOneClickWallets: `追加料金が適用されます`,
  billingNameLabel: `課金名`,
  billingNamePlaceholder: `名前と苗字`,
  cardHolderName: `クレジットカード名義人氏名`,
  on: `の上`,
  \"and": `そして`,
  nameEmptyText: str => `あなたの情報を提供してください ${str}`,
  completeNameEmptyText: str => `完全な情報を提供してください ${str}`,
  billingDetailsText: `支払明細`,
  socialSecurityNumberLabel: `社会保障番号`,
  saveWalletDetails: `選択時にウォレットの詳細が保存されます`,
  morePaymentMethods: `その他の支払い方法`,
  useExistingPaymentMethods: `保存した支払い方法を使用する`,
  cardNickname: `カードのニックネーム`,
  nicknamePlaceholder: `カードニックネーム（任意）`,
  cardExpiredText: `このカードは期限切れです`,
  cardHeader: `カード情報`,
  cardBrandConfiguredErrorText: str => `${str} は現在サポートされていません。`,
  currencyNetwork: `通貨ネットワーク`,
  expiryPlaceholder: `MM / YY`,
  dateOfBirth: `生年月日`,
  vpaIdLabel: `VPA ID`,
  vpaIdEmptyText: `VPA ID を空にすることはできません`,
  vpaIdInvalidText: `無効な VPA ID`,
  dateofBirthRequiredText: `生年月日が必要です`,
  dateOfBirthInvalidText: `年齢は18歳以上である必要があります`,
}
