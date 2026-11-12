open Types

let make = (options, ~clientSecret, ~publishableKey) => {
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  let customPodUri = options->Utils.getDictFromJson->Utils.getString("customPodUri", "")
  let profileId = options->Utils.getDictFromJson->Utils.getString("profileId", "")
  let authenticationId = options->Utils.getDictFromJson->Utils.getString("authenticationId", "")
  let merchantId = options->Utils.getDictFromJson->Utils.getString("merchantId", "")

  let defaultInitAuthenticationSession = {
    initClickToPaySession: initClickToPaySessionInput =>
      AuthenticationSessionMethods.initClickToPaySession(
        ~clientSecret,
        ~publishableKey,
        ~customPodUri,
        ~endpoint,
        ~profileId,
        ~authenticationId,
        ~merchantId,
        ~initClickToPaySessionInput,
      ),
    getActiveClickToPaySession: () =>
      AuthenticationSessionMethods.getActiveClickToPaySession(
        ~clientSecret,
        ~publishableKey,
        ~customPodUri,
        ~endpoint,
        ~profileId,
        ~authenticationId,
        ~merchantId,
      ),
  }

  defaultInitAuthenticationSession
}
