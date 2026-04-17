import React, { useEffect, useState } from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";
import {
  getQueryParam,
  fetchConfigAndUrls,
  getPaymentIntentData,
  loadHyperScript,
  hyperOptionsV1,
  hyperOptionsV2,
} from "./utils";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");
  const [paymentId, setPaymentId] = useState("");
  const [error, setError] = useState(null);
  const [isScriptLoaded, setIsScriptLoaded] = useState(false);

  const isCypressTestMode = getQueryParam("isCypressTestMode") === "true";
  const publishableKeyQueryParam = getQueryParam("publishableKey");
  const clientSecretQueryParam = getQueryParam("clientSecret");
  const localeQueryParam = getQueryParam("locale");
  const themeQueryParam = getQueryParam("theme");
  const layoutQueryParam = getQueryParam("layout");
  const optionsQueryParam = getQueryParam("options");

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
          profileId: configData?.profileId,
          customBackendUrl: urlsData.serverUrl,
          isScriptLoaded,
          setIsScriptLoaded,
        });

        if (isMounted) {
          setClientSecret(paymentIntentData.clientSecret);
          if (SDK_VERSION === "v2") {
            setPaymentId(paymentIntentData.paymentId);
          }
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

  let selectedOptions;
  if (SDK_VERSION === "v1") {
    selectedOptions = hyperOptionsV1(clientSecret, localeQueryParam, themeQueryParam);
  } else {
    selectedOptions = hyperOptionsV2(clientSecret, paymentId, localeQueryParam, themeQueryParam);
  }

  return (
    <div className="mainContainer">
      <div className="heading">
        <h2>Hyperswitch Unified Checkout</h2>
      </div>

      {error && <p className="text-red-600">{error}</p>}

      {clientSecret && hyperPromise && (
        <HyperElements hyper={hyperPromise} options={selectedOptions}>
          <CheckoutForm layoutQueryParam={layoutQueryParam} optionsQueryParam={optionsQueryParam} />
        </HyperElements>
      )}
    </div>
  );
}

export default Payment;
