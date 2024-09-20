@react.component
let make = () => {
  React.useEffect0(() => {
    Utils.messageParentWindow([("driverMounted", true->JSON.Encode.bool)])
    None
  })
  <div />
}
