open Types

let initClickToPaySessionRef: ref<initClickToPaySessionInput> = ref({
  request3DSAuthentication: None,
})

let make = (options, ~clientSecret, ~publishableKey) => {
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
        ~customPodUri,
        ~endpoint,
        ~profileId,
        ~authenticationId,
        ~merchantId,
        ~initClickToPaySessionInput=initClickToPaySessionRef.contents,
      ),
    initClickToPayDCTPSession: params =>
      AuthenticationSessionMethods.initClickToPayDCTPSession(
        ~params,
        ~clientSecret,
        ~publishableKey,
        ~customPodUri,
        ~endpoint,
        ~profileId,
        ~authenticationId,
      ),
  }

  defaultInitAuthenticationSession
}
