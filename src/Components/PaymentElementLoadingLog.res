/* PAYMENT_ELEMENT_LOADING. Lives inside each loading branch rather than in an
   effect on a flag, so it reports the shimmer the shopper actually sees — the
   Suspense fallback included. logElementLoading is one-shot, so only the first
   branch to mount emits. */
@react.component
let make = (~reason) => {
  let logger = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  React.useEffect(() => {
    if logger !== LoggerUtils.defaultLoggerConfig {
      LoggerUtils.logElementLoading(~logger, ~reason)
    }
    None
  }, [logger])
  React.null
}
