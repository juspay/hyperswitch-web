import React, { useState, useEffect } from "react";
import {
  PaymentElement,
  useHyper,
  useWidgets,
} from "@juspay-tech/react-hyper-js";
import Cart from "./Cart";
import Completion from "./Completion";
import "./App.css";

// Utility functions to help with payment flow
import {
  getClientSecretFromUrl,
  handlePaymentStatus,
  paymentElementOptions,
} from "./utils";

export default function CheckoutForm({ subscriptionId, subscriptionSecret }) {
  const hyper = useHyper();
  const elements = useWidgets();

  const [isSuccess, setIsSuccess] = useState(false);
  const [message, setMessage] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const clientSecret = getClientSecretFromUrl();

  // Handle form submission
  const handleSubmit = async (e) => {
    e.preventDefault();

    // Prevent submission if Hyper isn't ready or already processing
    if (!hyper || !elements || isProcessing) return;

    setIsProcessing(true);
    setMessage(null);

    try {
      // Confirm the payment using Hyper.js SDK
      // const { error, status } = await hyper.confirmPayment({
      //   elements,
      //   confirmParams: {
      //     return_url: window.location.origin,
      //   },
      // });

      const confirmSubscriptionResult = await HyperMethod.confirmSubscription({
        subscription_id: subscriptionId,
        subscription_secret: subscriptionSecret,
        confirmParams: {
          return_url: window.location.origin,
        },
      });

      const { error, status } = confirmSubscriptionResult;

      if (error) {
        setMessage(error.message || "An unknown error occurred.");
      }

      // Handle status returned by Hyper.js (e.g., succeeded, processing, failed)
      if (status) {
        handlePaymentStatus(status, setMessage, setIsSuccess);
      }
    } catch (err) {
      setMessage(`Error confirming payment: ${err.message}`);
    } finally {
      setIsProcessing(false);
    }
  };

  // On mount or when `hyper` and `clientSecret` are ready, retrieve the payment intent
  useEffect(() => {
    if (!hyper || !clientSecret) return;

    const fetchPaymentIntent = async () => {
      try {
        const { paymentIntent } = await hyper.retrievePaymentIntent(
          clientSecret
        );

        // Update UI based on the payment status
        if (paymentIntent?.status) {
          handlePaymentStatus(paymentIntent.status, setMessage, setIsSuccess);
        }
      } catch (err) {
        console.error("Error retrieving payment intent:", err);
        setMessage("Unable to retrieve payment details.");
      }
    };

    fetchPaymentIntent();
  }, [hyper, clientSecret]);

  return (
    <div className="browser">
      <div className="toolbar">
        <div className="controls">
          <div className="btn close" />
          <div className="btn min" />
          <div className="btn max" />
        </div>
      </div>
      <div className="tabbar">
        <div className="input">
          <div className="info"> &#8505;</div>
          <div> http://localhost:9060</div>
        </div>
      </div>
      <div className="viewport">
        {!isSuccess ? (
          <>
            <Cart />
            <div className="payment-form">
              <form id="payment-form" onSubmit={handleSubmit}>
                <div className="paymentElement">
                  <PaymentElement
                    id="payment-element"
                    options={paymentElementOptions}
                  />
                </div>
                <button
                  disabled={isProcessing || !hyper || !elements}
                  id="submit"
                >
                  <span id="button-text">
                    {isProcessing ? "Processing..." : "Pay now"}
                  </span>
                </button>
                {message && <div id="payment-message">{message}</div>}
              </form>
            </div>
          </>
        ) : (
          <Completion />
        )}
      </div>
    </div>
  );
}
