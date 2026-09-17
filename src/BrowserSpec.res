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

/*
 Minimal user-agent sniff. Only three parsed values ever reach a payment request - os_type,
 os_version and device_model - so the fields below are the whole contract. Names and versions
 follow ua-parser-js 2.0.0 so the values merchants already receive do not change.
 */
type userAgentInfo = {
  osName: option<string>,
  osVersion: option<string>,
  deviceModel: option<string>,
}

/*
 navigator.userAgent is attacker-controlled and ends up in the confirm request body and the
 stored payment record, so the bounds are explicit: 500 is ua-parser-js's own UA_MAX_LENGTH
 (the limit this field already had in production), and it caps the input every regex below sees.
 */
let maxUserAgentLength = 500

/*
 The longest real corpus value is "moto g stylus 5G" at 16 characters. An over-long value is by
 construction not a real model, so it is dropped rather than truncated - a prefix of an attack
 string is worse than "Unknown Device".
 */
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

/* `Windows NT <n>` is a kernel version, not the version the payment API expects */
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

/*
 Android and Windows Phone put the device model in the parenthesised comment, after the
 platform, locale and build segments. Drop every segment known not to be a model; of what
 remains, the last one is the model.

 The last two rules matter because the model is *not* always last: Huawei appends
 `HMSCore <version>`, Opera appends `Opera Mini/7.5.33361/28.2555` or
 `Opera Mobi/ADR-1305251841` - library tokens, not devices. A `<name>/<version>` product token
 is recognised by the *version*, not the slash: matching the bare slash would take out every
 dual-SIM/variant model (`SM-G998B/DS`, `SM-A515F/DS`, `INE-LX2r/DS`, `LG-D855/V20c`), which
 dominate India, Brazil, SE Asia and MENA. The dotted-version rule does NOT cover
 `Opera Mini/7.5.33361/28.2555`: it ends in `28.2555`, only two components.
 */
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
  /*
   Shape guards, for the same reason as the length cap: a Build.MODEL is never pure punctuation
   and never contains a control, bidi/zero-width or angle-bracket character. These narrow the
   *shape* of the field - they are not sanitisation; device_model stays untrusted client text
   and must be escaped wherever rendered.
   */
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

/* Order matters: iOS carries "like Mac OS X", Android and Ubuntu carry "Linux", Windows Phone
   carries "Android", and HarmonyOS carries "Android" *and* "Linux" */
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
    /* HarmonyOS reports as a comment segment *alongside* its compatible Android version
       (`(Linux; Android 10; HarmonyOS; JEF-AN00; …)`), so it must be tested before /android/i.
       ua-parser-js took the version from the Android token here, so keep doing that.
       OpenHarmony (NEXT) carries no Android token. */
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

/* The one choke point for both bounds: truncate before any regex sees the agent, and drop any
   value that comes back longer than a real one could be */
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

/*
 The bounds above cover the three *parsed* values only. `user_agent` below is emitted whole
 and untruncated, deliberately: EMVCo 3DS browser info carries it verbatim and ACS device
 fingerprinting hashes it, so truncating it would break authentication outright. `language` is
 likewise raw - both stay client-controlled and unbounded.
 */
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
