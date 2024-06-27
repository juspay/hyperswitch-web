const fetch = require("node-fetch");
const express = require("express");
const { resolve } = require("path");
const dotenv = require("dotenv");
const hyper = require("@juspay-tech/hyperswitch-node");
dotenv.config({ path: "./.env" });

const app = express();
const PORT = 5252;

const hyperswitch = hyper(process.env.HYPERSWITCH_SECRET_KEY);

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

function createPaymentRequest() {
  return {
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
  if (SERVER_URL) {
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
  } else {
    return await hyperswitch?.paymentIntents?.create(request);
  }
}

app.listen(PORT, () => {
  console.log(`Node server listening at http://localhost:${PORT}`);
});
