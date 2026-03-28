export type cardDetails = {
  cardNo: string;
  cardScheme: string;
  cvc: string;
  card_exp_month: string;
  card_exp_year: string;
};

type connectorCard = {
  successCard: cardDetails;
  threeDSCard: cardDetails;
  invalidCard: cardDetails;
};

export const stripeCards = {
  successCard: {
    cardNo: "4242424242424242",
    cardScheme: "Visa",
    cvc: "123",
    card_exp_month: "12",
    card_exp_year: "30",
  },
  invalidCard: {
    cardNo: "400000000000000",
    cardScheme: "Visa",
    cvc: "123",
    card_exp_month: "12",
    card_exp_year: "30",
  },
  threeDSCard: {
    cardNo: "4000000000003220",
    cardScheme: "Visa",
    cvc: "123",
    card_exp_month: "13",
    card_exp_year: "30",
  },
  unionPay19: {
    cardNo: "6205500000000000004",
    cardScheme: "UnionPay",
    cvc: "123",
    card_exp_month: "12",
    card_exp_year: "30",
  },
  masterCard16: {
    cardNo: "5555555555554444",
    cardScheme: "MasterCard",
    cvc: "123",
    card_exp_month: "12",
    card_exp_year: "30",
  },
  amexCard15: {
    cardNo: "378282246310005",
    cardScheme: "American Express",
    cvc: "1234",
    card_exp_month: "12",
    card_exp_year: "30",
  },
  dinersClubCard14: {
    cardNo: "36227206271667",
    cardScheme: "Diners Club",
    cvc: "123",
    card_exp_month: "12",
    card_exp_year: "30",
  },
};

const redsysCardsDefaultData = {
  cardScheme: "Visa",
  cvc: "123",
  card_exp_month: "12",
  card_exp_year: "30",
};

export const redsysCards = {
  threedsInvokeChallengeTestCard: {
    cardNo: "4918019199883839",
    ...redsysCardsDefaultData,
  },
  threedsInvokeFrictionlessTestCard: {
    cardNo: "4918019160034602",
    ...redsysCardsDefaultData,
  },
  challengeTestCard: {
    cardNo: "4548817212493017",
    ...redsysCardsDefaultData,
  },
  frictionlessTestCard: {
    cardNo: "4548814479727229",
    ...redsysCardsDefaultData,
  },
};

const trustpayCardsDefaultData = {
  cardScheme: "Visa",
  cvc: "123",
  card_exp_month: "12",
  card_exp_year: "30",
};

export const trustpayCards = {
  successCard: {
    cardNo: "4200000000000000",
    ...trustpayCardsDefaultData,
  },
  threeDSCard: {
    cardNo: "4200000000000067",
    ...trustpayCardsDefaultData,
  },
  invalidCard: {
    cardNo: "400000000000000",
    ...trustpayCardsDefaultData,
  },
};

const cybersourceCardsDefaultData = {
  cardScheme: "Visa",
  cvc: "123",
  card_exp_month: "12",
  card_exp_year: "30",
};

export const cybersourceCards = {
  successCard: {
    cardNo: "4242424242424242",
    ...cybersourceCardsDefaultData,
  },
  invalidCard: {
    cardNo: "400000000000000",
    ...cybersourceCardsDefaultData,
  },
};

const bankOfAmericaCardsDefaultData = {
  cardScheme: "Visa",
  cvc: "123",
  card_exp_month: "12",
  card_exp_year: "30",
};

export const bankOfAmericaCards = {
  successCard: {
    cardNo: "4242424242424242",
    ...bankOfAmericaCardsDefaultData,
  },
  invalidCard: {
    cardNo: "400000000000000",
    ...bankOfAmericaCardsDefaultData,
  },
};

// ─── Stripe Decline / Special Test Cards ────────────────────────────────────
export const stripeSpecialCards = {
  // This card is always declined by Stripe sandbox
  declinedCard: {
    cardNo: "4000000000000002",
    cardScheme: "Visa",
    cvc: "123",
    card_exp_month: "12",
    card_exp_year: "30",
  },
  // Insufficient funds decline
  insufficientFundsCard: {
    cardNo: "4000000000009995",
    cardScheme: "Visa",
    cvc: "123",
    card_exp_month: "12",
    card_exp_year: "30",
  },
};

// ─── Gift Card (Givex / Adyen) ───────────────────────────────────────────────
export const givexGiftCardDetails = {
  // Adyen Givex sandbox test card
  successCard: {
    cardNo: "6006491588888886",
    cardPin: "1234",
  },
};

// ─── ACH Bank Transfer (Stripe) ──────────────────────────────────────────────
export const achBankTransferDetails = {
  // Stripe test bank account (US)
  success: {
    routingNumber: "110000000",
    accountNumber: "000123456789",
    accountHolderName: "John Doe",
  },
  invalid: {
    routingNumber: "000000000",
    accountNumber: "000",
    accountHolderName: "John Doe",
  },
};

// ─── PIX Transfer (Adyen / Brazil) ──────────────────────────────────────────
export const pixTransferDetails = {
  validCpf: "12345678909",
  validEmail: "test@hyperswitch.io",
  validPhone: "+5511999999999",
  invalidKey: "not-a-valid-pix-key",
};
