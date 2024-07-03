open PaymentType
open RecoilAtoms

@react.component
let make = () => {
  let {savedPaymentMethods, displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  let (savedMethods, setSavedMethods) = React.useState(_ => [])
  let (isLoading, setIsLoading) = React.useState(_ => false)

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
        setIsLoading(_ => false)
      }
    | LoadingSavedCards => setIsLoading(_ => true)
    | NoResult(_) => setIsLoading(_ => false)
    }

    None
  }, (savedPaymentMethods, displaySavedPaymentMethods))

  <>
    <RenderIf condition={!isLoading}>
      <SavedPaymentManagement savedMethods setSavedMethods />
    </RenderIf>
    <RenderIf condition={isLoading}>
      <PaymentElementShimmer.SavedPaymentShimmer />
    </RenderIf>
    <PoweredBy />
  </>
}

let default = make
