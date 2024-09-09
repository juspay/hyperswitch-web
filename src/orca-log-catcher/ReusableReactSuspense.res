@react.component
let make = (~children, ~loaderComponent, ~componentName) => {
  <ErrorBoundary level=ErrorBoundary.PaymentMethod componentName>
    <React.Suspense fallback={loaderComponent}> {children} </React.Suspense>
  </ErrorBoundary>
}
