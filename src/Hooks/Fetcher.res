@val @scope(("window", "location")) external hostname: string = "hostname"
type match
type pathname = {match: match}
type url = {pathname: pathname}
@new external url: string => url = "URL"

let useFetcher = fileName => {
  let _url = RescriptReactRouter.useUrl()
  let (optionalJson, setJson) = React.useState(() => None)
  React.useEffect1(() => {
    open Promise
    Fetch.fetch(`${hostname}/json/${fileName}.json`)
    ->then(Fetch.Response.json)
    ->thenResolve(json => {
      setJson(_ => Some(json))
    })
    ->ignore

    None
  }, [fileName])

  optionalJson
}
