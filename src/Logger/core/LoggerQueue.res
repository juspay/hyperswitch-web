type entry = {
  row: LoggerTypes.row,
  mutable text: string,
  mutable bytes: int,
}

let rows: array<entry> = []
let queuedBytes = ref(0)
let flushTimer = ref(None)
let errorPending = ref(false)
let droppedRows = ref(0)
let failures = ref(0)
let sendFailures = ref(0)

let sendPayload = payload =>
  LoggerConfig.endpoint !== "" && Window.Navigator.hasSendBeacon()
    ? try Window.Navigator.sendBeacon(LoggerConfig.endpoint, payload) catch {
      | _ => false
      }
    : false

let clearTimer = () =>
  flushTimer.contents->Option.forEach(timer => {
    clearTimeout(timer)
    flushTimer := None
  })

let serialize = entry => {
  let text = entry.row->JSON.stringifyAny->Option.getOr("")
  entry.text = text
  entry.bytes = text->LoggerUtils.utf8Length + 1
}

let recountBytes = () => queuedBytes := rows->Array.reduce(0, (total, entry) => total + entry.bytes)

let batchSize = () => {
  let bytes = ref(2)
  let count = ref(0)
  while (
    count.contents < rows->Array.length &&
      (count.contents === 0 ||
        bytes.contents + (rows->Array.getUnsafe(count.contents)).bytes <=
          LoggerConfig.maxBatchBytes)
  ) {
    bytes := bytes.contents + (rows->Array.getUnsafe(count.contents)).bytes
    count := count.contents + 1
  }
  count.contents
}

let sendNext = () => {
  let count = batchSize()
  let batch = rows->Array.slice(~start=0, ~end=count)
  rows->Array.splice(~start=0, ~remove=count, ~insert=[])
  count === 0 || sendPayload(`[${batch->Array.map(entry => entry.text)->Array.join(",")}]`)
    ? None
    : Some(batch)
}

let requeue = batch => {
  rows->Array.splice(~start=0, ~remove=0, ~insert=batch)
  let overflow = rows->Array.length - LoggerConfig.maxQueuedRows
  if overflow > 0 {
    rows->Array.splice(~start=LoggerConfig.maxQueuedRows, ~remove=overflow, ~insert=[])
    droppedRows := droppedRows.contents + overflow
  }
}

let rec flush = () => {
  clearTimer()
  errorPending := false
  if rows->Array.length > 0 {
    switch sendNext() {
    | None => failures := 0
    | Some(batch) => {
        failures := failures.contents + 1
        sendFailures := sendFailures.contents + 1
        if failures.contents >= LoggerConfig.maxSendAttemptsPerBatch {
          failures := 0
          droppedRows := droppedRows.contents + batch->Array.length
        } else {
          batch->requeue
        }
      }
    }
    recountBytes()
    if rows->Array.length > 0 {
      scheduleFlush()
    }
  } else {
    queuedBytes := 0
  }
}
and scheduleFlush = () =>
  if flushTimer.contents->Option.isNone {
    let delay = switch failures.contents {
    | 0 => LoggerConfig.flushDelayMs
    | failures =>
      Math.Int.min(
        LoggerConfig.flushDelayMs * Math.Int.pow(2, ~exp=failures),
        LoggerConfig.maxFlushBackoffMs,
      )
    }
    flushTimer := Some(setTimeout(flush, delay))
  }

let drain = () =>
  LoggerUtils.safeRun(() => {
    clearTimer()
    errorPending := false
    let failed = ref(false)
    while !failed.contents && rows->Array.length > 0 {
      switch sendNext() {
      | None => ()
      | Some(batch) => {
          batch->requeue
          failed := true
        }
      }
    }
    recountBytes()
    if rows->Array.length > 0 {
      scheduleFlush()
    }
  })

let push = (row, ~isError) => {
  let entry = {row, text: "", bytes: 0}
  entry->serialize
  rows->Array.push(entry)
  queuedBytes := queuedBytes.contents + entry.bytes
  if isError {
    if !errorPending.contents {
      errorPending := true
      setTimeout(() => errorPending.contents ? flush() : (), 0)->ignore
    }
  } else if queuedBytes.contents >= LoggerConfig.maxBatchBytes {
    flush()
  } else {
    scheduleFlush()
  }
}

// Early rows (e.g. iframe mount events) can be emitted before the parent
// window shares the session context. They wait in the flush debounce window,
// so stamp any still-queued rows once the identifiers become known.
let backfillContext = (context: LoggerTypes.context) =>
  rows->Array.forEach(entry => {
    let row = entry.row
    let changed = ref(false)
    let fill = (current, value) =>
      if current === "" && value !== "" {
        changed := true
        value
      } else {
        current
      }
    row.sessionId = fill(row.sessionId, context.sessionId)
    row.merchantId = fill(row.merchantId, context.merchantId)
    row.paymentId = fill(row.paymentId, context.paymentId)
    row.authenticationId = fill(row.authenticationId, context.authenticationId)
    if changed.contents {
      let before = entry.bytes
      entry->serialize
      queuedBytes := queuedBytes.contents - before + entry.bytes
    }
  })

Window.addEventListener("visibilitychange", _ => Window.visibilityState === "hidden" ? drain() : ())
Window.addEventListener("pagehide", _ => drain())
