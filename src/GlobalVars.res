@val external repoName: string = "repoName"
@val external repoVersion: string = "repoVersion"
@val external repoPublicPath: string = "publicPath"
@val external backendEndPoint: string = "backendEndPoint"
@val external confirmEndPoint: string = "confirmEndPoint"
@val external sdkUrl: string = "sdkUrl"
@val external logEndpoint: string = "logEndpoint"
@val external sentryDSN: string = "sentryDSN"
@val external sentryScriptUrl: string = "sentryScriptUrl"
@val external enableLogging: bool = "enableLogging"
@val external loggingLevelStr: string = "loggingLevel"
@val external maxLogsPushedPerEventName: int = "maxLogsPushedPerEventName"
@val external sdkVersion: string = "sdkVersion"
let targetOrigin: string = "*"
let isInteg = sdkUrl === "https://dev.hyperswitch.io"
let isSandbox = sdkUrl === "https://beta.hyperswitch.io" || sdkUrl === "http://localhost:9050"
let isProd = sdkUrl === "https://checkout.hyperswitch.io"
let isRunningLocally =
  sdkUrl->String.includes("localhost") ||
  sdkUrl->String.includes("127.0.0.") ||
  sdkUrl->String.includes("0.0.0.0")
