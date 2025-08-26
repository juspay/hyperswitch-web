const fetch = require("node-fetch");
const express = require("express");
const { resolve } = require("path");
const dotenv = require("dotenv");
const rateLimit = require("express-rate-limit");

dotenv.config({ path: "./.env" });

const app = express();
const PORT = 5253;

// Add CORS headers
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

app.use(express.json());

// Rate limiter: 300 requests per minute per IP
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

// Serve static files automatically (index.html, assets)
app.use(express.static("./dist"));

// Dynamic routes are rate-limited for safety
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

// Mock subscription plans data
const SUBSCRIPTION_PLANS = [
  {
    id: "basic_monthly",
    name: "Basic",
    price: 9.99,
    interval: "month",
    description: "Perfect for individuals getting started",
    features: [
      "Up to 5 projects",
      "10GB storage",
      "Email support",
      "Basic analytics"
    ],
    trial: false,
    popular: false
  },
  {
    id: "pro_monthly",
    name: "Pro",
    price: 29.99,
    interval: "month",
    description: "Best for growing teams and businesses",
    features: [
      "Unlimited projects",
      "100GB storage",
      "Priority support",
      "Advanced analytics",
      "Team collaboration",
      "API access"
    ],
    trial: true,
    trialDays: 14,
    popular: true
  },
  {
    id: "enterprise_monthly",
    name: "Enterprise",
    price: 99.99,
    interval: "month",
    description: "For large organizations with advanced needs",
    features: [
      "Everything in Pro",
      "Unlimited storage",
      "24/7 phone support",
      "Custom integrations",
      "Advanced security",
      "Dedicated account manager"
    ],
    trial: true,
    trialDays: 30,
    popular: false
  }
];

// Mock coupons
const MOCK_COUPONS = {
  "SAVE20": { code: "SAVE20", discount: 20, description: "20% off your subscription" },
  "WELCOME25": { code: "WELCOME25", discount: 25, description: "25% off for new customers" },
  "SUMMER30": { code: "SUMMER30", discount: 30, description: "Summer special - 30% off" }
};

// Subscription endpoints
app.get("/subscription/plans", limiter, (req, res) => {
  res.send(SUBSCRIPTION_PLANS);
});

app.post("/subscription/create-session", limiter, async (req, res) => {
  try {
    const { planId, couponCode } = req.body;
    
    const plan = SUBSCRIPTION_PLANS.find(p => p.id === planId);
    if (!plan) {
      return res.status(404).send({ error: { message: "Plan not found" } });
    }

    let amount = plan.price;
    
    // Apply coupon discount if provided
    if (couponCode && MOCK_COUPONS[couponCode]) {
      const coupon = MOCK_COUPONS[couponCode];
      amount = amount * (1 - coupon.discount / 100);
    }

    // For trial plans, first payment is $0
    if (plan.trial) {
      amount = 0;
    }

    // Create a payment intent for the subscription
    const paymentIntent = await createSubscriptionPaymentIntent({
      amount: Math.round(amount * 100), // Convert to cents
      currency: "USD",
      planId,
      couponCode,
      trial: plan.trial,
      trialDays: plan.trialDays
    });

    res.send({
      clientSecret: paymentIntent.client_secret,
      sessionId: `session_${Date.now()}`,
      amount: parseFloat(amount.toFixed(2))
    });
  } catch (err) {
    console.error("Subscription session creation error:", err);
    res.status(400).send({
      error: { message: err.message || "Failed to create subscription session" },
    });
  }
});

