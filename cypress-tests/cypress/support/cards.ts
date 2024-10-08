export type cardDetails = {
    cardNo: string,
    cardScheme: string,
    cvc: string,
    card_exp_month: string,
    card_exp_year: string,
    
}


type connectorCard = {
    successCard: cardDetails
    failureCard: cardDetails
    threeDSCard: cardDetails
    invalidCard: cardDetails
    invalidCVC : cardDetails
    invalidMonth:cardDetails
    invalidYear: cardDetails
}


export const stripeCards = {
    successCard: {
        cardNo: "4242424242424242",
        cardScheme: "Visa",
        cvc: "123",
        card_exp_month:"12",
        card_exp_year:"30",
    },
    failureCard: {
        cardNo: "4000000000000002",
        cardScheme: "Visa",
        cvc: "123",
        card_exp_month:"12",
        card_exp_year:"30",
    },
    invalidYear: {
        cardNo: "4242424242424242",
        cardScheme: "Visa",
        cvc: "123",
        card_exp_month:"12",
        card_exp_year:"10",
    },
    invalidCVC: {
        cardNo: "4000000000000002",
        cardScheme: "Visa",
        cvc: "12",
        card_exp_month:"12",
        card_exp_year:"30",
    },
    invalidCard: {
        cardNo: "400000000000000",
        cardScheme: "Visa",
        cvc: "123",
        card_exp_month:"12",
        card_exp_year:"30",
    },
    invalidMonth: {
        cardNo: "4000000000000002",
        cardScheme: "Visa",
        cvc: "123",
        card_exp_month:"13",
        card_exp_year:"30",
    },
    threeDSCard: {
        cardNo: "4000000000003220",
        cardScheme: "Visa",
        cvc: "123",
        card_exp_month:"13",
        card_exp_year:"30",
    },
}