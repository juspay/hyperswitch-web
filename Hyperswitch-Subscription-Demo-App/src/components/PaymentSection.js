import React, { useState, useEffect } from "react";
import { useHyper, useElements, PaymentElement } from "@juspay-tech/react-hyper-js";
import CouponInput from "./CouponInput";
import PriceSummary from "./PriceSummary";

function PaymentSection({ 
  selectedPlan, 
  appliedCoupon, 
  finalAmount, 
  onCouponApply, 
  onCouponRemove 
}) {
  const hyper = useHyper();
  const elements = useElements();
  const [isProcessing, setIsProcessing] = useState(false);
  const [message, setMessage] = useState("");
  const [isSuccess, setIsSuccess] = useState(false);

  useEffect(() => {
    console.log("PaymentSection - hyper:", hyper);
    console.log("PaymentSection - elements:", elements);
    console.log("PaymentSection - selectedPlan:", selectedPlan);
    console.log("PaymentSection - finalAmount:", finalAmount);
  }, [hyper, elements, selectedPlan, finalAmount]);

  const handleSubmit = async (event) => {
    event.preventDefault();

    if (!hyper || !elements) {
      return;
    }

    setIsProcessing(true);
    setMessage("");

    try {
      const { error, paymentIntent } = await hyper.confirmPayment({
        elements,
        confirmParams: {
          return_url: `${window.location.origin}/subscription/success`,
        },
      });

      if (error) {
        setMessage(error.message || "An unexpected error occurred.");
        setIsSuccess(false);
      } else if (paymentIntent && paymentIntent.status === "succeeded") {
        setMessage("Subscription created successfully!");
        setIsSuccess(true);
      } else {
        setMessage("Payment processing...");
        setIsSuccess(false);
      }
    } catch (err) {
      setMessage("An unexpected error occurred.");
      setIsSuccess(false);
    }

    setIsProcessing(false);
  };

  return (
    <div className="payment-section-content">
      <PriceSummary
        selectedPlan={selectedPlan}
        appliedCoupon={appliedCoupon}
        finalAmount={finalAmount}
      />
      
      <CouponInput
        onCouponApply={onCouponApply}
        onCouponRemove={onCouponRemove}
        appliedCoupon={appliedCoupon}
      />

      <form onSubmit={handleSubmit} className="payment-form">
        <div className="payment-element">
          <PaymentElement 
            options={{
              layout: "tabs",
              paymentMethodOrder: ["card", "klarna", "paypal"]
            }}
          />
        </div>

        <button
          type="submit"
          disabled={isProcessing || !hyper || !elements}
          className="submit-button"
        >
          {isProcessing ? "Processing..." : `Subscribe for $${finalAmount}`}
        </button>

        {message && (
          <div className={isSuccess ? "success-message" : "error-message"}>
            {message}
          </div>
        )}
      </form>
    </div>
  );
}

export default PaymentSection;
