let useIsApplePayThirdPartyFlow = () => {
  open Utils
  let sessions = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)

  React.useMemo(() => {
    let sessionObj = switch sessions {
    | Loaded(val) => val
    | _ => Dict.make()->JSON.Encode.object
    }
    let dict = sessionObj->getDictFromJson
    let applePaySessionObj = SessionsType.itemToObjMapper(dict, ApplePayObject)
    let applePayToken = SessionsType.getPaymentSessionObj(
      applePaySessionObj.sessionsToken,
      ApplePay,
    )

    let applePayThirdPartyToken = switch applePayToken {
    | ApplePayTokenOptional(applePayThirdPartyToken) => applePayThirdPartyToken
    | _ => None
    }

    let isApplePayThirdPartyFlow =
      applePayThirdPartyToken
      ->Option.getOr(JSON.Encode.null)
      ->JSON.Decode.object
      ->Option.getOr(Dict.make())
      ->Dict.get("delayed_session_token")
      ->Option.getOr(JSON.Encode.null)
      ->JSON.Decode.bool
      ->Option.getOr(false)

    isApplePayThirdPartyFlow
  }, sessions)
}
