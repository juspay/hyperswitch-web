type loadMode = Load | Reuse
type loadResult = Loaded | Reused

type adapter = {
  isLoaded: string => bool,
  load: (string, unit => unit, unit => unit) => unit,
}

type resource =
  | Script
  | Stylesheet
  | Image
  | Fetch
  | Preload(string)
  | Custom(string, adapter)

@val @scope(("document", "head"))
external appendToHead: Dom.element => unit = "appendChild"

@val @scope("Array") external arrayFrom: array<'value> => array<'value> = "from"

let makeAdapter = (~isLoaded, ~load) => {isLoaded, load}

let resourceType = resource =>
  switch resource {
  | Script => "SCRIPT"
  | Stylesheet => "STYLESHEET"
  | Image => "IMAGE"
  | Fetch => "FETCH"
  | Preload(asType) => asType
  | Custom(resourceType, _) => resourceType
  }

let resourceIdentity = url => url->String.replaceRegExp(/[?#].*$/, "")

let elementWithUrlExists = (~selector, ~attribute, ~url, ~ignoreQuery=false) => {
  let expectedUrl = ignoreQuery ? url->resourceIdentity : url
  Window.querySelectorAll(selector)
  ->arrayFrom
  ->Array.some(element =>
    element
    ->Window.getAttribute(attribute)
    ->Nullable.toOption
    ->Option.map(elementUrl =>
      (ignoreQuery ? elementUrl->resourceIdentity : elementUrl) === expectedUrl
    )
    ->Option.getOr(false)
  )
}

let scriptAdapter = makeAdapter(
  ~isLoaded=url =>
    elementWithUrlExists(~selector="script[src]", ~attribute="src", ~url, ~ignoreQuery=true),
  ~load=(url, onLoad, onError) => {
    let script = Window.createElement("script")
    script->Window.setAttribute("type", "text/javascript")
    script->Window.setAttribute("src", url)
    script->Window.elementOnload(onLoad)
    script->Window.elementOnerror(_ => onError())
    Window.body->Window.appendChild(script)
  },
)

let stylesheetAdapter = makeAdapter(
  ~isLoaded=url =>
    elementWithUrlExists(~selector="link[rel=stylesheet][href]", ~attribute="href", ~url),
  ~load=(url, onLoad, onError) => {
    let stylesheet = Window.createElement("link")
    stylesheet->Window.setAttribute("rel", "stylesheet")
    stylesheet->Window.setAttribute("href", url)
    stylesheet->Window.elementOnload(onLoad)
    stylesheet->Window.elementOnerror(_ => onError())
    stylesheet->appendToHead
  },
)

let preloadAdapter = asType =>
  makeAdapter(
    ~isLoaded=url =>
      Window.querySelectorAll("link[rel=preload][href]")
      ->arrayFrom
      ->Array.some(element => {
        let hrefMatches =
          element
          ->Window.getAttribute("href")
          ->Nullable.toOption
          ->Option.map(href => href === url)
          ->Option.getOr(false)
        let typeMatches =
          element
          ->Window.getAttribute("as")
          ->Nullable.toOption
          ->Option.map(elementAsType => elementAsType === asType)
          ->Option.getOr(false)
        hrefMatches && typeMatches
      }),
    ~load=(url, onLoad, onError) => {
      let preload = Window.createElement("link")
      preload->Window.setAttribute("rel", "preload")
      preload->Window.setAttribute("as", asType)
      preload->Window.setAttribute("href", url)
      preload->Window.elementOnload(onLoad)
      preload->Window.elementOnerror(_ => onError())
      preload->appendToHead
    },
  )

let fetchedResources: Dict.t<bool> = Dict.make()

let fetchAdapter = makeAdapter(
  ~isLoaded=url => fetchedResources->Dict.get(url)->Option.getOr(false),
  ~load=(url, onLoad, onError) => {
    open Promise
    Fetch.fetch(url, {method: #GET})
    ->then(response => resolve(Some(response)))
    ->catch(_ => resolve(None))
    ->then(response => {
      switch response {
      | Some(response) if response->Fetch.Response.ok => {
          fetchedResources->Dict.set(url, true)
          onLoad()
        }
      | _ => onError()
      }
      resolve()
    })
    ->ignore
  },
)

let adapter = resource =>
  switch resource {
  | Script => scriptAdapter
  | Stylesheet => stylesheetAdapter
  | Image => preloadAdapter("image")
  | Fetch => fetchAdapter
  | Preload(asType) => preloadAdapter(asType)
  | Custom(_, adapter) => adapter
  }

let load = (~url, ~resource, ~onStart, ~onLoad, ~onError) => {
  let adapter = resource->adapter
  if adapter.isLoaded(url) {
    onStart(Reuse)
    onLoad(Reused)
  } else {
    onStart(Load)
    adapter.load(url, () => onLoad(Loaded), onError)
  }
}
