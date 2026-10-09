open Promise
open Utils

let ddcFailure = () => handleFailureResponse(~message="Something went wrong", ~errorType="error")

let handle = (
  ~result: JSON.t,
  ~redirect,
  ~returnUrl,
  ~ctx: ConfirmOutcome.context,
  ~paymentMethod,
) => {
  let resultDict = result->getDictFromJson
  let fullscreenRequest =
    resultDict->Dict.get("fullscreenRequest")->Option.flatMap(JSON.Decode.object)
  let nextAction = PaymentConfirmTypes.getNextAction(resultDict, "next_action")
  let optLogger = Some(ctx.logger)

  switch (fullscreenRequest, nextAction.type_) {
  | (Some(request), _) =>
    let host = FullscreenHost.make(~id=`headless-${generateRandomString(8)}`)
    host.present(
      ~param=request->getString("param", ""),
      ~metadata=request->Dict.get("metadata")->Option.getOr(JSON.Encode.null),
    )
    ->then(completion => {
      host.showLoader()
      ConfirmOutcome.finish(~completion, ~redirect, ~returnUrl, ~ctx)
    })
    ->finally(() => host.dispose())
  | (None, "invoke_ddc") =>
    let host = FullscreenHost.make(~id=`headless-${generateRandomString(8)}`)
    host.showLoader()
    DdcRunner.run(~ddcData=nextAction.ddc_data, ~optLogger, ~paymentMethod)
    ->then(ddcResult =>
      switch ddcResult {
      | Redirect(url, "if_required") =>
        ConfirmOutcome.finish(~completion=OpenUrlIfRequired(url), ~redirect, ~returnUrl, ~ctx)
      | Redirect(url, _) =>
        LoggerUtils.handleLogging(
          ~optLogger,
          ~eventName=REDIRECTING_USER,
          ~value="Post DDC redirection",
          ~paymentMethod,
        )
        replaceRootHref(url, ctx.redirectionFlags)
        JSON.Encode.null->resolve
      | Failed => ddcFailure()->resolve
      }
    )
    ->finally(() => host.dispose())
  | _ => result->resolve
  }
}
