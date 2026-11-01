open LoggerTypes

type transStatusData = {transStatus: string}
type threeDsMethodFailure = MissingContainer | FormSubmitFailed | IframeLoadFailed
type threeDsMethodFailureData = {reason: threeDsMethodFailure}

type lifecycleEvent =
  | ThreeDsChallengeShown(transStatusData)
  | ThreeDsFrictionlessResolved(transStatusData)
  | ThreeDsAuthContainerMissing(transStatusData)
  | ThreeDsAuthRequestFailed
  | ThreeDsMethodStarted
  | ThreeDsMethodCompleted
  | ThreeDsMethodSkipped
  | ThreeDsMethodFailed(threeDsMethodFailureData)
  | ThreeDsMethodTimedOut

let lifecycleSeverity = event =>
  switch event {
  | ThreeDsMethodStarted
  | ThreeDsMethodCompleted
  | ThreeDsMethodSkipped =>
    Debug
  | ThreeDsChallengeShown(_) | ThreeDsFrictionlessResolved(_) => Info
  | ThreeDsMethodTimedOut => Warning
  | ThreeDsAuthContainerMissing(_) | ThreeDsAuthRequestFailed => Error
  | ThreeDsMethodFailed({reason}) =>
    switch reason {
    | MissingContainer | FormSubmitFailed => Error
    | IframeLoadFailed => Warning
    }
  }
