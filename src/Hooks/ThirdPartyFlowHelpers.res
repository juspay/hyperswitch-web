let useIsThirdPartyFlow = () => {
  open Utils
  let sessions = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)

  React.useMemo(() => {
    let sessionObj = switch sessions {
    | Loaded(val) => val
    | _ => Dict.make()->JSON.Encode.object
    }
    let dict = sessionObj->getDictFromJson
    let applePaySessionObj = SessionsType.itemToObjMapper(dict, ApplePayObject)
    let googlePaySessionObj = SessionsType.itemToObjMapper(dict, GooglePayThirdPartyObject)
    let applePayToken = SessionsType.getPaymentSessionObj(
      applePaySessionObj.sessionsToken,
      ApplePay,
    )
    let gPayToken = SessionsType.getPaymentSessionObj(googlePaySessionObj.sessionsToken, Gpay)

    let applePayThirdPartyToken = switch applePayToken {
    | ApplePayTokenOptional(applePayThirdPartyToken) => applePayThirdPartyToken
    | _ => None
    }

    let googlePayThirdPartyToken = switch gPayToken {
    | GooglePayThirdPartyTokenOptional(googlePayThirdPartyToken) => googlePayThirdPartyToken
    | _ => None
    }

    let isGooglePayDelayedSessionFlow =
      googlePayThirdPartyToken
      ->Option.map(token =>
        token->getDecodedBoolFromJson(
          tokenObj => tokenObj->Dict.get("delayed_session_token"),
          false,
        )
      )
      ->Option.getOr(false)

    let isApplePayDelayedSessionFlow =
      applePayThirdPartyToken
      ->Option.map(token =>
        token->getDecodedBoolFromJson(
          tokenObj => tokenObj->Dict.get("delayed_session_token"),
          false,
        )
      )
      ->Option.getOr(false)

    (isApplePayDelayedSessionFlow, isGooglePayDelayedSessionFlow)
  }, [sessions])
}
