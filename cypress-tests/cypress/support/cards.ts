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
