let flushDelayMs = 2000

let maxBatchBytes = 60000

let maxQueuedRows = 100

type t = {
  rows: array<JSON.t>,
  mutable queuedBytes: int,
  mutable flushTimer: option<timeoutId>,
  mutable errorPending: bool,
  mutable droppedRows: int,
  mutable failures: int,
}

let queue = {
  rows: [],
  queuedBytes: 0,
  flushTimer: None,
  errorPending: false,
  droppedRows: 0,
  failures: 0,
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

let rowBytes = row => row->JSON.stringify->String.length + 1

let recountBytes = () =>
  queue.queuedBytes = queue.rows->Array.reduce(0, (total, row) => total + row->rowBytes)

let batchSize = () => {
  let bytes = ref(2)
  let count = ref(0)
  let rows = queue.rows
  while (
    count.contents < rows->Array.length &&
      (count.contents === 0 ||
        bytes.contents + rows->Array.getUnsafe(count.contents)->rowBytes <= maxBatchBytes)
  ) {
    bytes := bytes.contents + rows->Array.getUnsafe(count.contents)->rowBytes
    count := count.contents + 1
  }
  count.contents
}

let send = rows =>
  GlobalVars.logEndpoint->String.trim === "" || !Window.Navigator.hasSendBeacon()
    ? false
    : try Window.Navigator.sendBeacon(
        GlobalVars.logEndpoint,
        rows->JSON.Encode.array->JSON.stringify,
      ) catch {
      | _ => false
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

let rec flush = () => {
  clearTimer()
  queue.errorPending = false
  switch batchSize() {
  | 0 => queue.queuedBytes = 0
  | size => {
      let batch = size->take
      if batch->send {
        queue.failures = 0
      } else {
        queue.failures = queue.failures + 1
        batch->requeue
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

let flushNow = () => LoggerUtils.safeRun(flush)

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

let takeDroppedRows = () => {
  let dropped = queue.droppedRows
  queue.droppedRows = 0
  dropped
}

Window.addEventListener("visibilitychange", _ =>
  Window.visibilityState === "hidden" ? flushNow() : ()
)
Window.addEventListener("pagehide", _ => flushNow())
Window.addEventListener("beforeunload", _ => flushNow())
