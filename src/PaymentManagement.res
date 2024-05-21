open PaymentType
open RecoilAtoms

@react.component
let make = () => {
  let {customerPaymentMethods, displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(
    optionAtom,
  )
  let (savedMethods, setSavedMethods) = React.useState(_ => [])

  React.useEffect(() => {
    switch customerPaymentMethods {
    | LoadedSavedCards(savedPaymentMethods, _) => {
        let defaultPaymentMethod =
          savedPaymentMethods->Array.find(savedCard => savedCard.defaultPaymentMethodSet)

        let savedCardsWithoutDefaultPaymentMethod = savedPaymentMethods->Array.filter(savedCard => {
          !savedCard.defaultPaymentMethodSet
        })

        let finalSavedPaymentMethods = switch defaultPaymentMethod {
        | Some(defaultPaymentMethod) =>
          [defaultPaymentMethod]->Array.concat(savedCardsWithoutDefaultPaymentMethod)
        | None => savedCardsWithoutDefaultPaymentMethod
        }

        setSavedMethods(_ => finalSavedPaymentMethods)
      }
    | LoadingSavedCards
    | NoResult(_) => ()
    }

    None
  }, (customerPaymentMethods, displaySavedPaymentMethods))

  <>
    <SavedPaymentManagement savedMethods />
    <PoweredBy />
  </>
}

let default = make
