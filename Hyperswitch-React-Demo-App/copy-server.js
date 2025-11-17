const fetch = require("node-fetch");
const express = require("express");
const { resolve } = require("path");
const dotenv = require("dotenv");
dotenv.config({ path: "./.env" });

const app = express();
const PORT = 5252;

function getUrl(envVar, selfHostedValue) {
  return process.env[envVar] === selfHostedValue ? "" : process.env[envVar];
}

const SERVER_URL = getUrl("HYPERSWITCH_SERVER_URL", "SELF_HOSTED_SERVER_URL");
const CLIENT_URL = getUrl("HYPERSWITCH_CLIENT_URL", "SELF_HOSTED_CLIENT_URL");

app.use(express.static("./dist"));
app.get("/", (req, res) => {
  const path = resolve("./dist/index.html");
  res.sendFile(path);
});
app.get("/completion", (req, res) => {
  const path = resolve("./dist/index.html");
  res.sendFile(path);
});
app.get("/config", (req, res) => {
  res.send({
    publishableKey: process.env.HYPERSWITCH_PUBLISHABLE_KEY,
  });
});

app.get("/urls", (req, res) => {
  res.send({
    serverUrl: SERVER_URL,
    clientUrl: CLIENT_URL,
  });
});

const paymentData = {
  amount: 6500,
  order_details: [
    {
      product_name: "Apple iphone 15",
      quantity: 1,
      amount: 6500,
    },
  ],
  currency: "EUR",
  confirm: false,
  capture_method: "automatic",
  authentication_type: "three_ds",
  setup_future_usage: "on_session",
  request_external_three_ds_authentication: true,
  email: "abhishek.c@juspay.in",
  description: "Hello this is description",
  profile_id: "pro_1PEZIEJyHhhZ3WJTVIVM",
  shipping: {
    address: {
      state: "Ceuta",
      city: "Banglore",
      country: "ES",
      line1: "sdsdfsdf",
      line2: "hsgdbhd",
      line3: "alsksoe",
      zip: "571201",
      first_name: "John",
      last_name: "Doe",
    },
    phone: {
      number: "123456789",
      country_code: "+1",
    },
  },
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
  billing: {
    address: {
      line1: "1467",
      line2: "Harrison Street",
      line3: "Harrison Street",
      city: "San Fransico",
      state: "Ceuta",
      zip: "94122",
      country: "ES",
      first_name: "joseph",
      last_name: "Doe",
    },
    phone: {
      number: "8056594427",
      country_code: "+91",
    },
  },
  customer_id: "hyperswitch_sdk_demo_id",
};

const profileId = process.env.PROFILE_ID;
if (profileId) {
  paymentData.profile_id = profileId;
}

function createPaymentRequest() {
  return paymentData;
}

app.get("/create-payment-intent", async (_, res) => {
  try {
    const paymentRequest = createPaymentRequest();
    const paymentIntent = await createPaymentIntent(paymentRequest);

    res.send({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (err) {
    res.status(400).send({
      error: { message: err.message },
    });
  }
});

async function createPaymentIntent(request) {
  const url =
    process.env.HYPERSWITCH_SERVER_URL_FOR_DEMO_APP ||
    process.env.HYPERSWITCH_SERVER_URL;
  const apiResponse = await fetch(`${url}/payments`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "api-key": process.env.HYPERSWITCH_SECRET_KEY,
    },
    body: JSON.stringify(request),
  });
  const paymentIntent = await apiResponse.json();

  if (paymentIntent.error) {
    console.error("Error - ", paymentIntent.error);
    throw new Error(paymentIntent?.error?.message ?? "Something went wrong.");
  }
  return paymentIntent;
}

app.listen(PORT, () => {
  console.log(`Node server listening at http://localhost:${PORT}`);
});