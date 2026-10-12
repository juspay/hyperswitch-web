// Static test data: the customer used to fill card and billing fields, and
// payment method display names.
import type { CustomerData } from "./types";

export const testCustomer: CustomerData & {
  billingName: string;
  paymentSuccessfulText: string;
} = {
  cardNo: "4242 4242 4242 4242",
  threeDSCardNo: "4000000000003220",
  cardExpiry: "04/24",
  cardCVV: "424",
  billingName: "John Doe",
  cardHolderName: "John Doe",
  email: "arun@gmail.com",
  address: "123 Main Street Apt 4B",
  city: "New York",
  country: "United States",
  state: "New York",
  postalCode: "10001",
  paymentSuccessfulText: "Payment successful",
};

export const paymentMethodNames = {
  card: "Card",
  klarna: "Klarna",
  affirm: "Affirm",
  aliPay: "Ali Pay",
  weChatPay: "WeChat",
} as const;
