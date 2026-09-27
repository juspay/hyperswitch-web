let flushDelayMs = 2000

let maxBatchBytes = 30000

let maxQueuedRows = 100

type t = {
  rows: array<JSON.t>,
  mutable queuedBytes: int,
  mutable flushTimer: option<timeoutId>,
  mutable errorPending: bool,
  mutable droppedRows: int,
  mutable failures: int,
  mutable sendFailures: int,
}

let queue = {
  rows: [],
  queuedBytes: 0,
  flushTimer: None,
  errorPending: false,
  droppedRows: 0,
  failures: 0,
  sendFailures: 0,
}

let clearTimer = () =>
  switch queue.flushTimer {
  | Some(timer) => {
      clearTimeout(timer)
      queue.flushTimer = None
    }
  | None => ()
  }

let take = count => {
  let taken = queue.rows->Array.slice(~start=0, ~end=count)
  queue.rows->Array.splice(~start=0, ~remove=count, ~insert=[])
  taken
}

let rowBytes = row => row->JSON.stringify->LoggerUtils.utf8Length + 1

let recountBytes = () =>
  queue.queuedBytes = queue.rows->Array.reduce(0, (total, row) => total + row->rowBytes)

let batchSize = () => {
  let bytes = ref(2)
  let count = ref(0)
  let rows = queue.rows
  let continue = ref(true)
  while continue.contents && count.contents < rows->Array.length {
    let next = rows->Array.getUnsafe(count.contents)->rowBytes
    if count.contents === 0 || bytes.contents + next <= maxBatchBytes {
      bytes := bytes.contents + next
      count := count.contents + 1
    } else {
      continue := false
    }
  }
  count.contents
}

let retryDelayMs = () =>
  switch queue.failures {
  | 0 => flushDelayMs
  | failures => Math.Int.min(flushDelayMs * Math.Int.pow(2, ~exp=failures), 60000)
  }

let requeue = batch => {
  queue.rows->Array.splice(~start=0, ~remove=0, ~insert=batch)
  let overflow = queue.rows->Array.length - maxQueuedRows
  if overflow > 0 {
    queue.rows->Array.splice(~start=maxQueuedRows, ~remove=overflow, ~insert=[])
    queue.droppedRows = queue.droppedRows + overflow
  }
}

let maxSendAttemptsPerBatch = 4

let rec flush = () => {
  clearTimer()
  queue.errorPending = false
  switch batchSize() {
  | 0 => queue.queuedBytes = 0
  | size => {
      let batch = size->take
      if batch->LoggerTransport.send {
        queue.failures = 0
      } else {
        queue.failures = queue.failures + 1
        queue.sendFailures = queue.sendFailures + 1
        if queue.failures >= maxSendAttemptsPerBatch {
          queue.failures = 0
          queue.droppedRows = queue.droppedRows + batch->Array.length
        } else {
          batch->requeue
        }
      }
      recountBytes()
      queue.rows->Array.length > 0 ? scheduleFlush() : ()
    }
  }
}
and scheduleFlush = () =>
  switch queue.flushTimer {
  | Some(_) => ()
  | None => queue.flushTimer = Some(setTimeout(flush, retryDelayMs()))
  }

let drain = () =>
  LoggerUtils.safeRun(() => {
    clearTimer()
    queue.errorPending = false
    let continue = ref(true)
    while continue.contents {
      switch batchSize() {
      | 0 => continue := false
      | size => {
          let batch = size->take
          if !(batch->LoggerTransport.send) {
            batch->requeue
            continue := false
          }
        }
      }
    }
    recountBytes()
    queue.rows->Array.length > 0 ? scheduleFlush() : ()
  })

let push = (row, ~isError) => {
  queue.rows->Array.push(row)
  queue.queuedBytes = queue.queuedBytes + row->rowBytes
  if isError {
    if !queue.errorPending {
      queue.errorPending = true
      setTimeout(() => queue.errorPending ? flush() : (), 0)->ignore
    }
  } else if queue.queuedBytes >= maxBatchBytes {
    flush()
  } else {
    scheduleFlush()
  }
}

// Early rows (e.g. iframe mount events) can be emitted before the parent
// window shares the session context. They wait in the flush debounce window,
// so stamp any still-queued rows once the identifiers become known.
let backfillContext = (~sessionId, ~merchantId, ~paymentId, ~authenticationId) => {
  queue.rows->Array.forEach(row =>
    row
    ->JSON.Decode.object
    ->Option.forEach(object => {
      let fill = (key, value) =>
        if (
          value !== "" &&
            object->Dict.get(key)->Option.flatMap(JSON.Decode.string)->Option.getOr("") === ""
        ) {
          object->Dict.set(key, value->JSON.Encode.string)
        }
      fill("session_id", sessionId)
      fill("merchant_id", merchantId)
      fill("payment_id", paymentId)
      fill("authentication_id", authenticationId)
    })
  )
  recountBytes()
}

let takeDroppedRows = () => {
  let dropped = queue.droppedRows
  queue.droppedRows = 0
  dropped
}

let takeSendFailures = () => {
  let failures = queue.sendFailures
  queue.sendFailures = 0
  failures
}

Window.addEventListener("visibilitychange", _ => Window.visibilityState === "hidden" ? drain() : ())
Window.addEventListener("pagehide", _ => drain())
Window.addEventListener("beforeunload", _ => drain())
