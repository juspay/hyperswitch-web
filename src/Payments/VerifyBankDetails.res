@react.component
let make = () => {
  open Utils
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let endpoint = ApiEndpoint.getApiEndPoint()
  let (linkToken, setLinkToken) = React.useState(_ => "")

  let body = [
    ("client_secret", keys.clientSecret->Option.getOr("")->JSON.Encode.string),
    ("payment_id", keys.clientSecret->Option.getOr("")->getPaymentId->JSON.Encode.string),
    ("payment_method", "bank_debit"->JSON.Encode.string),
    ("payment_method_type", "ach"->JSON.Encode.string),
  ]

  let callAuthLink = () => {
    open Promise

    let uri = `${endpoint}/payment_methods/auth/link`

    let headers =
      [("Content-Type", "application/json"), ("api-key", keys.publishableKey)]->Dict.fromArray

    fetchApi(
      uri,
      ~method=#POST,
      ~bodyStr=body->getJsonFromArrayOfJson->JSON.stringify,
      ~headers,
      (),
    )
    ->then(res => {
      let statusCode = res->Fetch.Response.status->Int.toString
      if statusCode->String.charAt(0) !== "2" {
        res
        ->Fetch.Response.json
        ->then(_ => {
          JSON.Encode.null->resolve
        })
      } else {
        res
        ->Fetch.Response.json
        ->then(data => {
          setLinkToken(_ => data->getDictFromJson->getString("link_token", ""))
          res->Fetch.Response.json
        })
      }
    })
    ->catch(e => {
      Console.log2("Unable to retrieve payment_methods auth/link because of ", e)
      JSON.Encode.null->resolve
    })
  }

  let callAuthExchange = publicToken => {
    open Promise
    let uri = `${endpoint}/payment_methods/auth/exchange`
    let updatedBody = body->Array.concat([("public_token", publicToken->JSON.Encode.string)])

    let headers =
      [("Content-Type", "application/json"), ("api-key", keys.publishableKey)]->Dict.fromArray

    fetchApi(
      uri,
      ~method=#POST,
      ~bodyStr=updatedBody->getJsonFromArrayOfJson->JSON.stringify,
      ~headers,
      (),
    )
    ->then(res => {
      let statusCode = res->Fetch.Response.status->Int.toString
      if statusCode->String.charAt(0) !== "2" {
        res
        ->Fetch.Response.json
        ->then(_ => {
          JSON.Encode.null->resolve
        })
      } else {
        res
        ->Fetch.Response.json
        ->then(data => {
          setLinkToken(_ => data->getDictFromJson->getString("link_token", ""))
          res->Fetch.Response.json
        })
      }
    })
    ->catch(e => {
      Console.log2("Unable to retrieve payment_methods auth/link because of ", e)
      JSON.Encode.null->resolve
    })
  }

  React.useEffect(() => {
    if linkToken->String.length > 0 {
      Console.log2("linkToken", linkToken)
      let handler = Plaid.create({
        token: linkToken,
        onSuccess: (publicToken, _) => {
          let _ = callAuthExchange(publicToken)
        },
        onExit: json => {
          Console.log2("Plaid link token onExit", json)
        },
        onLoad: json => {
          Console.log2("Plaid link token onLoad", json)
        },
        onEvent: json => {
          Console.log2("Plaid link token onEvent", json)
        },
      })

      handler.open_()
    }

    None
  }, [linkToken])

  <button
    onClick={_ => callAuthLink()->ignore}
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
