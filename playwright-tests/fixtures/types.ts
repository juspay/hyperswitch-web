// Shared test-data types.
export type { cardDetails, CardDetails } from "./cards";

export type CustomerData = {
  cardNo: string;
  cardExpiry: string;
  cardCVV: string;
  cardHolderName: string;
  email: string;
  address: string;
  city: string;
  country: string;
  state: string;
  postalCode: string;
  threeDSCardNo: string;
};
