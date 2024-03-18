type navigator = {
  userAgent: string,
  language: string,
}
type date = {getTimezoneOffset: unit => float}
type screen = {colorDepth: int, height: int, width: int}

@val external navigator: navigator = "navigator"

@val external screen: screen = "screen"

@new external date: unit => date = "Date"

let checkIsSafari = () => {
  let userAgentString = navigator.userAgent
  let chromeAgent = userAgentString->String.indexOf("Chrome") > -1
  let safariAgent = userAgentString->String.indexOf("Safari") > -1
  chromeAgent && safariAgent ? false : safariAgent ? true : false
}

let date = date()
let broswerInfo = () => [
  (
    "browser_info",
    [
      ("user_agent", navigator.userAgent->JSON.Encode.string),
      (
        "accept_header",
        "text\/html,application\/xhtml+xml,application\/xml;q=0.9,image\/webp,image\/apng,*\/*;q=0.8"->JSON.Encode.string,
      ),
      ("language", navigator.language->JSON.Encode.string),
      ("color_depth", screen.colorDepth->Belt.Int.toFloat->JSON.Encode.float),
      ("screen_height", screen.height->Belt.Int.toFloat->JSON.Encode.float),
      ("screen_width", screen.width->Belt.Int.toFloat->JSON.Encode.float),
      ("time_zone", date.getTimezoneOffset()->JSON.Encode.float),
      ("java_enabled", true->JSON.Encode.bool),
      ("java_script_enabled", true->JSON.Encode.bool),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]
