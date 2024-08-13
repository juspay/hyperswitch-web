//pay_gpmsaQ9AIL3MH78HN7gJ_secret_xlVSaOqXCtqRy4QjUKpY
const request = {
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

const stripeTestCard = "4000000000003220";
const adyenTestCard = "4917610000000000";
const bluesnapTestCard = "4000000000001091";

const confirmBody = {
  client_secret: "",
  return_url: "http://localhost:9060/completion",
  payment_method: "card",
  payment_method_data: {
    card: {
      card_number: stripeTestCard,
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

let clientSecret;
describe("Card payment flow test", () => {
  it("create payment can be written like this", () => {
    cy.createPaymentIntent();
  });
  it("Why to do duplicate stuff?", () => {
    const k = cy.getGlobalState("clientSecret");
    cy.log(k);
  });
  it("create-payment-intent-call-test", () => {
    cy.request({
      method: "POST",
      url: "https://sandbox.hyperswitch.io/payments",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "api-key": "snd_c691ade6995743bd88c166ba509ff5da",
      },
      body: JSON.stringify(request),
    }).then((response) => {
      expect(response.headers["content-type"]).to.include("application/json");
      expect(response.body).to.have.property("client_secret");
      clientSecret = response.body.client_secret;
      cy.log(clientSecret);
      cy.log(response);
    });
  });

  it("payment_methods-call-test", () => {
    cy.request({
      method: "GET",
      url: `https://sandbox.hyperswitch.io/account/payment_methods?client_secret=${clientSecret}`,
      headers: {
        "Content-Type": "application/json",
        "api-key": publishableKey,
      },
      body: JSON.stringify(request),
    }).then((response) => {
      expect(response.headers["content-type"]).to.include("application/json");
      expect(response.body).to.have.property("redirect_url");
      expect(response.body).to.have.property("payment_methods");

      console.log("cl-------------->" + clientSecret);
      cy.log(response);
    });
  });

  it("confirm-call-test", () => {
    let paymentIntentID = clientSecret.split("_secret_")[0];
    confirmBody["client_secret"] = clientSecret;
    console.log("paymentIntentID--------->" + paymentIntentID);
    cy.request({
      method: "POST",
      url: `https://sandbox.hyperswitch.io/payments/${paymentIntentID}/confirm`,
      headers: {
        "Content-Type": "application/json",
        "api-key": publishableKey,
      },
      body: confirmBody,
    }).then((response) => {
      expect(response.headers["content-type"]).to.include("application/json");
      expect(response.body).to.have.property("next_action");
      //   expect(response.body).to.have.property("redirect_to_url");

      //   clientSecret = response.body.client_secret;

      const nextActionUrl = response.body.next_action.redirect_to_url;
      cy.log(nextActionUrl);
      cy.visit(nextActionUrl);
    });
  });
});
