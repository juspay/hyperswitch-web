const express = require("express");
const app = express();
const { resolve } = require("path");

// Replace if using a different env file or config
const env = require("dotenv").config({ path: "./.env" });
app.use(express.static(process.env.STATIC_DIR));
app.get("/", (req, res) => {
  const path = resolve(process.env.STATIC_DIR + "/index.html");
  res.sendFile(path);
});

// replace the test api key with your hyperswitch api key
const hyper = require("@juspay-tech/hyperswitch-node")(
  process.env.HYPERSWITCH_SECRET_KEY
);

app.get("/config", (req, res) => {
  res.send({
    publishableKey: process.env.HYPERSWITCH_PUBLISHABLE_KEY,
  });
});

app.post("/create-payment-intent", async (req, res) => {
  try {
    const paymentIntent = await hyper.paymentIntents.create({
      currency: "USD",
      amount: 2999,
    });

    // Send publishable key and PaymentIntent details to client
    res.send({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (err) {
    return res.status(400).send({
      error: {
        message: err.message,
      },
    });
  }
});

app.listen(5252, () =>
  console.log(`Node server listening at http://localhost:5252`)
);
