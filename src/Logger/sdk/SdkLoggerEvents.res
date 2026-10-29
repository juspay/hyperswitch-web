include SharedLogger.Events.WebSdk
let resourceKind = value => SharedLogger.Events.WebSdk.resourceKind(value,~script=ResourceLoader.Script,~stylesheet=ResourceLoader.Stylesheet)
