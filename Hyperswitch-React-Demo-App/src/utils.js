export const getPaymentIntentData = async ({
  baseUrl,
  isCypressTestMode,
  clientSecretQueryParam,
  setError,
}) => {
  try {
    if (isCypressTestMode) {
      return { clientSecret: clientSecretQueryParam };
    }
    let url;

    if (SDK_VERSION === "v1") {
      url = `${baseUrl}/create-payment-intent`;
    } else {
      url = `${baseUrl}/create-intent`;
    }
    const res = await fetch(url);
    if (!res.ok) throw new Error("Failed to fetch payment intent");

    return await res.json();
  } catch (err) {
    console.error("Error fetching payment intent:", err);
    setError("Failed to load payment details. Please try again.");
    return null;
  }
};

export const getQueryParam = (param) =>
  new URLSearchParams(window.location.search).get(param);

export const fetchConfigAndUrls = async (baseUrl) => {
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
};

export const loadHyperScript = ({
  clientUrl,
  publishableKey,
  customBackendUrl,
  profileId,
  isScriptLoaded,
  setIsScriptLoaded,
}) => {
  return new Promise((resolve, reject) => {
    if (isScriptLoaded) return resolve(window.Hyper);

    const script = document.createElement("script");
    script.src = `${clientUrl}/HyperLoader.js`;
    script.async = true;

    script.onload = () => {
      setIsScriptLoaded(true);
      resolve(
        window.Hyper(
          { publishableKey, profileId },
          {
            customBackendUrl,
          }
        )
      );
    };

    script.onerror = () => {
      reject("Failed to load HyperLoader.js");
    };

    document.head.appendChild(script);
  });
};

export const getClientSecretFromUrl = () =>
  new URLSearchParams(window.location.search).get(
    "payment_intent_client_secret"
  );

export const handlePaymentStatus = (status, setMessage, setIsSuccess) => {
  const statusMessages = {
    succeeded: "Payment successful.",
    processing: "Your payment is processing.",
    requires_payment_method:
      "Your payment was not successful. Please try again.",
    requires_capture: "Payment is authorized and requires manual capture.",
    requires_customer_action: "Customer needs to take further action.",
    failed: "Payment failed. Please check your payment method.",
  };

  const messageToSet =
    statusMessages[status] || `Unexpected payment status: ${status}`;
  setMessage(messageToSet);
  setIsSuccess(status === "succeeded");
};

export const paymentElementOptions = {
  displayDefaultSavedPaymentIcon: false,
  wallets: {
    walletReturnUrl: window.location.origin,
    applePay: "auto",
    googlePay: "auto",
    style: {
      theme: "dark",
      type: "default",
      height: 55,
    },
  },
};

export const hyperOptionsV1 = (clientSecret) => {
  return {
    clientSecret,
    appearance: {
      labels: "floating",
    },
  };
};

export const hyperOptionsV2 = (clientSecret, paymentId) => {
  return {
    clientSecret,
    paymentId,
    appearance: {
      labels: "floating",
    },
  };
};
