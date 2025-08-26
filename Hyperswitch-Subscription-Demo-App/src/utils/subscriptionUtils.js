// Mock data for subscription plans
const MOCK_PLANS = [
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

const baseUrl = "http://localhost:5253";

export const fetchConfigAndUrls = async () => {
  try {
    const [configRes, urlsRes] = await Promise.all([
      fetch(`${baseUrl}/config`),
      fetch(`${baseUrl}/urls`),
    ]);

    if (!configRes.ok || !urlsRes.ok) {
      throw new Error("Failed to fetch config or URL data");
    }

    const configData = await configRes.json();
    const urlsData = await urlsRes.json();

    return { configData, urlsData };
  } catch (error) {
    console.error("Error fetching config:", error);
    // Return mock data for demo purposes
    return {
      configData: {
        publishableKey: "pk_dev_e6641961e1054c6b97532cb4220854ed",
        profileId: "pro_BzTpuJapkdwuzDhEPMWI"
      },
      urlsData: {
        serverUrl: "http://localhost:8080",
        clientUrl: "http://localhost:9050"
      }
    };
  }
};

export const fetchSubscriptionPlans = async () => {
  try {
    // In a real implementation, this would fetch from the backend
    // const response = await fetch(`${baseUrl}/subscription/plans`);
    // return await response.json();
    
    // For demo purposes, return mock data
    return MOCK_PLANS;
  } catch (error) {
    console.error("Error fetching plans:", error);
    return MOCK_PLANS;
  }
};

export const createSubscriptionSession = async ({ planId, couponCode }) => {
  try {
    console.log("Creating subscription session for plan:", planId, "with coupon:", couponCode);
    
    // Call the backend API to create a real payment session
    const response = await fetch(`${baseUrl}/subscription/create-session`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ planId, couponCode })
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error?.message || "Failed to create subscription session");
    }

    const sessionData = await response.json();
    console.log("Subscription session created:", sessionData);
    return sessionData;
  } catch (error) {
    console.error("Error creating subscription session:", error);
    
    // Fallback to mock data if backend fails
    const plan = MOCK_PLANS.find(p => p.id === planId);
    if (!plan) {
      throw new Error("Plan not found");
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

    

    console.log("Using fallback mock data for subscription session");
    return {
      clientSecret: `cs_mock_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      sessionId: `session_${Date.now()}`,
      amount: parseFloat(amount.toFixed(2))
    };
  }
};

export const applyCoupon = async ({ planId, couponCode, sessionId }) => {
  try {
    // In a real implementation, this would validate with the backend
    // const response = await fetch(`${baseUrl}/subscription/apply-coupon`, {
    //   method: "POST",
    //   headers: { "Content-Type": "application/json" },
    //   body: JSON.stringify({ planId, couponCode, sessionId })
    // });
    // return await response.json();

    // For demo purposes, validate against mock coupons
    const coupon = MOCK_COUPONS[couponCode.toUpperCase()];
    if (!coupon) {
      throw new Error("Invalid coupon code");
    }

    const plan = MOCK_PLANS.find(p => p.id === planId);
    if (!plan) {
      throw new Error("Plan not found");
    }

    const originalAmount = plan.price;
    const discountAmount = (originalAmount * coupon.discount) / 100;
    const finalAmount = originalAmount - discountAmount;

    return {
      ...coupon,
      originalAmount,
      discountAmount: parseFloat(discountAmount.toFixed(2)),
      finalAmount: parseFloat(finalAmount.toFixed(2))
    };
  } catch (error) {
    console.error("Error applying coupon:", error);
    throw error;
  }
};

export const loadHyperScript = ({ 
  clientUrl, 
  publishableKey, 
  customBackendUrl, 
  profileId 
}) => {
  return new Promise((resolve, reject) => {
    // Check if script is already loaded
    if (window.Hyper) {
      console.log("Hyper SDK already loaded, initializing...");
      try {
        const hyperInstance = window.Hyper(
          { publishableKey, profileId },
          { customBackendUrl }
        );
        return resolve(hyperInstance);
      } catch (error) {
        console.error("Error initializing Hyper SDK:", error);
        return reject(error);
      }
    }

    console.log("Loading Hyper SDK from:", `${clientUrl}/HyperLoader.js`);
    const script = document.createElement("script");
    script.src = `${clientUrl}/HyperLoader.js`;
    script.async = true;

    script.onload = () => {
      console.log("Hyper SDK loaded successfully");
      // Wait a bit for the SDK to initialize
      setTimeout(() => {
        if (window.Hyper) {
          try {
            const hyperInstance = window.Hyper(
              { publishableKey, profileId },
              { customBackendUrl }
            );
            console.log("Hyper SDK initialized successfully");
            resolve(hyperInstance);
          } catch (error) {
            console.error("Error initializing Hyper SDK:", error);
            reject(error);
          }
        } else {
          reject(new Error("Hyper SDK not available after loading"));
        }
      }, 100);
    };

    script.onerror = (error) => {
      console.error("Failed to load HyperLoader.js:", error);
      reject(new Error("Failed to load HyperLoader.js"));
    };

    document.head.appendChild(script);
  });
};

export const getQueryParam = (param) =>
  new URLSearchParams(window.location.search).get(param);

export const handlePaymentStatus = (status, setMessage, setIsSuccess) => {
  const statusMessages = {
    succeeded: "Subscription created successfully!",
    processing: "Your payment is processing.",
    requires_payment_method: "Your payment was not successful. Please try again.",
    requires_capture: "Payment is authorized and requires manual capture.",
    requires_customer_action: "Customer needs to take further action.",
    failed: "Payment failed. Please check your payment method.",
  };

  const messageToSet = statusMessages[status] || `Unexpected payment status: ${status}`;
  setMessage(messageToSet);
  setIsSuccess(status === "succeeded");
};
