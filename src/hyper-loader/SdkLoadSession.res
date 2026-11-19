/* One correlation id per page load of HyperLoader.js, minted at module evaluation.

   The first funnel checkpoint — "the script was delivered and attached to the
   consumer app" — fires before any Hyper instance exists, so it has no session to
   belong to. Minting the id here, in a module both HyperLoader and Hyper can see,
   lets SDK_SCRIPT_LOADED and the subsequent APP_INITIATED share one `session_id`
   without introducing a second correlation column.

   A merchant-supplied `analyticsInfo.sessionID` still wins; this is only the
   default. */
let sessionId = "hyp_" ++ Utils.generateRandomString(8)
