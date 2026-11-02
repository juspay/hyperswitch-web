// False while the payment methods section is mounted hidden, so it neither confirms nor emits events.
let context = React.createContext(true)

let provider = React.Context.provider(context)

let useIsActive = () => React.useContext(context)
