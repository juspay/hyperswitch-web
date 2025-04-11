// Basic types for IndexedDB
type openDBRequest
type db
type transaction
type objectStore
type request

// Use abstract types for events
type event

@val @scope("window") external indexedDB: 'a = "indexedDB"

@send external open_: ('a, string, int) => openDBRequest = "open"

@set external onupgradeneeded: (openDBRequest, event => unit) => unit = "onupgradeneeded"
@set external onsuccess: (openDBRequest, event => unit) => unit = "onsuccess"
@set external onsuccessRequest: (request, event => unit) => unit = "onsuccess"
@set external onerror: (openDBRequest, event => unit) => unit = "onerror"
@set external onerrorRequest: (request, event => unit) => unit = "onerror"

// Directly use the IDBRequest.result property to get the database
@get external result: openDBRequest => db = "result"
@get external resultFromRequest: request => 'a = "result"

// For events, we need to access the target.result
@get external getTarget: event => 'a = "target"
@get external getResultFromTarget: 'a => 'b = "result"

// Error handling
@get external getTargetError: event => 'a = "target.error"
@get external getErrorMessage: 'a => string = "message"

@send external createObjectStore: (db, string, 'options) => objectStore = "createObjectStore"
@send external objectStore: (transaction, string) => objectStore = "objectStore"
@send external transaction_: (db, array<string>, string) => transaction = "transaction"
@send external add: (objectStore, 'data, 'key) => request = "add"
@send external put: (objectStore, 'data) => request = "put"
@send external getAll: objectStore => request = "getAll"
@send external clear: objectStore => request = "clear"
@send external close: db => unit = "close"

@set external setTransactionOncomplete: (transaction, event => unit) => unit = "oncomplete"
@set external setTransactionOnerror: (transaction, event => unit) => unit = "onerror"
@set external setAddRequestOnsuccess: (request, event => unit) => unit = "onsuccess"

// Helper to get result from event safely
let dbCache: ref<option<db>> = ref(None)
let getDbFromEvent = event => {
  switch dbCache.contents {
  | Some(db) => db
  | None => {
      let target = getTarget(event)
      let db = getResultFromTarget(target)
      dbCache := Some(db)
      db
    }
  }
}

// Setup database helper function
let openDBAndGetRequest = (~dbName, ~objectStoreName) => {
  let request = indexedDB->open_(dbName, 1)

  request->onupgradeneeded(event => {
    let db = getDbFromEvent(event)
    let _ = db->createObjectStore(objectStoreName, {"keyPath": "timestamp", "autoIncrement": true})
  })

  request
}

// Safe error message extraction
let getErrorMessageFromEvent = event => {
  try {
    let errorObj = getTargetError(event)
    getErrorMessage(errorObj)
  } catch {
  | _ => "Unknown error occurred"
  }
}
