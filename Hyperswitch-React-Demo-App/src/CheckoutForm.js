import React, { useState, useEffect } from "react";
import { PaymentElement, useHyper, useElements } from "@juspay-tech/react-hyper-js";
import { useNavigate } from "react-router-dom";
import Cart from "./Cart";
import Completion from "./Completion";
import "./App.css";

export default function CheckoutForm() {
  const hyper = useHyper();
  const elements = useElements();
  const navigate = useNavigate();

  const [isSuccess, setIsSuccess] = useState(false);
  const [message, setMessage] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const clientSecret = new URLSearchParams(window.location.search).get(
    "payment_intent_client_secret"
  );

  const handlePaymentStatus = (status) => {
    const statusMessages = {
      succeeded: "Payment successful.",
      processing: "Your payment is processing.",
      requires_payment_method: "Your payment was not successful. Please try again.",
      requires_capture: "Payment is authorized and requires manual capture.",
      requires_customer_action: "Customer needs to take further action.",
      failed: "Payment failed. Please check your payment method.",
    };

    const messageToSet = statusMessages[status] || `Unexpected payment status: ${status}`;
    setMessage(messageToSet);
    setIsSuccess(status === "succeeded");
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!hyper || !elements || isProcessing) return;

    setIsProcessing(true);
    setMessage(null);

    try {
      const { error, status } = await hyper.confirmPayment({
        elements,
        confirmParams: {
          return_url: window.location.origin,
        },
      });

      if (error) {
        setMessage(error.message || "An unknown error occurred.");
      }

      if (status) {
        handlePaymentStatus(status);
      }
    } catch (err) {
      setMessage(`Error confirming payment: ${err.message}`);
    } finally {
      setIsProcessing(false);
    }
  };

  useEffect(() => {
    if (!hyper || !clientSecret) return;

    const fetchPaymentIntent = async () => {
      try {
        const { paymentIntent } = await hyper.retrievePaymentIntent(clientSecret);
        if (paymentIntent?.status) {
          handlePaymentStatus(paymentIntent.status);
        }
      } catch (err) {
        console.error("Error retrieving payment intent:", err);
        setMessage("Unable to retrieve payment details.");
      }
    };

    fetchPaymentIntent();
  }, [hyper, clientSecret]);

  const paymentElementOptions = {
    displayDefaultSavedPaymentIcon: false,
    wallets: {
      walletReturnUrl: window.location.origin,
      applePay: "auto",
      googlePay: "auto",
      style: {
        theme: "dark",
        type: "default",
        height: 55,
      },
    },
  };

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
                  <PaymentElement id="payment-element" options={paymentElementOptions} />
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
