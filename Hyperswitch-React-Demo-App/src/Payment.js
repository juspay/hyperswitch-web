import React, { useEffect, useState } from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";

const getQueryParam = (param) => new URLSearchParams(window.location.search).get(param);

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");
  const [error, setError] = useState(null);
  const [isScriptLoaded, setIsScriptLoaded] = useState(false);

  const isCypressTestMode = getQueryParam("isCypressTestMode") === "true";
  const publishableKeyQueryParam = getQueryParam("publishableKey");
  const clientSecretQueryParam = getQueryParam("clientSecret");

  const baseUrl = SELF_SERVER_URL || ENDPOINT;

  const fetchPaymentData = async () => {
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

      const paymentIntentData = isCypressTestMode
        ? { clientSecret: clientSecretQueryParam }
        : await fetch(`${baseUrl}/create-payment-intent`).then((res) => {
            if (!res.ok) throw new Error("Failed to fetch payment intent");
            return res.json();
          });

      return { configData, urlsData, paymentIntentData };
    } catch (err) {
      console.error("Error fetching payment data:", err);
      setError("Failed to load payment details. Please try again.");
      return {};
    }
  };

  const loadHyperScript = (clientUrl, publishableKey, customBackendUrl) => {
    return new Promise((resolve, reject) => {
      if (isScriptLoaded) return resolve(window.Hyper);

      const script = document.createElement("script");
      script.src = `${clientUrl}/HyperLoader.js`;
      script.async = true;

      script.onload = () => {
        setIsScriptLoaded(true);
        resolve(
          window.Hyper(publishableKey, {
            customBackendUrl,
          })
        );
      };

      script.onerror = () => {
        reject("Failed to load HyperLoader.js");
      };

      document.head.appendChild(script);
    });
  };

  useEffect(() => {
    let isMounted = true;

    const initializePayment = async () => {
      const { configData, urlsData, paymentIntentData } = await fetchPaymentData();

      if (!configData || !urlsData || !paymentIntentData) return;

      const publishableKey = isCypressTestMode
        ? publishableKeyQueryParam
        : configData.publishableKey;

      try {
        const hyper = await loadHyperScript(
          urlsData.clientUrl,
          publishableKey,
          urlsData.serverUrl
        );
        if (isMounted) {
          setClientSecret(paymentIntentData.clientSecret);
          setHyperPromise(Promise.resolve(hyper));
        }
      } catch (err) {
        console.error("Script load error:", err);
        setError("Failed to load payment script. Please refresh.");
      }
    };

    initializePayment();

    return () => {
      isMounted = false;
    };
  }, []);

  return (
    <div className="mainContainer">
      <div className="heading">
        <h2>Hyperswitch Unified Checkout</h2>
      </div>

      {error && <p className="text-red-600">{error}</p>}

      {clientSecret && hyperPromise && (
        <HyperElements
          hyper={hyperPromise}
          options={{
            clientSecret: clientSecret,
            appearance: {
              labels: "floating",
            },
          }}
        >
          <CheckoutForm />
        </HyperElements>
      )}
    </div>
  );
}

export default Payment;
