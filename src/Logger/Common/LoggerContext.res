type t = {
  sessionId: string,
  flowId: string,
  authenticationId: string,
  paymentId: string,
  merchantId: string,
  profileId: string,
}

let makeFlowId = () => "flow_" ++ Utils.generateRandomString(12)

let empty = {
  sessionId: "",
  flowId: makeFlowId(),
  authenticationId: "",
  paymentId: "",
  merchantId: "",
  profileId: "",
}

let context = ref(empty)

let setSessionData = (
  ~sessionId=?,
  ~newFlow=false,
  ~authenticationId=?,
  ~paymentId=?,
  ~merchantId=?,
  ~profileId=?,
  (),
) => {
  let current = context.contents
  let normalizedSessionId = sessionId->Option.map(String.trim)
  let current = switch normalizedSessionId {
  | Some(sessionId) if sessionId !== current.sessionId => {
      ...empty,
      sessionId,
      flowId: makeFlowId(),
    }
  | _ => current
  }
  context := {
      sessionId: normalizedSessionId->Option.getOr(current.sessionId),
      flowId: newFlow ? makeFlowId() : current.flowId,
      authenticationId: authenticationId
      ->Option.map(String.trim)
      ->Option.getOr(current.authenticationId),
      paymentId: paymentId->Option.map(String.trim)->Option.getOr(current.paymentId),
      merchantId: switch merchantId {
      | Some(merchantId) => {
          let merchantId = merchantId->String.trim
          merchantId === "" ? current.merchantId : merchantId
        }
      | None => current.merchantId
      },
      profileId: switch profileId {
      | Some(profileId) => {
          let profileId = profileId->String.trim
          profileId === "" ? current.profileId : profileId
        }
      | None => current.profileId
      },
    }
}

let current = () => context.contents
