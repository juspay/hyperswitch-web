open BrowserSpec
open UPITypes

let getMobileOperatingSystem = () => {
  let ua = navigator.userAgent
  if (
    ua->String.includes("Android") ||
    ua->String.includes("android") ||
    ua->String.includes("ANDROID")
  ) {
    "ANDROID"
  } else if (
    ua->String.includes("iPad") || ua->String.includes("iPhone") || ua->String.includes("iPod")
  ) {
    "IOS"
  } else {
    "UNKNOWN"
  }
}

let isItInappBrowser = () => {
  try {
    let ua = navigator.userAgent->String.toLowerCase
    ua->String.includes("instagram") || ua->String.includes("fbav")
  } catch {
  | _error => false
  }
}

let detectIosWebView = () => {
  try {
    let hasWebkitMessageHandlers = switch webkit {
    | None => false
    | Some(webkitObj) =>
      switch webkitObj->messageHandlers {
      | None => false
      | Some(_) => true
      }
    }
    let hasEqualHeights = clientHeight === scrollHeight
    hasWebkitMessageHandlers || hasEqualHeights
  } catch {
  | _error => false
  }
}

let isItWebViewFromUserAgent = () => {
  try {
    switch getMobileOperatingSystem() {
    | "ANDROID" => navigator.userAgent->String.toLowerCase->String.includes("wv")
    | "IOS" => detectIosWebView()
    | _ => false
    }
  } catch {
  | _error => false
  }
}

let openApp = (upiUrl: string) => {
  let mobileOS = getMobileOperatingSystem()

  if mobileOS === "IOS" {
    try {
      Window.Location.replace(upiUrl)
    } catch {
    | _err => Console.error("Error opening UPI app on iOS: " ++ upiUrl)
    }
  } else if mobileOS === "ANDROID" {
    try {
      let isWebView = isItWebViewFromUserAgent()
      let isInAppBrowser = isItInappBrowser()

      if isWebView && isInAppBrowser {
        try {
          let payload = Dict.fromArray([
            ("action", "openApp"->JSON.Encode.string),
            ("url", upiUrl->JSON.Encode.string),
          ])
          Window.windowParent->postMessageToWindow(payload->JSON.Encode.object->JSON.stringify, "*")
        } catch {
        | _ => Window.Location.replace(upiUrl)
        }
      } else {
        Window.Location.replace(upiUrl)
      }
    } catch {
    | _err => Console.error("Error opening UPI app on Android: " ++ upiUrl)
    }
  } else {
    try {
      Window.Location.replace(upiUrl)
    } catch {
    | _err => Console.error("Error opening UPI app on unknown platform: " ++ upiUrl)
    }
  }
}

let constructUrl = (uri, packageName) => {
  if uri->String.startsWith("upi://pay") {
    uri->String.replace("upi://pay", packageName)
  } else {
    uri
  }
}

let constructAppSpecificUrl = (app: appInfo, originalUrl: string) => {
  if app.name === anyUpiApp.name {
    originalUrl
  } else {
    switch app.name {
    | "Google Pay"
    | "PhonePe"
    | "Paytm"
    | "BHIM"
    | "Mobikwik"
    | "CRED"
    | "Navi"
    | "Kiwi"
    | "Moneyview"
    | "Super Money" =>
      constructUrl(originalUrl, app.packageName)
    | _ => originalUrl
    }
  }
}

let generateQRCode = (url: string) => {
  try {
    let qr = QRGenerator.make(0, "M")
    qr.addData(url, "Byte")
    qr.make()

    Some(qr.createSvgTag(4, 8))
  } catch {
  | _ => None
  }
}

let formatTime = (seconds: float) => {
  let minutes = (seconds /. 60.0)->Float.toInt
  let remainingSeconds = seconds->Float.toInt - minutes * 60
  let formattedMinutes = minutes < 10 ? `0${minutes->Int.toString}` : minutes->Int.toString
  let formattedSeconds =
    remainingSeconds < 10 ? `0${remainingSeconds->Int.toString}` : remainingSeconds->Int.toString
  `${formattedMinutes}:${formattedSeconds} min`
}
