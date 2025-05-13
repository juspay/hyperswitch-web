import React from "react";
import "./index.css";
import "./App.css";
import success from "../public/assets/Successsuccess.svg";

function Completion() {
  return (
    <section className="ConfirmContainer">
      <div className="ConfirmImage">
        <img src={success} alt="Success" width="150" height="110" />
      </div>

      <h2 className="ConfirmText">Thanks for your order!</h2>

      <p className="ConfirmDes">
        Yayyy! You successfully made a payment with Hyperswitch. If it’s a real
        store, your items would have been on their way.
      </p>

      <div>
        <a className="returnLink" href="/" role="link">
          Try Hyperswitch Playground again
        </a>
      </div>
    </section>
  );
}

export default Completion;
