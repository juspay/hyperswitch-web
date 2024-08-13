export const CLIENT_URL = "http://localhost:9060"

export const request = {
  currency: "USD",
  amount: 6500,
  authentication_type: "three_ds",
  description: "Joseph First Crypto",
  email: "hyperswitch_sdk_demo_id@gmail.com",
  connector_metadata: {
    noon: {
      order_category: "applepay",
    },
  },
  metadata: {
    udf1: "value1",
    new_customer: "true",
    login_date: "2019-09-10T10:11:12Z",
  },
  //   customer_id: "hyperswitch_sdk_demo_test_id",
  business_country: "US",
  business_label: "default",
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
