import React, { useState } from "react";

function CouponInput({ onCouponApply, onCouponRemove, appliedCoupon }) {
  const [couponCode, setCouponCode] = useState("");
  const [isApplying, setIsApplying] = useState(false);
  const [error, setError] = useState("");

  const handleApplyCoupon = async () => {
    if (!couponCode.trim()) {
      setError("Please enter a coupon code");
      return;
    }

    setIsApplying(true);
    setError("");

    try {
      await onCouponApply(couponCode.trim());
      setCouponCode("");
    } catch (err) {
      setError(err.message || "Invalid coupon code");
    }

    setIsApplying(false);
  };

  const handleRemoveCoupon = () => {
    onCouponRemove();
    setError("");
  };

  return (
    <div className="coupon-section">
      <h3>Promo Code</h3>
      
      {appliedCoupon ? (
        <div className="coupon-applied">
          <span>
            {appliedCoupon.code} - {appliedCoupon.discount}% off
          </span>
          <button
            type="button"
            onClick={handleRemoveCoupon}
            className="remove-coupon"
          >
            ×
          </button>
        </div>
      ) : (
        <div className="coupon-input">
          <input
            type="text"
            placeholder="Enter coupon code"
            value={couponCode}
            onChange={(e) => setCouponCode(e.target.value)}
            onKeyPress={(e) => e.key === "Enter" && handleApplyCoupon()}
          />
          <button
            type="button"
            onClick={handleApplyCoupon}
            disabled={isApplying || !couponCode.trim()}
          >
            {isApplying ? "Applying..." : "Apply"}
          </button>
        </div>
      )}
      
      {error && <div className="error-message">{error}</div>}
    </div>
  );
}

export default CouponInput;
