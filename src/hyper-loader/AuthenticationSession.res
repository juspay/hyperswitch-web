open Types
open ErrorUtils

let initClickToPaySessionRef: ref<initClickToPaySessionInput> = ref({
  request3DSAuthentication: None,
})

let make = (
  options,
  ~clientSecret,
  ~publishableKey,
  ~logger: option<HyperLoggerTypes.loggerMake>,
) => {
  let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  let customPodUri = options->Utils.getDictFromJson->Utils.getString("customPodUri", "")
  let profileId = options->Utils.getDictFromJson->Utils.getString("profileId", "")
  let authenticationId = options->Utils.getDictFromJson->Utils.getString("authenticationId", "")
  let merchantId = options->Utils.getDictFromJson->Utils.getString("merchantId", "")

  let defaultInitAuthenticationSession = {
    initClickToPaySession: initClickToPaySessionInput => {
      initClickToPaySessionRef := initClickToPaySessionInput
      AuthenticationSessionMethods.initClickToPaySession(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~profileId,
        ~authenticationId,
        ~merchantId,
        ~initClickToPaySessionInput,
      )
    },
    getActiveClickToPaySession: () =>
      AuthenticationSessionMethods.getActiveClickToPaySession(
        ~clientSecret,
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~endpoint,
        ~profileId,
        ~authenticationId,
        ~merchantId,
        ~initClickToPaySessionInput=initClickToPaySessionRef.contents,
      ),
  }

  let clientSecretReMatch = switch GlobalVars.sdkVersion {
  | V1 => Some(RegExp.test(".+_secret_[A-Za-z0-9]+"->RegExp.fromString, clientSecret))
  | V2 => None
  }
  switch clientSecretReMatch {
  | Some(false) =>
    logger.setLogError(
      ~value=`Invalid Client Secret Format: ${clientSecret}`,
      ~eventName=AUTHENTICATION_SESSION_RETURNED,
    )
    let errorObject = Utils.getFailedSubmitResponse(
      ~errorType="INVALID_FORMAT",
      ~message="clientSecret is expected to be in format ******_secret_*****",
    )
    Exn.raiseError(errorObject->JSON.stringify)
  | _ => ()
  }

  switch authenticationId {
  | ""
  | "null" =>
    logger.setLogError(
      ~value=`Invalid AuthenticationId: ${authenticationId}`,
      ~eventName=AUTHENTICATION_SESSION_RETURNED,
    )
    let errorObject = Utils.getFailedSubmitResponse(
      ~errorType="INVALID_FORMAT",
      ~message="authenticationId is expected to be a non-empty string",
    )
    Exn.raiseError(errorObject->JSON.stringify)
  | _ => ()
  }

  logger.setLogInfo(
    ~value="Successfully initialized AuthenticationSession module",
    ~logType=DEBUG,
    ~eventName=AUTHENTICATION_SESSION_RETURNED,
  )

  defaultInitAuthenticationSession
}
