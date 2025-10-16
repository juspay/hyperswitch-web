const fetch = require("node-fetch");
const express = require("express");
const { resolve } = require("path");
const dotenv = require("dotenv");
const rateLimit = require("express-rate-limit");

dotenv.config({ path: "./.env" });

const app = express();
const PORT = 5252;

app.use(express.json());

// ✅ Simple rate limiter: 60 requests per minute per IP
const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 300, // limit each IP to 300 requests per windowMs
});

// Helper: get URL from env or fallback
function getUrl(envVar, selfHostedValue) {
  return process.env[envVar] === selfHostedValue ? "" : process.env[envVar];
}

const SERVER_URL = getUrl("HYPERSWITCH_SERVER_URL", "SELF_HOSTED_SERVER_URL");
const CLIENT_URL = getUrl("HYPERSWITCH_CLIENT_URL", "SELF_HOSTED_CLIENT_URL");
const SDK_VERSION = process.env.SDK_VERSION || "v1";

// ✅ Serve static files automatically (index.html, assets)
app.use(express.static("./dist"));

// ✅ Dynamic routes are rate-limited for safety

app.get("/config", limiter, (req, res) => {
  res.send({
    publishableKey: process.env.HYPERSWITCH_PUBLISHABLE_KEY,
    profileId: process.env.PROFILE_ID,
  });
});

app.get("/urls", limiter, (req, res) => {
  res.send({
    serverUrl: SERVER_URL,
    clientUrl: CLIENT_URL,
  });
});

