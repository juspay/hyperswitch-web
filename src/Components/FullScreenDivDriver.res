@react.component
let make = () => {
  React.useEffect(() => {
    Utils.handlePostMessage([("driverMounted", true->JSON.Encode.bool)])
    None
  }, [])
  <div />
}
