type paymentDetails = {
  type_: string,
  icon: option<React.element>,
  displayName: string,
}
let defaultPaymentDetails = {
  type_: "",
  icon: None,
  displayName: "",
}
let icon = (~size=22, ~width=size, name) => {
  <Icon size width name />
}
let details = [
  {
    type_: "card",
    icon: Some(icon("default-card", ~size=19)),
    displayName: "Card",
  },
  {
    type_: "crypto_currency",
    icon: Some(icon("crypto", ~size=19)),
    displayName: "Crypto",
  },
  {
    type_: "klarna",
    icon: Some(icon("klarna", ~size=19)),
    displayName: "Klarna",
  },
  {
    type_: "afterpay_clearpay",
    icon: Some(icon("afterpay", ~size=19)),
    displayName: "After Pay",
  },
  {
    type_: "affirm",
    icon: Some(icon("affirm", ~size=19)),
    displayName: "Affirm",
  },
  {
    type_: "sofort",
    icon: Some(icon("sofort", ~size=19)),
    displayName: "Sofort",
  },
  {
    type_: "ach_transfer",
    icon: Some(icon("ach", ~size=19)),
    displayName: "ACH Transfer",
  },
  {
    type_: "sepa_transfer",
    icon: Some(icon("ach", ~size=19)),
    displayName: "Sepa Transfer",
  },
  {
    type_: "bacs_transfer",
    icon: Some(icon("ach", ~size=19)),
    displayName: "Bacs Transfer",
  },
  {
    type_: "giropay",
    icon: Some(icon("giropay", ~size=19, ~width=25)),
    displayName: "GiroPay",
  },
  {
    type_: "eps",
    icon: Some(icon("eps", ~size=19, ~width=25)),
    displayName: "EPS",
  },
  {
    type_: "ideal",
    icon: Some(icon("ideal", ~size=19, ~width=25)),
    displayName: "iDEAL",
  },
  {
    type_: "ban_connect",
    icon: None,
    displayName: "Ban Connect",
  },
  {
    type_: "ach_debit",
    icon: Some(icon("ach", ~size=19)),
    displayName: "ACH Debit",
  },
  {
    type_: "sepa_debit",
    icon: Some(icon("sepa", ~size=19, ~width=25)),
    displayName: "SEPA Debit",
  },
  {
    type_: "bacs_debit",
    icon: Some(icon("bank", ~size=21)),
    displayName: "BACS Debit",
  },
  {
    type_: "becs_debit",
    icon: Some(icon("bank", ~size=21)),
    displayName: "BECS Debit",
  },
  {
    type_: "boleto",
    icon: Some(icon("boleto", ~size=21)),
    displayName: "Boleto",
  },
]
