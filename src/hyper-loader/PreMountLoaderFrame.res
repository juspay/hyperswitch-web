let make = (~selectorString, ~queryParams, ~title=?) => {
  let url = URLModule.makeUrl(`${ApiEndpoint.sdkDomainUrl}/index.html`)
  queryParams->Array.forEach(((key, value)) => url.searchParams.set(key, value))

  let wrapper = Window.createElement("div")
  wrapper->Window.setAttribute("id", `orca-element-${selectorString}`)
  wrapper->Window.setAttribute("style", "height: 0px; width: 0px; display: none;")
  wrapper->Window.setAttribute("class", "preMountLoader")

  let fullscreenSlot = Window.createElement("div")
  fullscreenSlot->Window.setAttribute("id", `orca-fullscreen-iframeRef-${selectorString}`)
  wrapper->Window.appendChildElement(fullscreenSlot)

  let iframe = Window.createElement("iframe")
  let iframeId = `orca-payment-element-iframeRef-${selectorString}`
  iframe->Window.setAttribute("id", iframeId)
  iframe->Window.setAttribute("name", "orca-payment")
  title->Option.forEach(value => iframe->Window.setAttribute("title", value))
  iframe->Window.setAttribute("src", url.href)
  iframe->Window.setAttribute("allow", "*")
  iframe->Window.setAttribute("style", "outline: none;")
  wrapper->Window.appendChildElement(iframe)

  let container = Window.createElement("div")
  container->Window.appendChildElement(wrapper)
  Window.body->Window.appendChild(container)
  iframe->Nullable.make
}
