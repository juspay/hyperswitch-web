type openDBRequest
type db
type transaction
type objectStore
type request<'a>
type event

module IndexedDB = {
  @val @scope("window") external instance: 'a = "indexedDB"
  @send external open_: ('a, string, int) => openDBRequest = "open"
}

module OpenDBRequest = {
  @set external onupgradeneeded: (openDBRequest, event => unit) => unit = "onupgradeneeded"
  @set external onsuccess: (openDBRequest, event => unit) => unit = "onsuccess"
  @set external onerror: (openDBRequest, event => unit) => unit = "onerror"
  @get external result: openDBRequest => db = "result"
}

module DB = {
  @send external createObjectStore: (db, string, 'options) => objectStore = "createObjectStore"
  @send external transaction: (db, array<string>, string) => transaction = "transaction"
  @send external close: db => unit = "close"
}

module Transaction = {
  @send external objectStore: (transaction, string) => objectStore = "objectStore"
  @set external oncomplete: (transaction, event => unit) => unit = "oncomplete"
  @set external onerror: (transaction, event => unit) => unit = "onerror"
}

module ObjectStore = {
  @send external add: (objectStore, 'data, 'key) => request<'a> = "add"
  @send external put: (objectStore, 'data) => request<'a> = "put"
  @send external getAll: objectStore => request<array<'a>> = "getAll"
  @send external clear: objectStore => request<'a> = "clear"
}

module Request = {
  @set external onsuccess: (request<'a>, event => unit) => unit = "onsuccess"
  @set external onerror: (request<'a>, event => unit) => unit = "onerror"
  @get external result: request<'a> => 'a = "result"
}

module Event = {
  @get external target: event => 'a = "target"
  @get external targetError: event => 'a = "target.error"
}

let dbCache: ref<option<db>> = ref(None)

let getDbFromEvent = event => {
  switch dbCache.contents {
  | Some(db) => db
  | None => {
      let target = Event.target(event)
      let db = target["result"]
      dbCache := Some(db)
      db
    }
  }
}

let getErrorMessageFromEvent = event => {
  try {
    let errorObj = Event.targetError(event)
    errorObj["message"]
  } catch {
  | _ => "Unknown error occurred"
  }
}

let openDBAndGetRequest = (~dbName, ~objectStoreName) => {
  let request = IndexedDB.instance->IndexedDB.open_(dbName, 1)

  request->OpenDBRequest.onupgradeneeded(event => {
    let db = getDbFromEvent(event)
    let _ =
      db->DB.createObjectStore(objectStoreName, {"keyPath": "timestamp", "autoIncrement": true})
  })

  request
}

let setupDatabase = (~dbName, ~objectStoreName, ~onSuccess, ~onError) => {
  let request = openDBAndGetRequest(~dbName, ~objectStoreName)

  request->OpenDBRequest.onsuccess(event => {
    let db = getDbFromEvent(event)
    onSuccess(db)
  })

  request->OpenDBRequest.onerror(event => {
    let errorMessage = getErrorMessageFromEvent(event)
    onError(errorMessage)
  })
}

let addData = (db, objectStoreName, data) => {
  let transaction = db->DB.transaction([objectStoreName], "readwrite")
  let store = transaction->Transaction.objectStore(objectStoreName)
  let request = store->ObjectStore.add(data, data["timestamp"])

  (request, transaction)
}

let getAllData = (db, objectStoreName, onSuccess) => {
  let transaction = db->DB.transaction([objectStoreName], "readonly")
  let store = transaction->Transaction.objectStore(objectStoreName)
  let request = store->ObjectStore.getAll

  request->Request.onsuccess(_ => {
    let result = Request.result(request)
    onSuccess(result)
  })
}
