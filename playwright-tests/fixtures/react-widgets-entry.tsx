import React, { useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { HyperElements, PaymentElement } from "@juspay-tech/react-hyper-js";

function Checkout({ index, allowEarlyConfirm }: { index: number; allowEarlyConfirm: boolean }) {
  const widget = useRef<any>(null);
  const [ready, setReady] = useState(false);
  const [readOnly, setReadOnly] = useState(false);
  const [message, setMessage] = useState("");
  const options = useMemo(
    () => ({
      displaySavedPaymentMethods: false,
      readOnly,
    }),
    [readOnly],
  );
  return (
    <form
      aria-label={`Checkout ${index}`}
      onSubmit={async (event) => {
        event.preventDefault();
        const result = await widget.current.confirmPayment({
          confirmParams: { return_url: location.origin },
          redirect: "if_required",
        });
        setMessage(
          result.error?.message || result.status || "Payment confirmed",
        );
      }}
    >
      <h2>Checkout {index}</h2>
      <label>
        <input
          type="checkbox"
          checked={readOnly}
          onChange={(event) => setReadOnly(event.target.checked)}
        />
        Read only {index}
      </label>
      <PaymentElement
        ref={widget}
        options={options}
        onReady={() => setReady(true)}
      />
      <button disabled={!ready && !allowEarlyConfirm}>
        Pay checkout {index}
      </button>
      <p role="status">{message}</p>
    </form>
  );
}

export function mount(hyper: Promise<unknown>, clientSecret: string, allowEarlyConfirm = false) {
  const app = (
    <React.StrictMode>
      <HyperElements hyper={hyper} options={{ clientSecret }}>
        <Checkout index={1} allowEarlyConfirm={allowEarlyConfirm} />
        <Checkout index={2} allowEarlyConfirm={allowEarlyConfirm} />
      </HyperElements>
    </React.StrictMode>
  );
  const root = document.getElementById("root")!;
  // Merchant root prefixes must remain safe when widget IDs become selectors.
  createRoot(root, { identifierPrefix: "checkout.:" }).render(app);
}
