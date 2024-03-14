type kountConfig = {
  clientID: string,
  environment: string,
  isSinglePageApp: bool,
}
type sdk = {\"IsCompleted": unit => bool}
type scriptSDK = {collectData: unit => unit}

@module("@kount/kount-web-client-sdk")
external kountSDK: (kountConfig, string) => sdk = "default"
@new external invokeKountSDK: unit => scriptSDK = "ka.ClientSDK"