const paymentData = {
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
  authentication_type: "three_ds",
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
  billing: {
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

const paymentDataRequestV2 = {
  amount_details: {
    currency: "USD",
    order_amount: 6540,
  },
};

const profileId = process.env.PROFILE_ID;
if (profileId) {
  paymentData.profile_id = profileId;
}

function createPaymentRequest() {
  return paymentData;
}

function createPaymentRequestV2() {
  return paymentDataRequestV2;
}

app.get("/create-intent", limiter, async (req, res) => {
  try {
    const paymentRequest =
      SDK_VERSION === "v1" ? createPaymentRequest() : createPaymentRequestV2();
    const paymentIntent = await createPaymentIntent(paymentRequest);

    const response = {
      clientSecret: paymentIntent.client_secret,
    };

    if (SDK_VERSION === "v2") {
      response.paymentId = paymentIntent.id;
    }

    res.send(response);
  } catch (err) {
    res.status(400).send({
      error: { message: err.message },
    });
  }
});

app.get("/create-subscription-intent", limiter, async (req, res) => {
  try {
    const subscriptionRequest = {
      item_price_id: "cbdemo_enterprise-suite-monthly",
      plan_id: "cbdemo_enterprise-suite",
      customer_id: "cus_UWZdcjmhuYMpjZwjN3Ei",
      amount: 14100,
      currency: "USD",
      payment_details: {
        authentication_type: "no_three_ds",
        setup_future_usage: "off_session",
        capture_method: "automatic",
        return_url: "https://google.com",
      },
    };

    // const subscriptionIntentData = await createSubscriptionIntent(
    //   subscriptionRequest
    // );

    // Mocking the subscription intent response structure for demonstration
    // In real implementation, use `subscriptionIntentData` directly

    const subscriptionIntent = {
      id: "sub_Ue5uPczEc4daRANZzDKQ",
      merchant_reference_id: null,
      status: "created",
      plan_id: "cbdemo_enterprise-suite",
      item_price_id: "cbdemo_enterprise-suite-monthly",
      profile_id: "pro_KFLU7UDsPlfpvTMyaqqZ",
      client_secret: "sub_Ue5uPczEc4daRANZzDKQ_secret_LJ9lajaRXJLst9iNKi9n",
      merchant_id: "merchant_1760598696",
      coupon_code: null,
      customer_id: "cus_UWZdcjmhuYMpjZwjN3Ei",
      payment: {
        payment_id: "pay_Nb6v1iPZ40tSEAsf6cS4",
        status: "requires_payment_method",
        amount: 14100,
        currency: "USD",
        profile_id: "pro_KFLU7UDsPlfpvTMyaqqZ",
        connector: null,
        payment_method_id: null,
        return_url: "https://google.com/",
        next_action: null,
        payment_experience: null,
        error_code: null,
        error_message: null,
        payment_method_type: null,
        client_secret: "pay_Nb6v1iPZ40tSEAsf6cS4_secret_sS5fU9tLUgaYnHHXC1JG",
        billing: null,
        shipping: null,
        payment_type: null,
      },
      invoice: {
        id: "invoice_vtQWR83ONymeItqY3kt9",
        subscription_id: "sub_Ue5uPczEc4daRANZzDKQ",
        merchant_id: "merchant_1760598696",
        profile_id: "pro_KFLU7UDsPlfpvTMyaqqZ",
        merchant_connector_id: "mca_FxiVnB2O8vpfQo0KOu1n",
        payment_intent_id: "pay_Nb6v1iPZ40tSEAsf6cS4",
        payment_method_id: null,
        customer_id: "cus_UWZdcjmhuYMpjZwjN3Ei",
        amount: 14100,
        currency: "USD",
        status: "invoice_created",
      },
    };

    const response = {
      clientSecret: subscriptionIntent.payment.client_secret,
      subscriptionId: subscriptionIntent.id,
      subscriptionSecret: subscriptionIntent.client_secret,
    };

    if (SDK_VERSION === "v2") {
      response.paymentId = subscriptionIntent?.payment?.payment_id;
    }

    res.send(response);
  } catch (err) {
    res.status(400).send({
      error: { message: err.message },
    });
  }
});

async function createPaymentIntent(request) {
  const baseUrl =
    process.env.HYPERSWITCH_SERVER_URL_FOR_DEMO_APP ||
    process.env.HYPERSWITCH_SERVER_URL;

  let apiEndpoint = "";
  let headers = {
    "Content-Type": "application/json",
  };

  if (SDK_VERSION === "v1") {
    apiEndpoint = `${baseUrl}/payments`;
    headers = {
      ...headers,
      Accept: "application/json",
      "api-key": process.env.HYPERSWITCH_SECRET_KEY,
    };
  } else {
    apiEndpoint = `${baseUrl}/v2/payments/create-intent`;
    headers = {
      ...headers,
      Authorization: `api-key=${process.env.HYPERSWITCH_SECRET_KEY}`,
      "X-Profile-Id": process.env.PROFILE_ID,
    };
  }

  const apiResponse = await fetch(apiEndpoint, {
    method: "POST",
    headers,
    body: JSON.stringify(request),
  });

  const paymentIntent = await apiResponse.json();

  if (paymentIntent.error) {
    console.error("Payment Intent Error:", paymentIntent.error);
    throw new Error(paymentIntent?.error?.message ?? "Something went wrong.");
  }

  return paymentIntent;
}
async function createSubscriptionIntent(request) {
  const baseUrl =
    process.env.HYPERSWITCH_SERVER_URL_FOR_DEMO_APP ||
    process.env.HYPERSWITCH_SERVER_URL;

  let apiEndpoint = `${baseUrl}/subscriptions/create`;
  let headers = {
    "Content-Type": "application/json",
    "api-key": process.env.HYPERSWITCH_SECRET_KEY,
    "X-Profile-Id": process.env.PROFILE_ID,
  };

  const apiResponse = await fetch(apiEndpoint, {
    method: "POST",
    headers,
    body: JSON.stringify(request),
  });

  const intent = await apiResponse.json();

  if (intent.error) {
    console.error("Payment Intent Error:", intent.error);
    throw new Error(intent?.error?.message ?? "Something went wrong.");
  }

  return intent;
}

app.listen(PORT, () => {
  console.log(`Node server listening at http://localhost:${PORT}`);
});
