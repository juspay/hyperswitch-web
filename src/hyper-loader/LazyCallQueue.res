/*
 One FIFO call queue per root facade object - one `elements()`, one `initPaymentMethodSession()`.

 A synchronous facade hands the merchant real objects before their chunk has landed, so calls
 made in the meantime must be recorded and replayed in merchant order. Callbacks spread across a
 promise chain run by chain depth, not registration order - a `deinit` issued last ran before an
 earlier `mount`, and `deinit` cannot undo a later mount - hence one queue per root, drained in
 push order. Each facade object parks its real counterpart in a `ref` that the queued step which
 creates it fills in; FIFO order guarantees the ref is populated before a later step reads it. A
 step whose ref is still `None` (chunk never arrived, or the `create` ahead of it failed) takes
 its own fallback branch.
 */
type t = {
  mutable steps: array<unit => unit>,
  mutable isDrained: bool,
  onError: exn => unit,
}

let make = (~onError: exn => unit): t => {steps: [], isDrained: false, onError}

/* One failing call must not take the rest of the queue down with it */
let runStep = (t, step) =>
  try step() catch {
  | err => t.onError(err)
  }

let push = (t: t, step: unit => unit): unit =>
  if t.isDrained {
    t->runStep(step)
  } else {
    t.steps->Array.push(step)
  }

/*
 Index-based rather than `forEach`: a step may push another step (a merchant handler firing
 during replay) and it must still run, behind everything ahead of it; `isDrained` is set only
 after the loop so a re-entrant push appends rather than jumping the queue.
 */
let drain = (t: t): unit => {
  let index = ref(0)
  while index.contents < t.steps->Array.length {
    t.steps->Array.get(index.contents)->Option.forEach(step => t->runStep(step))
    index := index.contents + 1
  }
  t.steps = []
  t.isDrained = true
}

/* `target` is filled in by the queued step that creates it; still `None` when the call runs
   means the object does not exist, so neither does the call */
let pushCall = (t: t, target: ref<option<'a>>, call: 'a => unit): unit =>
  t->push(() => target.contents->Option.forEach(call))

/* The merchant already holds the promise it was handed synchronously; `run` executes in queue
   order and decides whether the real object exists, and its return settles that promise */
let pushPromise = (t: t, run: unit => promise<'a>): promise<'a> =>
  Promise.make((resolve, reject) =>
    t->push(() =>
      try {
        run()
        ->Promise.then(value => {
          resolve(value)
          Promise.resolve()
        })
        ->Promise.catch(err => {
          reject(err)
          Promise.resolve()
        })
        ->ignore
      } catch {
      | err => reject(err)
      }
    )
  )

/* `orElse` is what the promise settles with when the object never came into existence */
let pushPromiseCall = (
  t: t,
  target: ref<option<'a>>,
  call: 'a => promise<'b>,
  ~orElse: unit => promise<'b>,
): promise<'b> =>
  t->pushPromise(() =>
    switch target.contents {
    | Some(value) => call(value)
    | None => orElse()
    }
  )