app.post("/subscription/apply-coupon", limiter, (req, res) => {
  try {
    const { planId, couponCode, sessionId } = req.body;
    
    const coupon = MOCK_COUPONS[couponCode.toUpperCase()];
    if (!coupon) {
      return res.status(400).send({ error: { message: "Invalid coupon code" } });
    }

    const plan = SUBSCRIPTION_PLANS.find(p => p.id === planId);
    if (!plan) {
      return res.status(404).send({ error: { message: "Plan not found" } });
    }

    const originalAmount = plan.price;
    const discountAmount = (originalAmount * coupon.discount) / 100;
    const finalAmount = originalAmount - discountAmount;

    res.send({
      ...coupon,
      originalAmount,
      discountAmount: parseFloat(discountAmount.toFixed(2)),
      finalAmount: parseFloat(finalAmount.toFixed(2))
    });
  } catch (err) {
    console.error("Coupon application error:", err);
    res.status(400).send({
      error: { message: err.message || "Failed to apply coupon" },
    });
  }
});

// Payment intent creation for subscriptions
async function createSubscriptionPaymentIntent(subscriptionData) {
  const baseUrl =
    process.env.HYPERSWITCH_SERVER_URL ||
    "http://localhost:8080";

  const paymentData = {
    amount: subscriptionData.amount,
    currency: subscriptionData.currency,
    confirm: false,
    capture_method: "automatic",
    authentication_type: "no_three_ds",
    customer_id: "subscription_demo_customer",
    email: "hyperswitch_sdk_demo_id@gmail.com",
    description: `Subscription payment for plan: ${subscriptionData.planId}`,
    shipping: {
      address: {
        state: "California",
        city: "San Francisco",
        country: "US",
        line1: "1467 Harrison Street",
        line2: "Harrison Street",
        line3: "Harrison Street",
        zip: "94122",
        first_name: "Demo",
        last_name: "User"
      },
      phone: {
        number: "123456789",
        country_code: "+1"
      }
    },
    billing: {
      address: {
        line1: "1467 Harrison Street",
        line2: "Harrison Street",
        line3: "Harrison Street",
        city: "San Francisco",
        state: "California",
        zip: "94122",
        country: "US",
        first_name: "Demo",
        last_name: "User"
      },
      phone: {
        number: "123456789",
        country_code: "+1"
      }
    },
    setup_future_usage: "off_session",
    metadata: {
      subscription_plan_id: subscriptionData.planId,
      coupon_code: subscriptionData.couponCode || "",
      is_trial: subscriptionData.trial ? "true" : "false",
      trial_days: subscriptionData.trialDays || "0",
      subscription_type: "recurring"
    }
  };

  const profileId = process.env.PROFILE_ID;
  if (profileId) {
    paymentData.profile_id = profileId;
  }

  const apiEndpoint = `${baseUrl}/payments`;
  const headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "api-key": process.env.HYPERSWITCH_SECRET_KEY,
  };

  console.log("Creating payment intent with data:", JSON.stringify(paymentData, null, 2));
  console.log("API endpoint:", apiEndpoint);
  console.log("Headers:", headers);

  try {
    const apiResponse = await fetch(apiEndpoint, {
      method: "POST",
      headers,
      body: JSON.stringify(paymentData),
    });

    const responseText = await apiResponse.text();
    console.log("Raw API response:", responseText);

    let paymentIntent;
    try {
      paymentIntent = JSON.parse(responseText);
    } catch (parseError) {
      console.error("Failed to parse API response:", parseError);
      throw new Error("Invalid response from payment API");
    }

    if (!apiResponse.ok) {
      console.error("Payment Intent API Error:", paymentIntent);
      throw new Error(paymentIntent?.error?.message ?? `API Error: ${apiResponse.status}`);
    }

    if (paymentIntent.error) {
      console.error("Payment Intent Error:", paymentIntent.error);
      throw new Error(paymentIntent?.error?.message ?? "Something went wrong.");
    }

    console.log("Payment intent created successfully:", paymentIntent);
    return paymentIntent;
  } catch (error) {
    console.error("Error creating subscription payment intent:", error);
    throw error;
  }
}

app.listen(PORT, () => {
  console.log(`Subscription Demo Server listening at http://localhost:${PORT}`);
  console.log(`Frontend will be available at http://localhost:9061`);
});
