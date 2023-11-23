import { PaymentElement } from "@juspay-tech/react-hyper-js";
import Cart from "./Cart";
import { useState, useEffect } from "react";
import { useHyper, useElements } from "@juspay-tech/react-hyper-js";
import { useNavigate } from "react-router-dom";
import "./App.css";
import "./index";
import React from "react";
import Completion from "./Completion";

export default function CheckoutForm() {
  const hyper = useHyper();
  const elements = useElements();
  const navigate = useNavigate();
  const [isSuccess, setSucces] = useState(false);

  const [message, setMessage] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);

  function handlePaymentStatus(status) {
    switch (status) {
      case "succeeded":
        setMessage("Payment successful");
        setSucces(true);
        break;
      case "processing":
        setMessage("Your payment is processing.");
        break;
      case "requires_payment_method":
        setMessage("Your payment was not successful, please try again.");
        break;
      case "requires_capture":
        setMessage("Payment processing! Requires manual capture");
        break;
      case "requires_customer_action":
        setMessage("Customer needs to take action to confirm this payment");
        break;
      case "failed":
        setMessage("Payment Failed!");
        break;
      default:
        setMessage(`Something went wrong. (Status: ${status})`);
        break;
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!hyper || !elements) {
      // Hyper.js has not yet loaded.
      // Make sure to disable form submission until Hyper.js has loaded.
      return;
    }

    setIsProcessing(true);

    const { error, status } = await hyper.confirmPayment({
      elements,
      confirmParams: {
        // Make sure to change this to your payment completion page
        return_url: `${window.location.origin}`,
      },
    });

    if (error) {
      setMessage(error.message);
    } else {
      setMessage("Unexpected Error");
    }

    if (status) {
      console.log("-status", status);
      handlePaymentStatus(status);
    }

    setIsProcessing(false);
  };

  useEffect(() => {
    if (!hyper) {
      return;
    }
    const clientSecret = new URLSearchParams(window.location.search).get(
      "payment_intent_client_secret"
    );
    if (!clientSecret) {
      return;
    }
    hyper.retrievePaymentIntent(clientSecret).then(({ paymentIntent }) => {
      console.log("-retrieve called", paymentIntent.status);
      handlePaymentStatus(paymentIntent.status);
    });
  }, [hyper, navigate]);

  const options = {
    wallets: {
      walletReturnUrl: `${window.location.origin}`,
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
    <div class="browser">
      <div class="toolbar">
        <div class="controls">
          <div class="btn close"></div>
          <div class="btn min"></div>
          <div class="btn max"></div>
        </div>
      </div>
      <div class="tabbar">
        <div class="input">
          <div class="info"> &#8505;</div>
          <div> http://localhost:9060</div>
        </div>
      </div>
      <div class="viewport">
        {!isSuccess ? (
          <>
            <Cart />
            <div className="payment-form">
              <form id="payment-form" onSubmit={handleSubmit}>
                <div class="paymentElement">
                  <PaymentElement id="payment-element" options={options} />
                </div>
                <button
                  disabled={isProcessing || !hyper || !elements}
                  id="submit"
                >
                  <span id="button-text">
                    {isProcessing ? "Processing ... " : "Pay now"}
                  </span>
                </button>
                {/* Show any error or success messages */}
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
