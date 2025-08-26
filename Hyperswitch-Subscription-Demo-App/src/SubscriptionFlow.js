import React, { useState, useEffect } from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import PlanSelector from "./components/PlanSelector";
import PaymentSection from "./components/PaymentSection";
import { 
  fetchSubscriptionPlans, 
  createSubscriptionSession, 
  applyCoupon,
  loadHyperScript,
  fetchConfigAndUrls 
} from "./utils/subscriptionUtils";

function SubscriptionFlow() {
  const [plans, setPlans] = useState([]);
  const [selectedPlan, setSelectedPlan] = useState(null);
  const [appliedCoupon, setAppliedCoupon] = useState(null);
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");
  const [sessionId, setSessionId] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [finalAmount, setFinalAmount] = useState(0);

  useEffect(() => {
    initializeSubscriptionFlow();
  }, []);

  const initializeSubscriptionFlow = async () => {
    try {
      setLoading(true);
      
      // Fetch configuration and URLs
      console.log("Fetching config and URLs...");
      const { configData, urlsData } = await fetchConfigAndUrls();
      console.log("Config data:", configData);
      console.log("URLs data:", urlsData);
      
      // Fetch available subscription plans
      console.log("Fetching subscription plans...");
      const plansData = await fetchSubscriptionPlans();
      console.log("Plans data:", plansData);
      setPlans(plansData);
      
      // Initialize Hyperswitch SDK
      console.log("Initializing Hyperswitch SDK...");
      const hyper = await loadHyperScript({
        clientUrl: urlsData.clientUrl,
        publishableKey: configData.publishableKey,
        profileId: configData?.profileId,
        customBackendUrl: urlsData.serverUrl,
      });
      
      console.log("Hyperswitch SDK initialized:", hyper);
      setHyperPromise(Promise.resolve(hyper));
      setLoading(false);
    } catch (err) {
      console.error("Initialization error:", err);
      setError("Failed to initialize subscription flow. Please refresh.");
      setLoading(false);
    }
  };

  const handlePlanSelection = async (plan) => {
    try {
      setSelectedPlan(plan);
      setError(null);
      
      // Create subscription session with selected plan
      const sessionData = await createSubscriptionSession({
        planId: plan.id,
        couponCode: appliedCoupon?.code,
      });
      
      setClientSecret(sessionData.clientSecret);
      setSessionId(sessionData.sessionId);
      setFinalAmount(sessionData.amount);
    } catch (err) {
      console.error("Plan selection error:", err);
      setError("Failed to select plan. Please try again.");
    }
  };

  const handleCouponApplication = async (couponCode) => {
    try {
      setError(null);
      
      const couponData = await applyCoupon({
        planId: selectedPlan?.id,
        couponCode,
        sessionId,
      });
      
      setAppliedCoupon(couponData);
      setFinalAmount(couponData.finalAmount);
      
      // Update session with new amount
      const sessionData = await createSubscriptionSession({
        planId: selectedPlan.id,
        couponCode: couponData.code,
      });
      
      setClientSecret(sessionData.clientSecret);
      setFinalAmount(sessionData.amount);
      
      return couponData;
    } catch (err) {
      console.error("Coupon application error:", err);
      throw new Error("Invalid coupon code or coupon has expired");
    }
  };

  const handleCouponRemoval = async () => {
    try {
      setAppliedCoupon(null);
      
      // Recreate session without coupon
      const sessionData = await createSubscriptionSession({
        planId: selectedPlan.id,
        couponCode: null,
      });
      
      setClientSecret(sessionData.clientSecret);
      setFinalAmount(sessionData.amount);
    } catch (err) {
      console.error("Coupon removal error:", err);
      setError("Failed to remove coupon. Please try again.");
    }
  };

  if (loading) {
    return (
      <div className="subscription-container">
        <div className="loading">
          <div>Loading subscription plans...</div>
        </div>
      </div>
    );
  }

  if (error && !plans.length) {
    return (
      <div className="subscription-container">
        <div className="error-message">
          {error}
        </div>
      </div>
    );
  }

  const hyperOptions = {
    clientSecret,
    appearance: {
      labels: "floating",
      theme: "stripe",
      variables: {
        colorPrimary: "#667eea",
        colorBackground: "#ffffff",
        fontFamily: "Inter, sans-serif",
      },
    },
  };

  return (
    <div className="subscription-container">
      <div className="subscription-header">
        <h1>Choose Your Subscription Plan</h1>
        <p>Select a plan and complete your payment to get started</p>
      </div>
      
      <div className="subscription-content">
        <div className="plans-section">
          <h2 className="section-title">Available Plans</h2>
          <PlanSelector
            plans={plans}
            selectedPlan={selectedPlan}
            onPlanSelect={handlePlanSelection}
          />
        </div>
        
        <div className="payment-section">
          <h2 className="section-title">Payment Details</h2>
          {error && <div className="error-message">{error}</div>}
          
          {selectedPlan && clientSecret && hyperPromise ? (
            <HyperElements hyper={hyperPromise} options={hyperOptions}>
              <PaymentSection
                selectedPlan={selectedPlan}
                appliedCoupon={appliedCoupon}
                finalAmount={finalAmount}
                onCouponApply={handleCouponApplication}
                onCouponRemove={handleCouponRemoval}
              />
            </HyperElements>
          ) : (
            <div className="loading">
              {selectedPlan ? "Preparing payment..." : "Please select a plan to continue"}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default SubscriptionFlow;
