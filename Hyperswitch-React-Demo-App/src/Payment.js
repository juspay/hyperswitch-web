import { useEffect, useState } from "react";
import React from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import { loadHyper } from "@juspay-tech/hyper-js";
import CheckoutForm from "./CheckoutForm";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");

  useEffect(() => {
    Promise.all([
      fetch(`${endPoint}/config`),
      fetch(`${endPoint}/server`),
      fetch(`${endPoint}/create-payment-intent`),
    ])
      .then((responses) => {
        return Promise.all(responses.map((response) => response.json()));
      })
      .then((dataArray) => {
        const { publishableKey } = dataArray[0];
        const { serverUrl } = dataArray[1];
        const { clientSecret } = dataArray[2];
        setHyperPromise(
          loadHyper(publishableKey, { customBackendUrl: serverUrl })
        );
        setClientSecret(clientSecret);
      })
      .catch((error) => {
        console.error("Error:", error);
      });
  }, []);

  return (
    <>
      <h2>Hyperswitch Unified Checkout</h2>
      {clientSecret && hyperPromise && (
        <HyperElements hyper={hyperPromise} options={{ clientSecret }}>
          <CheckoutForm />
        </HyperElements>
      )}
    </>
  );
}

export default Payment;
