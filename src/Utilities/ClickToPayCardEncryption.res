@module("./ClickToPayCardEncryptionHelpers")
external encryptMessage: Js.Json.t => Js.Promise.t<string> = "encryptMessage"
