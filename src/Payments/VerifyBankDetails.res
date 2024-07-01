@react.component
let make = (~paymentMethodType) => {
  let {publishableKey, clientSecret, iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let pmAuthConnectorsArr =
    PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(
      paymentMethodListValue.payment_methods,
    )->PmAuthConnectorUtils.getAllRequiredPmAuthConnectors

  // let callAuthExchange = publicToken => {
  //   open Promise
  //   let uri = `${endpoint}/payment_methods/auth/exchange`
  //   let updatedBody = body->Array.concat([("public_token", publicToken->JSON.Encode.string)])

  //   let headers =
  //     [("Content-Type", "application/json"), ("api-key", keys.publishableKey)]->Dict.fromArray

  //   fetchApi(
  //     uri,
  //     ~method=#POST,
  //     ~bodyStr=updatedBody->getJsonFromArrayOfJson->JSON.stringify,
  //     ~headers,
  //     (),
  //   )
  //   ->then(res => {
  //     let statusCode = res->Fetch.Response.status->Int.toString
  //     if statusCode->String.charAt(0) !== "2" {
  //       res
  //       ->Fetch.Response.json
  //       ->then(_ => {
  //         JSON.Encode.null->resolve
  //       })
  //     } else {
  //       PaymentHelpers.fetchCustomerPaymentMethodList(
  //         ~clientSecret=keys.clientSecret->Option.getOr(""),
  //         ~publishableKey=keys.publishableKey,
  //         ~optLogger=Some(logger),
  //         ~switchToCustomPod=false,
  //         ~endpoint,
  //       )
  //       ->then(customerListResponse => {
  //         let customerPaymentMethodsVal =
  //           customerListResponse
  //           ->getDictFromJson
  //           ->PaymentType.getCustomerMethods("customerPaymentMethods")
  //         setOptionValue(
  //           prev => {
  //             ...prev,
  //             customerPaymentMethods: customerPaymentMethodsVal,
  //           },
  //         )
  //         setShowFields(_ => false)
  //         res->Fetch.Response.json
  //       })
  //       ->catch(e => {
  //         Console.log2(
  //           "Unable to retrieve customer/payment_methods after auth/exchange because of ",
  //           e,
  //         )
  //         JSON.Encode.null->resolve
  //       })
  //     }
  //   })
  //   ->catch(e => {
  //     Console.log2("Unable to retrieve payment_methods auth/link because of ", e)
  //     JSON.Encode.null->resolve
  //   })
  // }

  // let _ = callAuthExchange(publicToken)

  <button
    onClick={_ =>
      PaymentHelpers.callAuthLink(
        ~publishableKey,
        ~clientSecret,
        ~iframeId,
        ~paymentMethodType,
        ~pmAuthConnectorsArr,
      )->ignore}
    style={
      width: "100%",
      padding: "20px",
      cursor: "pointer",
      borderRadius: themeObj.borderRadius,
      borderColor: themeObj.borderColor,
      borderWidth: "2px",
    }>
    {React.string("Verify Bank Details")}
  </button>
}
