type match
type pathname = {match: match}
type url = {pathname: pathname}
@new external url: string => url = "URL"

let useFetcher = fileName => {
  let _url = RescriptReactRouter.useUrl()
  let (optionalJson, setJson) = React.useState(() => None)
  React.useEffect(() => {
    open Promise
    let jsonUrl = URLModule.makeUrl(`${Window.Location.hostname}/json/${fileName}.json`)
    Fetch.get(jsonUrl.href)
    ->then(Fetch.Response.json)
    ->thenResolve(json => {
      setJson(_ => Some(json))
    })
    ->ignore

    None
  }, [fileName])

  optionalJson
}
