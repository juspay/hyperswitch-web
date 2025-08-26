import React from "react";

function PlanSelector({ plans, selectedPlan, onPlanSelect }) {
  return (
    <div className="plan-selector">
      {plans.map((plan) => (
        <div
          key={plan.id}
          className={`plan-card ${selectedPlan?.id === plan.id ? "selected" : ""}`}
          onClick={() => onPlanSelect(plan)}
        >
          {plan.popular && <div className="popular-badge">Most Popular</div>}
          
          <div className="plan-name">
            {plan.name}
            {plan.trial && <span className="trial-badge">Free Trial</span>}
          </div>
          
          <div className="plan-price">
            ${plan.price}
            <span style={{ fontSize: "0.8rem", fontWeight: "normal" }}>
              /{plan.interval}
            </span>
          </div>
          
          <div className="plan-description">{plan.description}</div>
          
          <ul className="plan-features">
            {plan.features.map((feature, index) => (
              <li key={index}>{feature}</li>
            ))}
          </ul>
          
          {plan.trial && (
            <div style={{ marginTop: "10px", fontSize: "0.8rem", color: "#28a745" }}>
              {plan.trialDays} days free trial
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

export default PlanSelector;
