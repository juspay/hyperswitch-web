import { useEffect, useState } from "react";

import { HyperElements } from "@juspay-tech/react-hyper-js";
import { loadHyper } from "@juspay-tech/hyper-js";
import CheckoutForm from "./CheckoutForm";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");

  useEffect(() => {
    fetch("/config").then(async (r) => {
      const { publishableKey } = await r.json();
      setHyperPromise(loadHyper(publishableKey));
    });
  }, []);

  useEffect(() => {
    fetch("/create-payment-intent", {
      method: "POST",
      body: JSON.stringify({}),
    }).then(async (result) => {
      var { clientSecret } = await result.json();
      setClientSecret(clientSecret);
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
