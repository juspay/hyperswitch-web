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

// const paymentData = {
//   "amount": 5044,
//   "currency": "USD",
//   "shipping_cost": 5000,
//   "order_tax_amount": 1000,
//   "confirm": false,
//   "metadata": {
//       "delivery_options": [
//           {
//               "id": "standard-delivery",
//               "price":{
//                   "amount": "20.00",
//                   "currency_code":"USD"
//               },
//               "shipping_method":{
//                   "shipping_method_name":"standard-courier",
//                   "shipping_method_code":"standard-courier"
//               },
//               "is_default":true
//           },
//           {
//               "id":"express-delivery",
//               "price":{
//                   "amount":"50",
//                   "currency_code":"USD"
//               },
//               "shipping_method":{
//                   "shipping_method_name":"express-courier",
//                   "shipping_method_code":"express-courier"
//               },
//               "is_default":false
//           }
//       ]
//   },
//   "shipping": {
//       "address": {
//           "line1": "10 Ditka Ave",
//           "line2": "Suite 2500",
//           "line3": null,
//           "city": "Chicago",
//           "state": "IL",
//           "zip": "60602",
//           "country": "US",
//           "first_name": "Susie",
//           "last_name": "Smith"
//       },
//       "phone": {
//           "number": "8000000000"
//       }
//   }
// };

// console.log(paymentData.metadata);

const paymentData = {
  "amount": 5044,
  "currency": "USD",
  "shipping_cost": 2000,
  "order_tax_amount": 1000,
  "confirm": false,
  "metadata": {
      "delivery_options": [
          {
              "id": "standard-delivery",
              "price":{
                  "amount": 2000,
                  "currency_code":"USD"
              },
              "shipping_method":{
                  "shipping_method_name":"standard-courier",
                  "shipping_method_code":"standard-courier"
              },
              "is_default":true
          },
          {
              "id":"express-delivery",
              "price":{
                  "amount": 5000,
                  "currency_code":"USD"
              },
              "shipping_method":{
                  "shipping_method_name":"express-courier",
                  "shipping_method_code":"express-courier"
              },
              "is_default":false
          }
      ]
  }
}

const profileId = process.env.PROFILE_ID;
if (profileId) {
  paymentData.profile_id = profileId;
}

function createPaymentRequest() {
  // console.log("heelo",paymentData.metadata);
  return paymentData;
}

app.get("/create-payment-intent", async (_, res) => {
  try {
    // console.log("here")
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
