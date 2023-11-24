import React from "react";
import "./index.css";
import "./App.css";
import success from "../public/assets/Successsuccess.svg";

function Completion(props) {
  return (
    <>
      <div className="ConfirmContainer">
        <div>
          <img src={success} width="150px" height="110px" />
        </div>
        <div className="ConfirmText">Thanks for your order!</div>
        <div className="ConfirmDes">
          Yayyy! You successfully made a payment with Hyperswitch. If its a real
          store, your items would have been on their way.
        </div>
        <div>
          <a className="returnLink" href="/">
            Try hyperswitch Playground again
          </a>
        </div>
      </div>
    </>
  );
}

export default Completion;
