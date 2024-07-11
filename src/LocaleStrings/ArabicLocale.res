let localeStrings: LocaleStringTypes.localeStrings = {
  locale: "ar",
  localeDirection: "rtl",
  cardNumberLabel: `رقم البطاقة`,
  inValidCardErrorText: `رقم البطاقة غير صالحة`,
  inCompleteCVCErrorText: `رمز أمان بطاقتك غير مكتمل`,
  inCompleteExpiryErrorText: `تاريخ انتهاء صلاحية بطاقتك غير مكتمل`,
  pastExpiryErrorText: `انقضت سنة انتهاء صلاحية بطاقتك`,
  poweredBy: `مدعوم من هيبيرسويتش`,
  validThruText: `صالحة من خلال`,
  sortCodeText: `الكود البنكى`,
  accountNumberText: `رقم حساب`,
  cvcTextLabel: `رمز الحماية`,
  emailLabel: `البريد الإلكتروني`,
  emailEmptyText: `لا يمكن أن يكون البريد الإلكتروني فارغًا`,
  emailInvalidText: `عنوان البريد الإلكتروني غير صالح`,
  fullNameLabel: `الاسم الكامل`,
  line1Label: `العنوان سطر 1`,
  line1Placeholder: `.عنوان الشارع`,
  line1EmptyText: `لا يمكن أن يكون سطر العنوان 1 فارغًا`,
  line2Label: `سطر العنوان 2`,
  line2Placeholder: `مناسب ، رقم الوحدة ، إلخ (اختياري)`,
  line2EmptyText: `لا يمكن أن يكون سطر العنوان 2 فارغًا`,
  postalCodeLabel: `رمز بريدي`,
  postalCodeEmptyText: `لا يمكن أن يكون الرمز البريدي فارغًا`,
  postalCodeInvalidText: `الرمز البريدي غير صالح`,
  stateLabel: `ولاية`,
  stateEmptyText: `لا يمكن أن تكون الحالة فارغة`,
  cityLabel: `مدينة`,
  cityEmptyText: `لا يمكن أن تكون المدينة فارغة`,
  fullNamePlaceholder: `الاسم الأول والاسم الأخير`,
  countryLabel: `دولة`,
  currencyLabel: `عملة`,
  bankLabel: `حدد البنك`,
  redirectText: `بعد تقديم طلبك ، ستتم إعادة توجيهك لإكمال عملية الشراء بشكل آمن.`,
  bankDetailsText: `بعد إرسال هذه التفاصيل ، ستحصل على معلومات الحساب المصرفي لإجراء الدفع. يُرجى التأكد من تدوين ذلك.`,
  orPayUsing: `أو الدفع باستخدام`,
  addNewCard: `أضف بطاقة جديدة`,
  useExisitingSavedCards: `استخدم البطاقات المحفوظة الموجودة`,
  saveCardDetails: `حفظ تفاصيل البطاقة`,
  addBankAccount: `إضافة حساب مصرفي`,
  achBankDebitTerms: str =>
    `من خلال تقديم رقم حسابك وتأكيد هذا الدفع ، فإنك تفوض ${str} و Hyperswitch ، مزود خدمة الدفع ، لإرسال تعليمات إلى البنك الذي تتعامل معه للخصم من حسابك والبنك الخاص بك للخصم من حسابك وفقًا لهذه التعليمات. يحق لك استرداد الأموال من البنك الذي تتعامل معه بموجب شروط وأحكام اتفاقيتك مع البنك الذي تتعامل معه. يجب المطالبة باسترداد الأموال في غضون 8 أسابيع بدءًا من تاريخ الخصم من حسابك.`,
  sepaDebitTerms: str =>
    `من خلال تقديم معلومات الدفع الخاصة بك وتأكيد هذا الدفع ، فإنك تفوض (أ) ${str} و Hyperswitch ، موفر خدمة الدفع لدينا و / أو PPRO ، مزود الخدمة المحلي ، لإرسال تعليمات إلى البنك الذي تتعامل معه للخصم من حسابك و (ب) البنك الذي تتعامل معه للخصم من حسابك وفقًا لتلك التعليمات. كجزء من حقوقك ، يحق لك استرداد الأموال من البنك الذي تتعامل معه بموجب شروط وأحكام اتفاقيتك مع البنك الذي تتعامل معه. يجب المطالبة باسترداد الأموال في غضون 8 أسابيع بدءًا من تاريخ الخصم من حسابك. يتم توضيح حقوقك في بيان يمكنك الحصول عليه من البنك الذي تتعامل معه. أنت توافق على تلقي إشعارات بالخصم المستقبلي لمدة تصل إلى يومين قبل حدوثها.`,
  becsDebitTerms: `من خلال تقديم تفاصيل حسابك المصرفي وتأكيد هذه الدفعة ، فإنك توافق على طلب الخصم المباشر هذا واتفاقية خدمة طلب الخصم المباشر وتفوض Hyperswitch Payments Australia Pty Ltd ACN 160180343 رقم معرف مستخدم الخصم المباشر 507156 ("Hyperswitch") للخصم من حسابك حساب من خلال نظام المقاصة الإلكترونية المجمعة (BECS) نيابة عن Hyperswitch Payment Widget ("التاجر") لأي مبالغ يرسلها التاجر لك بشكل منفصل. أنت تقر بأنك إما صاحب حساب أو مفوض بالتوقيع على الحساب المذكور أعلاه.`,
  cardTerms: str =>
    `من خلال تقديم معلومات بطاقتك ، فإنك تسمح لـ ${str} بشحن بطاقتك للمدفوعات المستقبلية وفقًا لشروطها.`,
  payNowButton: `ادفع الآن`,
  cardNumberEmptyText: `لا يمكن أن يكون رقم البطاقة فارغاً`,
  cardExpiryDateEmptyText: `لا يمكن أن يكون تاريخ انتهاء البطاقة فارغاً`,
  cvcNumberEmptyText: `لا يمكن أن يكون رقم التحقق من البطاقة (CVC) فارغًا`,
  enterFieldsText: `الرجاء إدخال كافة الحقول`,
  enterValidDetailsText: `الرجاء إدخال تفاصيل صالحة`,
  selectPaymentMethodText: `الرجاء تحديد طريقة الدفع والمحاولة مرة أخرى`,
  card: `بطاقة`,
  surchargeMsgAmount: (currency, str) => <>
    {React.string(`سيتم تطبيق مبلغ إضافي من${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}على هذه المعاملة`)}
  </>,
  surchargeMsgAmountForCard: (currency, str) => <>
    {React.string(`سيتم تطبيق مبلغ إضافي يصل إلى${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}على هذه المعاملة`)}
  </>,
  surchargeMsgAmountForOneClickWallets: `رسوم إضافية قابلة للتطبيق`,
  billingNameLabel: `اسم الفواتير`,
  billingNamePlaceholder: `الاسم الأول والاسم الأخير`,
  cardHolderName: `إسم صاحب البطاقة`,
  on: `على`,
  \"and": `و`,
  nameEmptyText: str => `يرجى تقديم الخاص بك ${str}`,
  completeNameEmptyText: str => `يرجى تقديم كامل الخاص بك ${str}`,
  billingDetailsText: `تفاصيل الفاتورة`,
  socialSecurityNumberLabel: `رقم الضمان الاجتماعي`,
  saveWalletDetails: `سيتم حفظ تفاصيل المحفظة عند الاختيار`,
  morePaymentMethods: `المزيد من طرق الدفع`,
  useExistingPaymentMethods: `استخدم طرق الدفع المحفوظة`,
  cardNickname: `الاسم علي الكارت`,
  nicknamePlaceholder: `اسم البطاقة (اختياري)`,
  cardExpiredText: `انتهت صلاحية هذه البطاقة`,
  cardHeader: `معلومات البطاقة`,
  cardBrandConfiguredErrorText: str => `${str} غير مدعوم في الوقت الحالي.`,
  currencyNetwork: `شبكات العملات`,
  expiryPlaceholder: `MM / YY`,
  dateOfBirth: `تاريخ الميلاد`,
  vpaIdLabel: `معرف VPA`,
  vpaIdEmptyText: `لا يمكن أن يكون معرف Vpa فارغًا`,
  vpaIdInvalidText: `معرف Vpa غير صالح`,
}
