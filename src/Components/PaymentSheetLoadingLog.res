@react.component
let make = (~reason) => {
  let logger = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  React.useEffect(() => {
    if logger !== LoggerUtils.defaultLoggerConfig {
      LoggerUtils.logSheetLoading(~logger, ~reason)
    }
    None
  }, [logger])
  React.null
}
