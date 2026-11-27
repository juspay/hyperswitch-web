type match
type pathname = {match: match}
type searchParams = {set: (string, string) => unit, get: string => Nullable.t<string>}
@new external makeSearchParams: string => searchParams = "URLSearchParams"
type url = {searchParams: searchParams, href: string, pathname: pathname, origin: string}
@new external makeUrl: string => url = "URL"
