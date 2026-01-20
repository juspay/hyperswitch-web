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

type token = {
  @as("type") type_: string,
  data: string,
}

type associatedPaymentMethodsObj = {
  token: token,
  paymentMethodType: string,
  paymentMethodSubType: string,
}

type associatedPaymentMethods = array<associatedPaymentMethodsObj>

type intent = {
  nextAction: nextAction,
  id: string,
  customerId: string,
  clientSecret: string,
  authenticationDetails: authenticationDetails,
  associatedPaymentMethods: associatedPaymentMethods,
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
  associatedPaymentMethods: [],
}

let defaultToken = {
  type_: "",
  data: "",
}

let defaultAssociatedPaymentMethodObj = {
  token: defaultToken,
  paymentMethodType: "",
  paymentMethodSubType: "",
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

let getAssociatedPaymentMethods = (dict, str) => {
  dict
  ->Utils.getArray(str)
  ->Array.map(item => {
    let obj = item->JSON.Decode.object->Option.getOr(Dict.make())
    let tokenObj = obj->getDictFromDict("payment_method_token")
    {
      token: {
        type_: getString(tokenObj, "type", ""),
        data: getString(tokenObj, "data", ""),
      },
      paymentMethodType: getString(obj, "payment_method_type", ""),
      paymentMethodSubType: getString(obj, "payment_method_subtype", ""),
    }
  })
}

let itemToPMMConfirmMapper = dict => {
  {
    nextAction: getNextAction(dict, "next_action"),
    clientSecret: getString(dict, "client_secret", ""),
    customerId: getString(dict, "customer_id", ""),
    id: getString(dict, "id", ""),
    authenticationDetails: getAuthenticationDetails(dict, "authentication_details"),
    associatedPaymentMethods: getAssociatedPaymentMethods(dict, "associated_payment_methods"),
  }
}
