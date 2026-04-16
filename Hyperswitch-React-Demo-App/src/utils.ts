import type { HyperInstance } from "@juspay-tech/hyper-js";
import type React from "react";

interface PaymentStatusMessages {
  [key: string]: string;
}

export const getPaymentIntentData = async ({
  baseUrl,
  isCypressTestMode,
  clientSecretQueryParam,
  setError,
}: {
  baseUrl: string;
  isCypressTestMode: boolean;
  clientSecretQueryParam: string | null;
  setError: React.Dispatch<React.SetStateAction<string | null>>;
}): Promise<{ clientSecret: string; paymentId?: string } | null> => {
  try {
    if (isCypressTestMode) {
      return { clientSecret: clientSecretQueryParam ?? "" };
    }

    const res = await fetch(`${baseUrl}/create-intent`);
    if (!res.ok) throw new Error("Failed to fetch payment intent");

    return await res.json();
  } catch (err) {
    console.error("Error fetching payment intent:", err);
    setError("Failed to load payment details. Please try again.");
    return null;
  }
};

export const getQueryParam = (param: string): string | null =>
  new URLSearchParams(window.location.search).get(param);

export const fetchConfigAndUrls = async (
  baseUrl: string
): Promise<{ configData: any; urlsData: any }> => {
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

// Cached singleton — avoids creating multiple Hyper instances when the merchant
// (or React strict-mode) triggers loadHyperScript more than once.
let hyperInstance: HyperInstance | null = null;

export const loadHyperScript = ({
  clientUrl,
  publishableKey,
  customBackendUrl,
  profileId,
  isScriptLoaded,
  setIsScriptLoaded,
}: {
  clientUrl: string;
  publishableKey: string;
  customBackendUrl?: string;
  profileId?: string;
  isScriptLoaded: boolean;
  setIsScriptLoaded: React.Dispatch<React.SetStateAction<boolean>>;
}): Promise<HyperInstance> => {
  return new Promise((resolve, reject) => {
    if (isScriptLoaded && hyperInstance) return resolve(hyperInstance);

    const script = document.createElement("script");
    script.src = `${clientUrl}/HyperLoader.js`;
    script.async = true;

    script.onload = () => {
      setIsScriptLoaded(true);
      hyperInstance = window.Hyper(
        { publishableKey, profileId },
        { customBackendUrl }
      );
      resolve(hyperInstance);
    };

    script.onerror = () => {
      reject("Failed to load HyperLoader.js");
    };

    document.head.appendChild(script);
  });
};

export const getClientSecretFromUrl = (): string | null =>
  new URLSearchParams(window.location.search).get(
    "payment_intent_client_secret"
  );

export const handlePaymentStatus = (
  status: string,
  setMessage: React.Dispatch<React.SetStateAction<string | null>>,
  setIsSuccess: React.Dispatch<React.SetStateAction<boolean>>
): void => {
  const statusMessages: PaymentStatusMessages = {
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

export const hyperOptionsV1 = (clientSecret: string) => {
  return {
    clientSecret,
    appearance: {
      labels: "floating",
    },
  };
};

export const hyperOptionsV2 = (clientSecret: string, paymentId: string) => {
  return {
    clientSecret,
    paymentId,
    appearance: {
      labels: "floating",
    },
  };
};
