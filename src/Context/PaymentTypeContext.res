open CardThemeType

type context = {paymentType: mode}

let context = React.createContext({paymentType: Payment})

let provider = React.Context.provider(context)

let usePaymentType = () => {
  let contextValue = React.useContext(context)
  contextValue.paymentType
}
