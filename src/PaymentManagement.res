open PaymentType
open RecoilAtoms

@react.component
let make = () => {
  let {savedPaymentMethods, displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  let (savedMethods, setSavedMethods) = React.useState(_ => [])

  React.useEffect(() => {
    switch savedPaymentMethods {
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
  }, (savedPaymentMethods, displaySavedPaymentMethods))

  let loading = false

  <>
    <RenderIf condition={!loading}>
      <SavedPaymentManagement savedMethods />
    </RenderIf>
    <RenderIf condition={loading}>
      <div> {"Loading..."->React.string} </div>
    </RenderIf>
    <PoweredBy />
  </>
}

let default = make
