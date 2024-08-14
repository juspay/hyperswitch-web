@react.component
let make = (~children, ~loaderComponent, ~componentName) => {
  Console.log2("-- componentName -- ", componentName)

  <ErrorBoundary level=ErrorBoundary.PaymentMethod>
    <React.Suspense fallback={loaderComponent}> {children} </React.Suspense>
  </ErrorBoundary>
}
