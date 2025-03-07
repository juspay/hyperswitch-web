type options = {to: string}
@module("pako")
external inflate: (Js.TypedArray2.ArrayBuffer.t, options) => string = "inflate"

@send
external arrayBuffer: Fetch.Response.t => Promise.t<Js.TypedArray2.ArrayBuffer.t> = "arrayBuffer"

let extractZipFromResp = async resp => {
  try {
    let response = await resp
    let arrayBuffer = await response->arrayBuffer
    arrayBuffer->inflate({
      to: "string",
    })
  } catch {
  | _ => ""
  }
}

let extractJson = async resp => {
  try {
    let data = await extractZipFromResp(resp)
    data->JSON.parseExn
  } catch {
  | _ => JSON.Encode.null
  }
}
