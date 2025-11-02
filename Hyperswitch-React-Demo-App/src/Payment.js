import React, { useEffect, useState } from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";
import {
  getQueryParam,
  fetchConfigAndUrls,
  getPaymentIntentData,
  loadHyperScript,
  buildHyperOptions,
  getSubscriptionIntentData,
} from "./utils";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [error, setError] = useState(null);
  const [isScriptLoaded, setIsScriptLoaded] = useState(false);
  const [selectedOptions, setSelectedOptions] = useState(null);
  const isCypressTestMode = getQueryParam("isCypressTestMode") === "true";
  const publishableKeyQueryParam = getQueryParam("publishableKey");
  const clientSecretQueryParam = getQueryParam("clientSecret");
  const baseUrl = SELF_SERVER_URL || ENDPOINT;
  const isSubscriptionsFlow = true;

  useEffect(() => {
    let isMounted = true;

    const initializePayment = async () => {
      try {
        const { configData, urlsData } = await fetchConfigAndUrls(baseUrl);

        const publishableKey = isCypressTestMode
          ? publishableKeyQueryParam
          : configData.publishableKey;

        const paymentIntentData = isSubscriptionsFlow
          ? await getSubscriptionIntentData({
              baseUrl,
              isCypressTestMode,
              clientSecretQueryParam,
              setError,
            })
          : await getPaymentIntentData({
              baseUrl,
              isCypressTestMode,
              clientSecretQueryParam,
              setError,
            });

        if (!paymentIntentData) return;

        const hyper = await loadHyperScript({
          clientUrl: urlsData.clientUrl,
          publishableKey,
          profileId: configData?.profileId,
          customBackendUrl: urlsData.serverUrl,
          isScriptLoaded,
          setIsScriptLoaded,
          isSubscriptionsFlow,
        });

        if (isMounted) {
          setSelectedOptions(buildHyperOptions(paymentIntentData));
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

      {hyperPromise && (
        <HyperElements hyper={hyperPromise} options={selectedOptions}>
          <CheckoutForm />
        </HyperElements>
      )}
    </div>
  );
}

export default Payment;
