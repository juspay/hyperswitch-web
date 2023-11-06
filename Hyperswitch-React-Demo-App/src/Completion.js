function Completion(props) {
  return window.location.href.includes("failed") ?
    <h1>Payment failed, Please try again!</h1> :
    <h1>Payment successful, Thank you! 🎉</h1>;
}

export default Completion;
