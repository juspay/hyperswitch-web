import React from "react";
import logo from "../public/assets/hyperswitchLogo.svg";
import shirt from "../public/assets/shirt.png";
import cap from "../public/assets/cap.png";

const cartItems = [
  {
    id: 1,
    name: "HS Tshirt",
    price: 100,
    image: shirt,
    size: "37",
    qty: 1,
    color: "Black",
  },
  {
    id: 2,
    name: "HS Cap",
    price: 100,
    image: cap,
    size: "2",
    qty: 1,
    color: "Black",
  },
];

function Cart() {
  const total = cartItems.reduce((sum, item) => sum + item.price * item.qty, 0);

  return (
    <section className="cart">
      <header className="titleContainer">
        <div className="title">
          <img className="logoImg" width="28" src={logo} alt="Hyperswitch logo" />
          Hyperswitch Playground App
        </div>
        <div className="testMode">Test Mode</div>
      </header>

      <h2 className="ordersummary">Order Summary ({cartItems.length})</h2>

      <div className="items">
        {cartItems.map(({ id, name, price, image, size, qty, color }) => (
          <div className="Item" key={id}>
            <div className="ItemContainer">
              <div className="itemImg">
                <img src={image} alt={name} />
              </div>
              <div className="itemDetails">
                <div className="name">{name}</div>
                <div className="props">
                  Size: <span className="value">{size}&nbsp;&nbsp;&nbsp;</span>
                  Qty: <span className="value">{qty}</span>
                </div>
                <div className="props">
                  Color: <span className="value">{color}</span>
                </div>
              </div>
            </div>
            <div className="itemPrice">₹{price.toFixed(2)}</div>
          </div>
        ))}

        <div className="ItemTotal">
          <div className="total">Total Amount</div>
          <div className="totalPrice">₹{total.toFixed(2)}</div>
        </div>
      </div>
    </section>
  );
}

export default Cart;
