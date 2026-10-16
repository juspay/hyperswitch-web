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

type userAgentInfo = {
  osName: option<string>,
  osVersion: option<string>,
  deviceModel: option<string>,
}

let maxUserAgentLength = 500

let maxFieldLength = 64

let bounded = value => value->String.length > maxFieldLength ? None : Some(value)

let firstGroup = (regex, str) =>
  switch regex->RegExp.exec(str) {
  | Some(result) =>
    switch result->RegExp.Result.matches->Array.get(0)->Option.getOr("") {
    | "" => None
    | value => Some(value)
    }
  | None => None
  }

let underscoresToDots = version => version->String.replaceRegExp(%re("/_/g"), ".")

let windowsVersion = ntVersion =>
  switch ntVersion {
  | "10.0" | "6.4" => "10"
  | "6.3" => "8.1"
  | "6.2" => "8"
  | "6.1" => "7"
  | "6.0" => "Vista"
  | "5.2" | "5.1" => "XP"
  | "5.0" => "2000"
  | other => other
  }

let isNotDeviceModel = segment =>
  segment == "" ||
  %re("/^(u|wv|phone|mobile|tablet|tv|vr|khtml, like gecko)$/i")->RegExp.test(segment) ||
  %re("/^(android|linux|windows|x11|macintosh|intel|ppc|win64|wow64|x64|arm_?6?4?|harmonyos|openharmony)[ \d._]*$/i")->RegExp.test(
    segment,
  ) ||
  %re("/^[a-z]{2}([-_][a-z]{2,3})?$/i")->RegExp.test(segment) ||
  %re("/^rv:/i")->RegExp.test(segment) ||
  %re("/^[\d.]+$/")->RegExp.test(segment) ||
  %re("/\/(?:\d|[^\/]*\d{4,})/")->RegExp.test(segment) ||
  %re("/\d+(\.\d+){2,}$/")->RegExp.test(segment) ||
  !(%re("/[a-z\d]/i")->RegExp.test(segment)) ||
  %re("/[\x00-\x1f\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff<>]/")->RegExp.test(
    segment,
  )

let deviceModelFromComment = userAgent =>
  switch %re("/\(([^)]*)\)/")->firstGroup(userAgent) {
  | Some(comment) =>
    comment
    ->String.split(";")
    ->Array.map(segment => segment->String.replaceRegExp(%re("/\s+build\/.*$/i"), "")->String.trim)
    ->Array.filter(segment => !isNotDeviceModel(segment))
    ->Array.last
    ->Option.map(model => model->String.replaceRegExp(%re("/^samsung\s+/i"), ""))
  | None => None
  }

let parseTruncatedUserAgent = userAgent =>
  if %re("/windows phone/i")->RegExp.test(userAgent) {
    {
      osName: Some("Windows Phone"),
      osVersion: %re("/windows phone(?: os)?[ \/]?([\d.]+)/i")->firstGroup(userAgent),
      deviceModel: deviceModelFromComment(userAgent),
    }
  } else if %re("/ip(hone|ad|od)/i")->RegExp.test(userAgent) {
    let version = switch %re("/os (\d+(?:[._]\d+)*) like mac os/i")->firstGroup(userAgent) {
    | Some(version) => Some(version)
    | None => %re("/ios[\/ ]([\d._]+)/i")->firstGroup(userAgent)
    }
    {
      osName: Some("iOS"),
      osVersion: version->Option.map(underscoresToDots),
      deviceModel: %re("/\((ip(?:hone|ad|od)[\w ]*)\s*[;)]/i")->firstGroup(userAgent),
    }
  } else if %re("/\b(?:harmonyos|openharmony)\b/i")->RegExp.test(userAgent) {
    let version = switch %re("/android[ \/-]?([\d.]+)/i")->firstGroup(userAgent) {
    | Some(version) => Some(version)
    | None => %re("/\b(?:harmonyos|openharmony)[ \/-]?([\d.]+)/i")->firstGroup(userAgent)
    }
    {
      osName: Some(%re("/\bopenharmony\b/i")->RegExp.test(userAgent) ? "OpenHarmony" : "HarmonyOS"),
      osVersion: version,
      deviceModel: deviceModelFromComment(userAgent),
    }
  } else if %re("/android/i")->RegExp.test(userAgent) {
    {
      osName: Some("Android"),
      osVersion: %re("/android[ \/-]?([\d.]+)/i")->firstGroup(userAgent),
      deviceModel: deviceModelFromComment(userAgent),
    }
  } else if %re("/windows/i")->RegExp.test(userAgent) {
    {
      osName: Some("Windows"),
      osVersion: %re("/windows nt ([\d.]+)/i")->firstGroup(userAgent)->Option.map(windowsVersion),
      deviceModel: None,
    }
  } else if %re("/mac os x|macintosh/i")->RegExp.test(userAgent) {
    {
      osName: Some("macOS"),
      osVersion: %re("/mac os x ([\d_.]+)/i")->firstGroup(userAgent)->Option.map(underscoresToDots),
      deviceModel: Some("Macintosh"),
    }
  } else if %re("/cros/i")->RegExp.test(userAgent) {
    {
      osName: Some("Chrome OS"),
      osVersion: %re("/cros [\w]+ ([\d.]+)/i")->firstGroup(userAgent),
      deviceModel: None,
    }
  } else if %re("/ubuntu/i")->RegExp.test(userAgent) {
    {osName: Some("Ubuntu"), osVersion: None, deviceModel: None}
  } else if %re("/linux/i")->RegExp.test(userAgent) {
    {
      osName: Some("Linux"),
      osVersion: %re("/linux ?([\w.]*)/i")->firstGroup(userAgent),
      deviceModel: None,
    }
  } else {
    {osName: None, osVersion: None, deviceModel: None}
  }

let parseUserAgent = userAgent => {
  let truncated =
    userAgent->String.length > maxUserAgentLength
      ? userAgent->String.slice(~start=0, ~end=maxUserAgentLength)
      : userAgent
  let {osName, osVersion, deviceModel} = truncated->parseTruncatedUserAgent
  {
    osName: osName->Option.flatMap(bounded),
    osVersion: osVersion->Option.flatMap(bounded),
    deviceModel: deviceModel->Option.flatMap(bounded),
  }
}

let date = date()

let broswerInfo = () => {
  let data = parseUserAgent(navigator.userAgent)
  let osType = data.osName->Option.getOr("Unknown")
  let osVersion = data.osVersion->Option.getOr("Unknown")
  let deviceModel = data.deviceModel->Option.getOr("Unknown Device")
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
        ("device_model", deviceModel->JSON.Encode.string),
        ("os_type", osType->JSON.Encode.string),
        ("os_version", osVersion->JSON.Encode.string),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]
}
