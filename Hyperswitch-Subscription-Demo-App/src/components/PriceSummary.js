import React from "react";

function PriceSummary({ selectedPlan, appliedCoupon, finalAmount }) {
  if (!selectedPlan) {
    return null;
  }

  const originalAmount = selectedPlan.price;
  const discountAmount = appliedCoupon 
    ? (originalAmount * appliedCoupon.discount) / 100 
    : 0;

  return (
    <div className="price-summary">
      <h3>Order Summary</h3>
      
      <div className="price-row">
        <span>{selectedPlan.name} ({selectedPlan.interval})</span>
        <span>${originalAmount}</span>
      </div>
      
      {appliedCoupon && (
        <div className="price-row discount">
          <span>{appliedCoupon.code} ({appliedCoupon.discount}% off)</span>
          <span>-${discountAmount.toFixed(2)}</span>
        </div>
      )}
      
      {selectedPlan.trial && (
        <div className="price-row">
          <span>Free trial ({selectedPlan.trialDays} days)</span>
          <span>$0.00</span>
        </div>
      )}
      
      <div className="price-row total">
        <span>Total</span>
        <span>${finalAmount}</span>
      </div>
      
      {selectedPlan.trial && (
        <div style={{ fontSize: "0.8rem", color: "#666", marginTop: "10px" }}>
          You will be charged ${finalAmount} after your {selectedPlan.trialDays}-day free trial ends.
        </div>
      )}
    </div>
  );
}

export default PriceSummary;
