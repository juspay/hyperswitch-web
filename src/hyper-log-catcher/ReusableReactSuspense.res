@react.component
let make = (~children, ~loaderComponent, ~componentName) => {
  let {publishableKey} = Jotai.useAtomValue(JotaiAtoms.keys)
  <ErrorBoundary level=ErrorBoundary.PaymentMethod componentName publishableKey>
    <React.Suspense
      fallback={<>
        <ReadyHooks.Pending />
        loaderComponent
      </>}>
      {children}
    </React.Suspense>
  </ErrorBoundary>
}
