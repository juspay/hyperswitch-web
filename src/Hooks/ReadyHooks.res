// Shimmers use animate-pulse; Suspense fallbacks add loadingMarkerClass as they may render nothing.
let loadingMarkerClass = "SdkLoading"
let loadingSelector = `.animate-pulse, .${loadingMarkerClass}`

type mutationObserver
type mutationObserverInit = {
  childList: bool,
  subtree: bool,
  attributes: bool,
  attributeFilter: array<string>,
}
@new external makeMutationObserver: (unit => unit) => mutationObserver = "MutationObserver"
@send external observe: (mutationObserver, Dom.element, mutationObserverInit) => unit = "observe"
@send external disconnect: mutationObserver => unit = "disconnect"
@send external querySelectorAll: (Dom.element, string) => Dom.nodeList = "querySelectorAll"
@send external closest: (Dom.element, string) => Nullable.t<Dom.element> = "closest"
@get external childElementCount: Dom.element => int = "childElementCount"

let hasPendingPlaceholder = section =>
  section
  ->querySelectorAll(loadingSelector)
  ->Window.nodeListToArray
  ->Array.some(placeholder => placeholder->closest(`[aria-hidden="true"]`)->Nullable.isNullable)

let useIsSectionLoaded = (sectionRef: React.ref<Nullable.t<Dom.element>>, ~isMounted) => {
  let (isLoaded, setIsLoaded) = React.useState(_ => false)
  React.useEffect(() => {
    switch (isMounted, sectionRef.current->Nullable.toOption) {
    | (true, Some(section)) =>
      let update = () =>
        setIsLoaded(_ => section->childElementCount > 0 && !hasPendingPlaceholder(section))
      update()
      let observer = makeMutationObserver(update)
      observer->observe(
        section,
        {childList: true, subtree: true, attributes: true, attributeFilter: ["class", "aria-hidden"]},
      )
      Some(() => observer->disconnect)
    | _ =>
      setIsLoaded(_ => false)
      None
    }
  }, [isMounted])
  isLoaded
}
