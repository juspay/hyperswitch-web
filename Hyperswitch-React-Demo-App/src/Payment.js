/* eslint-disable no-undef */
import { useEffect, useState } from "react";
import React from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");

  const queryParams = new URLSearchParams(window.location.search);
  const isCypressTestMode = queryParams.get("isCypressTestMode");
  const publishableKeyQueryParam = queryParams.get("publishableKey");
  const clientSecretQueryParam = queryParams.get("clientSecret");
  const url = SELF_SERVER_URL === "" ? ENDPOINT : SELF_SERVER_URL;

  const getPaymentData = async () => {
    try {
      const [configResponse, urlsResponse] = await Promise.all([
        fetch(`${url}/config`),
        fetch(`${url}/urls`),
      ]);

      const paymentIntentResponse = isCypressTestMode
        ? { clientSecret: clientSecretQueryParam }
        : await fetch(`${url}/create-payment-intent`).then((res) => res.json());

      if (!configResponse.ok || !urlsResponse.ok) {
        throw new Error("Network response was not ok");
      }

      const paymentDataArray = await Promise.all([
        configResponse.json(),
        urlsResponse.json(),
      ]);

      return [...paymentDataArray, paymentIntentResponse];
    } catch (error) {
      console.error("Error fetching data:", error);
    }
  };

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [configData, urlsData, paymentIntentData] = await getPaymentData(
          url
        );

        const { publishableKey } = configData;
        const { serverUrl, clientUrl } = urlsData;
        const { clientSecret } = paymentIntentData;
        setClientSecret(clientSecret);
        const script = document.createElement("script");
        script.src = `${clientUrl}/HyperLoader.js`;
        document.head.appendChild(script);
        script.onload = () => {
          setHyperPromise(
            new Promise((resolve) => {
              resolve(
                window.Hyper(
                  isCypressTestMode ? publishableKeyQueryParam : publishableKey,
                  {
                    customBackendUrl: serverUrl,
                  }
                )
              );
            })
          );
        };

        script.onerror = () => {
          setHyperPromise(
            new Promise((_, reject) => {
              reject("Script could not be loaded");
            })
          );
        };

        return () => {
          document.head.removeChild(script);
        };
      } catch (error) {
        console.error("Error fetching data:", error);
      }
    };

    fetchData();
  }, []);

  return (
    <div className="mainContainer">
      <div className="heading">
        <h2>Hyperswitch Unified Checkout</h2>
      </div>
      {clientSecret && hyperPromise && (
        <HyperElements
          hyper={hyperPromise}
          options={{
            clientSecret: isCypressTestMode
              ? clientSecretQueryParam
              : clientSecret,
            appearance: {
              // theme: "midnight",
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
