open Utils

type authenticationDetails = {
  status: string,
  error: string,
}

type nextAction = {
  redirectToUrl: string,
  type_: string,
  next_action_data: option<JSON.t>,
}

type intent = {
  nextAction: nextAction,
  id: string,
  customerId: string,
  clientSecret: string,
  authenticationDetails: authenticationDetails,
}

let defaultAuthenticationDetails = {
  status: "",
  error: "",
}

let defaultNextAction = {
  redirectToUrl: "",
  type_: "",
  next_action_data: None,
}

let defaultIntent = {
  nextAction: defaultNextAction,
  id: "",
  customerId: "",
  clientSecret: "",
  authenticationDetails: defaultAuthenticationDetails,
}

let getNextAction = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      redirectToUrl: getString(json, "redirect_to_url", ""),
      type_: getString(json, "type", ""),
      next_action_data: Some(json->getDictFromDict("next_action_data")->JSON.Encode.object),
    }
  })
  ->Option.getOr(defaultNextAction)
}

let getAuthenticationDetails = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      status: getString(json, "status", ""),
      error: getString(json, "status", ""),
    }
  })
  ->Option.getOr(defaultAuthenticationDetails)
}

let itemToPMMConfirmMapper = dict => {
  {
    nextAction: getNextAction(dict, "next_action"),
    clientSecret: getString(dict, "client_secret", ""),
    customerId: getString(dict, "customer_id", ""),
    id: getString(dict, "id", ""),
    authenticationDetails: getAuthenticationDetails(dict, "authentication_details"),
  }
}
