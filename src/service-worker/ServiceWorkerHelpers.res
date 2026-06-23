let getContainer = () =>
  try {
    Window.Navigator.serviceWorker
  } catch {
  | _ => None
  }

let getController = () =>
  getContainer()->Option.flatMap(container =>
    container->Window.ServiceWorkerContainer.controller->Nullable.toOption
  )

let isAvailable = () =>
  getController()
  ->Option.map(controller =>
    controller->Window.ServiceWorker.scriptURL->String.includes("hs-sdk-sw.js")
  )
  ->Option.getOr(false)

let registerSW = async () =>
  switch getContainer() {
  | Some(container) =>
    try {
      let _ = await container->Window.ServiceWorkerContainer.register("/hs-sdk-sw.js")
    } catch {
    | _ => ()
    }
  | None => ()
  }

let sendMessage = message =>
  getController()->Option.forEach(controller =>
    controller->Window.ServiceWorker.postMessage(message)
  )
