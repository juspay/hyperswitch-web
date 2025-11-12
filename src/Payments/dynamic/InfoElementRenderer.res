@react.component
let make = (~paymentMethodType, ~groupedFields) => {
  let shouldShowInfoElement = React.useMemo(() => {
    switch paymentMethodType {
    | "afterpay_clearpay"
    | "mb_way"
    | "mobile_pay"
    | "ali_pay"
    | "ali_pay_hk"
    | "we_chat_pay"
    | "duit_now"
    | "revolut_pay"
    | "affirm"
    | "pay_safe_card"
    | "crypto_currency"
    | "klarna"
    | "sofort"
    | "flexiti"
    | "breadpay"
    | "giropay"
    | "eps"
    | "walley"
    | "pay_bright"
    | "ach_debit"
    | "bacs_debit"
    | "becs_debit"
    | "blik"
    | "trustly"
    | "bancontact_card"
    | "online_banking_czech_republic"
    | "online_banking_slovakia"
    | "online_banking_finland"
    | "online_banking_poland"
    | "ideal"
    | "przelewy24"
    | "interac"
    | "twint"
    | "vipps"
    | "dana"
    | "go_pay"
    | "kakao_pay"
    | "gcash"
    | "momo"
    | "touch_n_go"
    | "bizum"
    | "classic"
    | "online_banking_fpx"
    | "online_banking_thailand"
    | "alma"
    | "atome"
    | "multibanco_transfer"
    | "card_redirect"
    | "open_banking_uk"
    | "open_banking_pis"
    | "evoucher"
    | "pix_transfer"
    | "boleto"
    | "local_bank_transfer_transfer"
    | "mifinity"
    | "skrill"
    | "bluecode"
    | "upi_collect"
    | "upi_intent"
    | "eft" => true
    | _ => false
    }
  }, [paymentMethodType])

  let bottomElement = <InfoElement />

  <RenderIf condition={shouldShowInfoElement}>
    {
      let (
        cardFields,
        emailFields,
        billingNameFields,
        billingPhoneFields,
        billingOtherFields,
        cryptoFields,
        otherFields,
      ) = groupedFields

      let hasMultipleFieldGroups =
        [
          cardFields,
          emailFields,
          billingNameFields,
          billingPhoneFields,
          billingOtherFields,
          cryptoFields,
          otherFields,
        ]
        ->Array.filter(fields => fields->Array.length > 0)
        ->Array.length > 1

      if hasMultipleFieldGroups {
        bottomElement
      } else {
        <Block bottomElement />
      }
    }
  </RenderIf>
}
