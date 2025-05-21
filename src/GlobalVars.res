type sdkVersion = V1 | V2

let getVersionFromStr = name =>
  switch name->String.toLowerCase {
  | "v2" => V2
  | "v1"
  | _ =>
    V1
  }

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
@val external sdkVersionStr: string = "sdkVersionValue"
let sdkVersion = sdkVersionStr->getVersionFromStr
let targetOrigin: string = "*"
@val external isInteg: bool = "isIntegrationEnv"
@val external isSandbox: bool = "isSandboxEnv"
@val external isProd: bool = "isProductionEnv"
