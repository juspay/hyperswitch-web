let isAvailable = () => {
  switch Window.Navigator.serviceWorker {
  | Some(container) =>
    switch container->Window.ServiceWorkerContainer.controller {
    | Some(_) => true
    | None => false
    }
  | None => false
  }
}

let registerSW = async () => {
  switch Window.Navigator.serviceWorker {
  | Some(container) =>
    try {
      let _ = await container->Window.ServiceWorkerContainer.register("/sw.js")
    } catch {
    | _ => ()
    }
  | None => ()
  }
}

let sendMessage = message => {
  switch Window.Navigator.serviceWorker {
  | Some(container) =>
    switch container->Window.ServiceWorkerContainer.controller {
    | Some(controller) => controller->Window.ServiceWorker.postMessage(message)
    | None => ()
    }
  | None => ()
  }
}
