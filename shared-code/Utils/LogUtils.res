type apiLogType = Request | Response | NoResponse | Err | Method

let getApiLogValues = (
  apiLogType: apiLogType,
  url,
  statusCode,
  data,
  ~paymentMethod=?,
  ~result=?,
) => {
  switch apiLogType {
  | Request => ([("url", url->JSON.Encode.string)], [])
  | Response => (
      [("url", url->JSON.Encode.string), ("statusCode", statusCode->JSON.Encode.string)],
      [("response", data)],
    )
  | NoResponse => (
      [
        ("url", url->JSON.Encode.string),
        ("statusCode", "504"->JSON.Encode.string),
        ("response", data),
      ],
      [("response", data)],
    )
  | Err => (
      [
        ("url", url->JSON.Encode.string),
        ("statusCode", statusCode->JSON.Encode.string),
        ("response", data),
      ],
      [("response", data)],
    )
  | Method => {
      let methodValue = switch paymentMethod {
      | Some(method) => method->JSON.Encode.string
      | None => ""->JSON.Encode.string
      }
      let resultValue = switch result {
      | Some(res) => res
      | None => Dict.make()->JSON.Encode.object
      }
      ([("method", methodValue)], [("result", resultValue)])
    }
  }
}
