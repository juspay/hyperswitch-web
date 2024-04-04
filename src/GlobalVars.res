@val external repoName: string = "repoName"
@val external repoVersion: string = "repoVersion"
@val external repoPublicPath: string = "publicPath"
@val external backendEndPoint: string = "backendEndPoint"
@val external confirmEndPoint: string = "confirmEndPoint"
@val external sdkUrl: string = "sdkUrl"
@val external logEndpoint: string = "logEndpoint"
// @val external sentryDSN: string = "sentryDSN"
// @val external sentryScriptUrl: string = "sentryScriptUrl"
@val external enableLogging: bool = "enableLogging"
@val external loggingLevelStr: string = "loggingLevel"
@val external maxLogsPushedPerEventName: int = "maxLogsPushedPerEventName"
let targetOrigin: string = "*"
let isInteg = sdkUrl === "https://dev.hyperswitch.io"
let isSandbox = sdkUrl === "https://beta.hyperswitch.io"
let isProd = sdkUrl === "https://checkout.hyperswitch.io"
