let localeStrings: LocaleStringTypes.localeStrings = {
  locale: `ru`,
  localeDirection: `ltr`,
  cardNumberLabel: `Номер карты`,
  inValidCardErrorText: `Номер карты недействителен.`,
  inCompleteCVCErrorText: `Неправильно указан код безопасности карты.`,
  inCompleteExpiryErrorText: `Неправильно указан срок действия карты.`,
  pastExpiryErrorText: `Год истечения срока действия карты в прошлом.`,
  poweredBy: `Работает на Hyperswitch`,
  validThruText: `Окончание действия`,
  sortCodeText: `Номер отделения банка`,
  cvcTextLabel: `CVC`,
  line1Label: `Адресная строка 1`,
  line1Placeholder: `Улица`,
  line2Label: `Адресная строка 2`,
  line2Placeholder: `Квартира, номер блока и т. д. (необязательно)`,
  cityLabel: `Город`,
  postalCodeLabel: `Почтовый индекс`,
  stateLabel: `Область`,
  accountNumberText: `Номер счета`,
  emailLabel: `Электронная почта`,
  fullNameLabel: `Ф.И.О.`,
  fullNamePlaceholder: `Имя и фамилия`,
  countryLabel: `Страна`,
  currencyLabel: `Валюта`,
  bankLabel: `Выберите банк`,
  redirectText: `После оформления заказа вы будете перенаправлены на другую страницу для безопасного завершения покупки.`,
  bankDetailsText: `После ввода этих данных вы получите банковские реквизиты для совершения платежа. Обязательно запишите их.`,
  orPayUsing: `Или оплатить с помощью`,
  addNewCard: `Добавить кредитную/дебетовую карту`,
  useExisitingSavedCards: `Использовать сохраненные дебетовые/кредитные карты`,
  saveCardDetails: `Сохранить данные карты`,
  addBankAccount: `Добавить банковский счет`,
  achBankDebitTerms: str =>
    `Предоставляя номер своего счета и подтверждая этот платеж, вы уполномочиваете ${str} и Hyperswitch, нашего поставщика платежных услуг, отправить инструкции в ваш банк для списания средств с вашего счета, а ваш банк — списать средства с вашего счета в соответствии с этими инструкциями. Вы имеете право на возврат средств от своего банка в соответствии с условиями вашего договора с банком. Заявление на возврат средств должно быть подано в течение 8 недель, начиная с даты списания средств с вашего счета.`,
  sepaDebitTerms: str =>
    `Предоставляя свои платежные данные и подтверждая данный платеж, вы уполномочиваете (А) ${str} и Hyperswitch, нашего поставщика платежных услуг и/или PPRO, его местного поставщика услуг, отправить инструкции в ваш банк для списания средств с вашего счета и (Б) ваш банк списать средства с вашего счета в соответствии с этими инструкциями. В рамках своих прав вы имеете право на возврат средств от своего банка в соответствии с условиями вашего договора с банком. Заявление на возврат средств должно быть подано в течение 8 недель, начиная с даты списания средств с вашего счета. Ваши права разъясняются в заявлении, которое вы можете получить в своем банке. Вы соглашаетесь получать уведомления о будущих списаниях средств за 2 дня до их осуществления.`,
  becsDebitTerms: `Предоставляя свои банковские реквизиты и подтверждая этот платеж, вы соглашаетесь с настоящим Запросом на прямое дебетование и соглашением об услуге Запроса на прямое дебетование и уполномочиваете Hyperswitch Payments Australia Pty Ltd ACN 160 180 343 Direct Debit User ID number 507156 («Hyperswitch») списать средства с вашего счета через Систему массовых электронных расчетов (BECS) от имени Платежного виджета Hyperswitch («Продавец») на любые суммы, отдельно сообщенные вам Продавцом. Вы подтверждаете, что являетесь владельцем счета или уполномоченным лицом с правом подписи по указанному выше счету.`,
  cardTerms: str =>
    `Предоставляя данные своей карты, вы позволяете компании ${str} списать средства с вашей карты для будущих платежей в соответствии с ее условиями.`,
  payNowButton: `Оплатить сейчас`,
  cardNumberEmptyText: `Необходимо указать номер карты`,
  cardExpiryDateEmptyText: `Необходимо указать дату окончания срока действия карты`,
  cvcNumberEmptyText: `Необходимо указать номер CVC`,
  enterFieldsText: `Заполните все поля`,
  enterValidDetailsText: `Введите действительные данные`,
  card: `Карта`,
  billingNameLabel: `Имя плательщика`,
  cardHolderName: `Имя держателя карты`,
  cardNickname: `Прозвище карты`,
  billingNamePlaceholder: `Имя и фамилия`,
  emailEmptyText: `Электронная почта не может быть пустой`,
  emailInvalidText: `Неверный адрес электронной почты`,
  line1EmptyText: `Адресная строка 1 не может быть пустой.`,
  line2EmptyText: `Адресная строка 2 не может быть пустой.`,
  cityEmptyText: `Город не может быть пустым`,
  postalCodeEmptyText: `Почтовый индекс не может быть пустым`,
  postalCodeInvalidText: `Неверный почтовый индекс`,
  stateEmptyText: `Штат не может быть пустым`,
  surchargeMsgAmount: (currency, str) => <>
    {React.string(`Дополнительная сумма в размере${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string({
      `${Utils.nbsp}будет применено к этой транзакции`
    })}
  </>,
  surchargeMsgAmountForCard: (currency, str) => <>
    {React.string(`Сумма доплаты до${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}будет применено к этой транзакции`)}
  </>,
  surchargeMsgAmountForOneClickWallets: `Возможна дополнительная плата`,
  on: `на`,
  \"and": `и`,
  nameEmptyText: str => `Пожалуйста, предоставьте свой ${str}`,
  completeNameEmptyText: str =>
    `Пожалуйста, предоставьте полную ${str}`,
  billingDetailsText: `Платежные реквизиты`,
  socialSecurityNumberLabel: `Номер социального страхования`,
  saveWalletDetails: `Данные кошельков будут сохранены после выбора.`,
  morePaymentMethods: `Больше способов оплаты`,
  useExistingPaymentMethods: `Используйте сохраненные способы оплаты`,
  nicknamePlaceholder: `Псевдоним карты (необязательно)`,
  selectPaymentMethodText: `Пожалуйста, выберите способ оплаты и повторите попытку.`,
  cardExpiredText: `Эта карта истекла`,
  cardHeader: `Информация о карте`,
  cardBrandConfiguredErrorText: str =>
    `${str} в данный момент не поддерживается.`,
  currencyNetwork: `Валютные сети`,
  expiryPlaceholder: `MM / ГГ`,
  dateOfBirth: `Дата рождения`,
  vpaIdLabel: `Идентификатор ВПА`,
  vpaIdEmptyText: `Идентификатор VPA не может быть пустым.`,
  vpaIdInvalidText: `Неверный идентификатор VPA`,
  dateofBirthRequiredText: `Дата рождения обязательна`,
  dateOfBirthInvalidText: `Возраст должен быть не меньше 18 лет`,
  dateOfBirthPlaceholderText: `Введите дату рождения`,
  formFundsInfoText: `Средства будут зачислены на этот счет`,
  formFundsCreditInfoText: pmLabel =>
    `Ваши средства будут зачислены на выбранный ${pmLabel}.`,
  formEditText: `Редактировать`,
  formSaveText: `Сохранить`,
  formSubmitText: `Отправить`,
  formSubmittingText: `Отправка`,
  formSubheaderCardText: `Данные вашей карты`,
  formSubheaderAccountText: pmLabel => `Ваш ${pmLabel}`,
  formHeaderReviewText: `Обзор`,
  formHeaderReviewTabLayoutText: pmLabel =>
    `Просмотрите данные вашего ${pmLabel}`,
  formHeaderBankText: bankTransferType =>
    `Введите банковские данные ${bankTransferType}`,
  formHeaderWalletText: walletTransferType =>
    `Введите данные кошелька ${walletTransferType}`,
  formHeaderEnterCardText: `Введите данные карты`,
  formHeaderSelectBankText: `Выберите метод банка`,
  formHeaderSelectWalletText: `Выберите кошелек`,
  formHeaderSelectAccountText: `Выберите счет для выплат`,
  formFieldACHRoutingNumberLabel: `Маршрутный номер`,
  formFieldSepaIbanLabel: `Международный номер банковского счета (IBAN)`,
  formFieldSepaBicLabel: `Банковский идентификационный код (опционально)`,
  formFieldPixIdLabel: `ID Pix`,
  formFieldBankAccountNumberLabel: `Номер банковского счета`,
  formFieldPhoneNumberLabel: `Номер телефона`,
  formFieldCountryCodeLabel: `Код страны (опционально)`,
  formFieldBankNameLabel: `Название банка (опционально)`,
  formFieldBankCityLabel: `Город банка (опционально)`,
  formFieldCardHoldernamePlaceholder: `Ваше имя`,
  formFieldBankNamePlaceholder: `Название банка`,
  formFieldBankCityPlaceholder: `Город банка`,
  formFieldEmailPlaceholder: `Ваш e-mail`,
  formFieldPhoneNumberPlaceholder: `Ваш телефон`,
  formFieldInvalidRoutingNumber: `Неверный маршрутный номер.`,
  infoCardRefId: `Идентификатор ссылки`,
  infoCardErrCode: `Код ошибки`,
  infoCardErrMsg: `Сообщение об ошибке`,
  infoCardErrReason: `Причина`,
  linkRedirectionText: seconds =>
    `Перенаправление через ${seconds->Int.toString} секунд ...`,
  linkExpiryInfo: expiry => `Ссылка истекает: ${expiry}`,
  payoutFromText: merchant => `Выплата от ${merchant}`,
  payoutStatusFailedMessage: `Не удалось обработать ваш платеж. Пожалуйста, свяжитесь с вашим поставщиком для получения дополнительной информации.`,
  payoutStatusPendingMessage: `Ваш платеж должен быть обработан в течение 2-3 рабочих дней.`,
  payoutStatusSuccessMessage: `Ваш платеж был успешно выполнен. Средства были зачислены на выбранный вами способ оплаты.`,
  payoutStatusFailedText: `Платеж успешен`,
  payoutStatusPendingText: `Платеж в процессе`,
  payoutStatusSuccessText: `Платеж не удался`,
}
