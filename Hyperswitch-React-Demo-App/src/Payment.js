import { useEffect, useState } from "react";
import React from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");

  useEffect(() => {
    Promise.all([
      fetch(`${endPoint}/config`),
      fetch(`${endPoint}/urls`),
      fetch(`${endPoint}/create-payment-intent`),
    ])
      .then((responses) => {
        return Promise.all(responses.map((response) => response.json()));
      })
      .then((dataArray) => {
        const { publishableKey } = dataArray[0];
        const { serverUrl, clientUrl } = dataArray[1];
        const { clientSecret } = dataArray[2];
        setClientSecret(clientSecret);
        const script = document.createElement("script");
        script.src = `${clientUrl}/HyperLoader.js`;
        document.head.appendChild(script);
        script.onload = () => {
          setHyperPromise(
            new Promise((resolve, _) => {
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
      });
  }, []);

  return (
    <div className="mainConatiner">
      <div className="heading">
        <h2>Hyperswitch Unified Checkout</h2>
      </div>
      {clientSecret && hyperPromise && (
        <HyperElements hyper={hyperPromise} options={{ clientSecret }}>
          <CheckoutForm />
        </HyperElements>
      )}
    </div>
  );
}

export default Payment;
