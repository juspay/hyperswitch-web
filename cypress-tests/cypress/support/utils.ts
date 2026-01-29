export const CLIENT_BASE_URL = "http://localhost:9060";

export const getClientURL = (clientSecret, publishableKey) => {
  return `${CLIENT_BASE_URL}?isCypressTestMode=true&clientSecret=${clientSecret}&publishableKey=${publishableKey}`;
};

export const enum connectorEnum {
  TRUSTPAY,
  ADYEN,
  STRIPE,
  NETCETERA,
  REDSYS,
  MIFINITY,
  CRYPTOPAY,
  BANK_OF_AMERICA,
  CYBERSOURCE,
  CASHTOCODE,
  JUSPAY
}
export const connectorProfileIdMapping = new Map<connectorEnum, string>([
  [connectorEnum.TRUSTPAY, "pro_eP323T9e4ApKpilWBfPA"],
  [connectorEnum.ADYEN, "pro_Kvqzu8WqBZsT1OjHlCj4"],
  [connectorEnum.STRIPE, "pro_5fVcCxU8MFTYozgtf0P8"],
  [connectorEnum.NETCETERA, "pro_h9VHXnJx8s6W4KSZfSUL"],
  [connectorEnum.REDSYS, "pro_6BcODfWXoRbntNHkNV1J"],
  [connectorEnum.MIFINITY, "pro_reQgggKZjGvnmnJ7O10c"],
  [connectorEnum.CRYPTOPAY, "pro_cy1AdBRB5jfCuiWgJUZM"],
  [connectorEnum.BANK_OF_AMERICA, "pro_Y90w9nPTg5eBOblKa2L9"],
  [connectorEnum.CYBERSOURCE, "pro_h9VHXnJx8s6W4KSZfSUL"],
  [connectorEnum.CASHTOCODE, "pro_JRdEyK7YyQaDAAzvJuMJ"],
  [connectorEnum.JUSPAY, "pro_TD0ZZ3cwf87wpPoZroSE"],
]);

export const createPaymentBody = {
  currency: "USD",
  amount: 2999,
  order_details: [
    {
      product_name: "Apple iPhone 15",
      quantity: 1,
      amount: 2999,
    },
  ],
  confirm: false,
  capture_method: "automatic",
  authentication_type: "no_three_ds",
  customer_id: "hyperswitch_sdk_demo_id",
  email: "hyperswitch_sdk_demo_id@gmail.com",
  request_external_three_ds_authentication: false,
  description: "Hello this is description",
  shipping: {
    address: {
      line1: "1467",
      line2: "Harrison Street",
      line3: "Harrison Street",
      city: "San Fransico",
      state: "California",
      zip: "94122",
      country: "US",
      first_name: "joseph",
      last_name: "Doe",
    },
    phone: {
      number: "8056594427",
      country_code: "+91",
    },
  },
  metadata: {
    udf1: "value1",
    new_customer: "true",
    login_date: "2019-09-10T10:11:12Z",
  },
  profile_id: "pro_5fVcCxU8MFTYozgtf0P8",
  billing: {
    email: "hyperswitch_sdk_demo_id@gmail.com",
    address: {
      line1: "1467",
      line2: "Harrison Street",
      line3: "Harrison Street",
      city: "San Fransico",
      state: "California",
      zip: "94122",
      country: "US",
      first_name: "joseph",
      last_name: "Doe",
    },
    phone: {
      number: "8056594427",
      country_code: "+91",
    },
  },
};

export const changeObjectKeyValue = (
  object: Record<string, any>,
  key: string,
  value: boolean | string | object,
) => {
  object[key] = value;
};

export const confirmBody = {
  client_secret: "",
  return_url: "http://localhost:9060/completion",
  payment_method: "card",
  payment_method_data: {
    card: {
      card_number: "4000000000001091",
      card_exp_month: "01",
      card_exp_year: "28",
      card_holder_name: "",
      card_cvc: "424",
      card_issuer: "",
      card_network: "Visa",
    },
  },
  billing: {
    address: {
      state: "New York",
      city: "New York",
      country: "US",
      first_name: "John",
      last_name: "Doe",
      zip: "10001",
      line1: "123 Main Street Apt 4B",
    },
  },
  email: "hyperswitch_sdk_demo_id@gmail.com",
  browser_info: {
    user_agent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    accept_header:
      "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
    language: "en-US",
    color_depth: 30,
    screen_height: 1117,
    screen_width: 1728,
    time_zone: -330,
    java_enabled: true,
    java_script_enabled: true,
  },
};
export const stripeTestCard = "4000000000003220";
export const adyenTestCard = "4917610000000000";
export const bluesnapTestCard = "4000000000001091";
export const amexTestCard = "378282246310005";
export const visaTestCard = "4242424242424242";
export const netceteraChallengeTestCard = "348638267931507";
export const netceteraFrictionlessTestCard = "4929251897047956";
export const juspayChallengeTestCard = "5306889942833340";
export const juspayFrictionlessTestCard = "4929251897047956";
