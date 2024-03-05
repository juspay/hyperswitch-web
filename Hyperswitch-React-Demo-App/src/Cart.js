import React from "react";
import logo from "../public/assets/hyperswitchLogo.svg";
import shirt from "../public/assets/shirt.png";
import cap from "../public/assets/cap.png";
function Cart() {
  return (
    <>
      <div class="cart">
        <div className="titleContainer">
          <div class="title">
            {" "}
            <img className="logoImg" width="28px" src={logo} alt="" />{" "}
            Hyperswitch Playground App
          </div>
          <div class="testMode">Test Mode</div>
        </div>
        <div className="ordersummary">Order Summary(2) </div>
        <div className="items">
          <div className="Item">
            <div className="ItemContainer">
              <div className="itemImg">
                <img src={shirt} alt="" />
              </div>
              <div className="itemDetails">
                <div className="name">HS Tshirt</div>
                <div className="props">
                  Size: <span className="value">37 &nbsp;&nbsp;&nbsp;</span>
                  Qty:<span className="value">1 </span>
                </div>
                <div className="props">
                  Color: <span className="value">Black</span>
                </div>
              </div>
            </div>
            <div> 100.00</div>
          </div>
          <div className="Item">
            <div className="ItemContainer">
              <div className="itemImg">
                <img src={cap} alt="" />
              </div>
              <div className="itemDetails">
                <div className="name">HS Cap</div>
                <div className="props">
                  Size: <span className="value">2 &nbsp;&nbsp;&nbsp;</span>
                  Qty:<span className="value">1 </span>
                </div>
                <div className="props">
                  Color: <span className="value">Black</span>
                </div>
              </div>
            </div>
            <div> 100.00</div>
          </div>
          <div className="ItemTotal">
            <div className="total">Total Amount</div>
            <div> 200.00</div>
          </div>
        </div>
      </div>
    </>
  );
}

export default Cart;
