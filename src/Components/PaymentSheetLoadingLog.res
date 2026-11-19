@react.component
let make = (~reason) => {
  let logger = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  React.useEffect(() => {
    LoggerUtils.logSheetLoading(~logger, ~reason)
    None
  }, [])
  React.null
}
