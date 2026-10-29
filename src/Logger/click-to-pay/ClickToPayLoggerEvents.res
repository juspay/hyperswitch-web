include SharedLogger.Events.WebClickToPay
let resourceKind = value => SharedLogger.Events.WebClickToPay.resourceKind(value,~script=ResourceLoader.Script,~stylesheet=ResourceLoader.Stylesheet)
