open IndexedDB
let logApi = (
  ~eventName,
  ~statusCode=0,
  ~data: JSON.t=Dict.make()->JSON.Encode.object,
  ~apiLogType: HyperLoggerTypes.apiLogType,
  ~url="",
  ~paymentMethod="",
  ~result: JSON.t=Dict.make()->JSON.Encode.object,
  ~optLogger: option<HyperLoggerTypes.loggerMake>,
  ~logType: HyperLoggerTypes.logType=INFO,
  ~logCategory: HyperLoggerTypes.logCategory=API,
  ~isPaymentSession: bool=false,
) => {
  let (value, internalMetadata) = switch apiLogType {
  | Request => ([("url", url->JSON.Encode.string)], [])
  | Response => (
      [("url", url->JSON.Encode.string), ("statusCode", statusCode->JSON.Encode.int)],
      [("response", data)],
    )
  | NoResponse => (
      [("url", url->JSON.Encode.string), ("statusCode", 504->JSON.Encode.int), ("response", data)],
      [("response", data)],
    )
  | Err => (
      [
        ("url", url->JSON.Encode.string),
        ("statusCode", statusCode->JSON.Encode.int),
        ("response", data),
      ],
      [("response", data)],
    )
  | Method => ([("method", paymentMethod->JSON.Encode.string)], [("result", result)])
  }
  switch optLogger {
  | Some(logger) =>
    logger.setLogApi(
      ~eventName,
      ~value=ArrayType(value),
      ~internalMetadata=ArrayType(internalMetadata),
      ~logType,
      ~logCategory,
      ~apiLogType,
      ~isPaymentSession,
    )
  | None => ()
  }
}

let logInputChangeInfo = (text, logger: HyperLoggerTypes.loggerMake) => {
  logger.setLogInfo(~value=text, ~eventName=INPUT_FIELD_CHANGED)
}

let handleLogging = (
  ~optLogger: option<HyperLoggerTypes.loggerMake>,
  ~value,
  ~internalMetadata="",
  ~eventName,
  ~paymentMethod,
  ~logType: HyperLoggerTypes.logType=INFO,
) => {
  switch optLogger {
  | Some(logger) =>
    logger.setLogInfo(~value, ~internalMetadata, ~eventName, ~paymentMethod, ~logType)
  | _ => ()
  }
}

let eventNameToStrMapper = (eventName: HyperLoggerTypes.eventName) => (eventName :> string)

let getPaymentId = clientSecret =>
  String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")

let convertToScreamingSnakeCase = text => {
  text->String.trim->String.replaceRegExp(%re("/ /g"), "_")->String.toUpperCase
}

let toSnakeCaseWithSeparator = (str, separator) => {
  str->Js.String2.unsafeReplaceBy0(%re("/[A-Z]/g"), (letter, _, _) =>
    `${separator}${letter->String.toLowerCase}`
  )
}

let defaultLoggerConfig: HyperLoggerTypes.loggerMake = {
  sendLogs: () => (),
  setClientSecret: _x => (),
  setEphemeralKey: _x => (),
  setConfirmPaymentValue: (~paymentType as _) => {Dict.make()->JSON.Encode.object},
  setLogError: (
    ~value as _,
    ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
  ) => (),
  setLogApi: (
    ~value as _,
    ~internalMetadata as _,
    ~eventName as _,
    ~timestamp as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
    ~apiLogType as _=?,
    ~isPaymentSession as _=?,
  ) => (),
  setLogInfo: (
    ~value as _,
    ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
  ) => (),
  setLogInitiated: () => (),
  setMerchantId: _x => (),
  setSessionId: _x => (),
  setMetadata: _x => (),
  setSource: _x => (),
}

let saveLogsToIndexedDB = (logs: array<HyperLoggerTypes.logFile>) => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    onsuccess(request, _ => {
      let db = result(request)
      if logs->Array.length > 0 {
        let transaction = db->transaction_(["logs"], "readwrite")
        let store = transaction->objectStore("logs")

        transaction->setTransactionOncomplete(
          _ => {
            db->close
            resolve()
          },
        )

        transaction->setTransactionOnerror(
          _ => {
            db->close
            reject()
          },
        )

        logs->Array.forEach(
          log => {
            let _ = store->put(log)
          },
        )
      } else {
        db->close
        reject()
      }
    })

    onerror(request, _ => {
      reject()
    })
  })
}

let retrieveLogsFromIndexedDB = () => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    onsuccess(request, _ => {
      let db = result(request)
      let transaction = db->transaction_(["logs"], "readonly")
      let store = transaction->objectStore("logs")
      let getAllRequest = store->getAll

      onsuccessRequest(
        getAllRequest,
        resultEvent => {
          let target = getTarget(resultEvent)
          let result = getResultFromTarget(target)
          db->close
          resolve(result)
        },
      )

      onerrorRequest(
        getAllRequest,
        _ => {
          db->close
          reject([])
        },
      )
    })

    onerror(request, _ => {
      reject([])
    })
  })
}

let clearLogsFromIndexedDB = () => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    onsuccess(request, _ => {
      let db = result(request)
      let transaction = db->transaction_(["logs"], "readwrite")
      let store = transaction->objectStore("logs")
      let clearRequest = store->clear

      onsuccessRequest(
        clearRequest,
        _ => {
          db->close
          resolve()
        },
      )

      onerrorRequest(
        clearRequest,
        _ => {
          db->close
          reject()
        },
      )
    })

    onerror(request, _ => {
      reject()
    })
  })
}
