type navigator = {
  userAgent: string,
  language: string,
}
type date = {getTimezoneOffset: (. unit) => float}
type screen = {colorDepth: int, height: int, width: int}

@val external navigator: navigator = "navigator"

@val external screen: screen = "screen"

@new external date: unit => date = "Date"

let checkIsSafari = () => {
  let userAgentString = navigator.userAgent
  let chromeAgent = userAgentString->Js.String2.indexOf("Chrome") > -1
  let safariAgent = userAgentString->Js.String2.indexOf("Safari") > -1
  chromeAgent && safariAgent ? false : safariAgent ? true : false
}

let date = date()
let broswerInfo = () => [
  (
    "browser_info",
    [
      ("user_agent", navigator.userAgent->Js.Json.string),
      (
        "accept_header",
        "text\/html,application\/xhtml+xml,application\/xml;q=0.9,image\/webp,image\/apng,*\/*;q=0.8"->Js.Json.string,
      ),
      ("language", navigator.language->Js.Json.string),
      ("color_depth", screen.colorDepth->Belt.Int.toFloat->Js.Json.number),
      ("screen_height", screen.height->Belt.Int.toFloat->Js.Json.number),
      ("screen_width", screen.width->Belt.Int.toFloat->Js.Json.number),
      ("time_zone", date.getTimezoneOffset(.)->Js.Json.number),
      ("java_enabled", true->Js.Json.boolean),
      ("java_script_enabled", true->Js.Json.boolean),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
