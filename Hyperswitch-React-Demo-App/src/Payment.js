import React, { useEffect, useState } from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";
import {
  getQueryParam,
  fetchConfigAndUrls,
  getPaymentIntentData,
  getSubscriptionIntentData,
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
  const [subscriptionId, setSubscriptionId] = useState("");
  const [subscriptionSecret, setSubscriptionSecret] = useState("");

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

        // const paymentIntentData = await getPaymentIntentData({
        //   baseUrl,
        //   isCypressTestMode,
        //   clientSecretQueryParam,
        //   setError,
        // });

        //dummy
        const subscriptionIntentData = {
          clientSecret: "pay_EXIeTndU9RaHe9mHOIPb_secret_o26N3HtNKjg9ew80ZFsj",
          subscriptionId: "sub_7wqn0zxOqbbocjM9Qz3h",
          subscriptionSecret:
            "sub_7wqn0zxOqbbocjM9Qz3h_secret_lyHur4RfiaFRYCHV3Xs0",
        };

        // const subscriptionIntentData = await getSubscriptionIntentData({
        //   baseUrl,
        //   isCypressTestMode,
        //   clientSecretQueryParam,
        //   setError,
        // });

        setSubscriptionId(subscriptionIntentData?.subscriptionId);
        setSubscriptionSecret(subscriptionIntentData?.subscriptionSecret);

        if (!subscriptionIntentData) return;

        const hyper = await loadHyperScript({
          clientUrl: urlsData.clientUrl,
          publishableKey,
          profileId: configData?.profileId,
          customBackendUrl: urlsData.serverUrl,
          isScriptLoaded,
          setIsScriptLoaded,
        });

        if (isMounted) {
          setClientSecret(subscriptionIntentData?.clientSecret);
          if (SDK_VERSION === "v2") {
            setPaymentId(subscriptionIntentData?.paymentId);
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
    selectedOptions = hyperOptionsV1(clientSecret);
  } else {
    selectedOptions = hyperOptionsV2(clientSecret, paymentId);
  }

  return (
    <div className="mainContainer">
      <div className="heading">
        <h2>Hyperswitch Unified Checkout</h2>
      </div>

      {error && <p className="text-red-600">{error}</p>}

      {clientSecret && hyperPromise && (
        <HyperElements hyper={hyperPromise} options={selectedOptions}>
          <CheckoutForm
            subscriptionId={subscriptionId}
            subscriptionSecret={subscriptionSecret}
          />
        </HyperElements>
      )}
    </div>
  );
}

export default Payment;
