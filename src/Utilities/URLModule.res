type match
type pathname = {match: match}
type searchParams = {set: (string, string) => unit}
type url = {searchParams: searchParams, href: string, pathname: pathname}
@new external makeUrl: string => url = "URL"
