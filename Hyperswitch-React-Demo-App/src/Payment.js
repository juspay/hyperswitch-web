import React, { useEffect, useState } from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";
import {
  getQueryParam,
  fetchConfigAndUrls,
  getPaymentIntentData,
  loadHyperScript,
} from "./utils";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");
  const [error, setError] = useState(null);
  const [isScriptLoaded, setIsScriptLoaded] = useState(false);

  const isCypressTestMode = getQueryParam("isCypressTestMode") === "true";
  const publishableKeyQueryParam = getQueryParam("publishableKey");
  const clientSecretQueryParam = getQueryParam("clientSecret");

  const baseUrl = SELF_SERVER_URL || ENDPOINT;

  useEffect(() => {
    let isMounted = true;

    const initializePayment = async () => {
      try {
        const { configData, urlsData } = await fetchConfigAndUrls(baseUrl);

        const publishableKey = isCypressTestMode
          ? publishableKeyQueryParam
          : configData.publishableKey;

        const paymentIntentData = await getPaymentIntentData({
          baseUrl,
          isCypressTestMode,
          clientSecretQueryParam,
          setError,
        });

        if (!paymentIntentData) return;

        const hyper = await loadHyperScript({
          clientUrl: urlsData.clientUrl,
          publishableKey,
          customBackendUrl: urlsData.serverUrl,
          isScriptLoaded,
          setIsScriptLoaded,
        });

        if (isMounted) {
          setClientSecret(paymentIntentData.clientSecret);
          setHyperPromise(Promise.resolve(hyper));
        }
      } catch (err) {
        console.error("Initialization error:", err);
        setError("Failed to load payment. Please refresh.");
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
            clientSecret,
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
