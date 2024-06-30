/* eslint-disable no-undef */
import { useEffect, useState } from "react";
import React from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");

  useEffect(() => {
    const fetchData = async () => {
      try {
        const url = SELF_SERVER_URL === "" ? ENDPOINT : SELF_SERVER_URL;

        const [configResponse, urlsResponse, paymentIntentResponse] =
          await Promise.all([
            fetch(`${url}/config`),
            fetch(`${url}/urls`),
            fetch(`${url}/create-payment-intent`),
          ]);

        if (
          !configResponse.ok ||
          !urlsResponse.ok ||
          !paymentIntentResponse.ok
        ) {
          throw new Error("Network response was not ok");
        }

        const [configData, urlsData, paymentIntentData] = await Promise.all([
          configResponse.json(),
          urlsResponse.json(),
          paymentIntentResponse.json(),
        ]);

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
                window.Hyper(publishableKey, {
                  customBackendUrl: serverUrl,
                })
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
