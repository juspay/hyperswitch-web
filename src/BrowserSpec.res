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
  !chromeAgent && safariAgent
}

let getPlatformFromUserAgent = () => {
  let userAgentString = navigator.userAgent

  if userAgentString->String.includes("Win") {
    "Windows"
  } else if userAgentString->String.includes("Mac") {
    "MacOS"
  } else if userAgentString->String.includes("X11") || userAgentString->String.includes("Linux") {
    "Linux"
  } else if userAgentString->String.includes("Android") {
    "Android"
  } else if userAgentString->String.includes("iPhone") || userAgentString->String.includes("iPad") {
    "iOS"
  } else {
    "Unknown"
  }
}

let matchAndExtract = (regex, groupIndex, userAgentString) => {
  switch userAgentString->String.match(regex) {
  | Some(match) => match->Array.get(groupIndex)->Option.getOr("")
  | None => ""
  }
}

let getBrowserInfoFromUserAgent = () => {
  let userAgentString = navigator.userAgent

  if (
    %re("/Chrome\/(\d+\.\d+\.\d+\.\d+)/")->RegExp.test(userAgentString) &&
      !(%re("/Edg\/|OPR\//")->RegExp.test(userAgentString))
  ) {
    ("Chrome", matchAndExtract(%re("/Chrome\/(\d+\.\d+\.\d+\.\d+)/"), 1, userAgentString))
  } else if (
    %re("/Safari\/(\d+\.\d+\.\d+)/")->RegExp.test(userAgentString) &&
      !(%re("/Chrome/")->RegExp.test(userAgentString))
  ) {
    ("Safari", matchAndExtract(%re("/Version\/(\d+\.\d+)/"), 1, userAgentString))
  } else if %re("/Firefox\/(\d+\.\d+)/")->RegExp.test(userAgentString) {
    ("Firefox", matchAndExtract(%re("/Firefox\/(\d+\.\d+)/"), 1, userAgentString))
  } else if %re("/Edg\/(\d+\.\d+\.\d+\.\d+)/")->RegExp.test(userAgentString) {
    ("Edge", matchAndExtract(%re("/Edg\/(\d+\.\d+\.\d+\.\d+)/"), 1, userAgentString))
  } else if %re("/OPR\/(\d+\.\d+\.\d+\.\d+)/")->RegExp.test(userAgentString) {
    ("Opera", matchAndExtract(%re("/OPR\/(\d+\.\d+\.\d+\.\d+)/"), 1, userAgentString))
  } else if %re("/MSIE (\d+\.\d+);/")->RegExp.test(userAgentString) {
    ("Internet Explorer", matchAndExtract(%re("/MSIE (\d+\.\d+);/"), 1, userAgentString))
  } else if %re("/Trident\/.*rv:(\d+\.\d+)/")->RegExp.test(userAgentString) {
    ("Internet Explorer 11", matchAndExtract(%re("/Trident\/.*rv:(\d+\.\d+)/"), 1, userAgentString))
  } else {
    ("Unknown Browser", "Unknown Version")
  }
}

let date = date()
let broswerInfo = () => {
  let (browserName, browserVersion) = getBrowserInfoFromUserAgent()
  let colorDepth =
    [1, 4, 8, 15, 16, 24, 32, 48]->Array.includes(screen.colorDepth) ? screen.colorDepth : 24
  [
    (
      "browser_info",
      [
        ("user_agent", navigator.userAgent->JSON.Encode.string),
        (
          "accept_header",
          "text\/html,application\/xhtml+xml,application\/xml;q=0.9,image\/webp,image\/apng,*\/*;q=0.8"->JSON.Encode.string,
        ),
        ("language", navigator.language->JSON.Encode.string),
        ("color_depth", colorDepth->Int.toFloat->JSON.Encode.float),
        ("screen_height", screen.height->Int.toFloat->JSON.Encode.float),
        ("screen_width", screen.width->Int.toFloat->JSON.Encode.float),
        ("time_zone", date.getTimezoneOffset()->JSON.Encode.float),
        ("java_enabled", true->JSON.Encode.bool),
        ("java_script_enabled", true->JSON.Encode.bool),
        ("device_model", `web-${browserName}`->JSON.Encode.string),
        ("os_type", getPlatformFromUserAgent()->JSON.Encode.string),
        ("os_version", browserVersion->JSON.Encode.string),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]
}
