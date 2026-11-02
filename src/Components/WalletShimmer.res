@react.component
let make = () => {
  open PaymentElementShimmer
  // Wallet scripts (e.g. TrustPay) may never finish loading, so the wait is capped.
  <Shimmer classname="opacity-70" pendingTimeoutMs=ReadyHooks.walletDecisionTimeoutMs>
    <div
      className="animate-pulse w-full h-12 rounded bg-slate-200 flex justify-center items-center ">
      <div className="w-24 h-3 rounded bg-white bg-opacity-70 self-center " />
    </div>
  </Shimmer>
}
