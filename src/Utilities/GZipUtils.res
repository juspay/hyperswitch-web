type options = {to: string}
@module("pako")
external inflate: (Js.TypedArray2.ArrayBuffer.t, options) => string = "inflate"

@send
external arrayBuffer: Fetch.Response.t => Promise.t<Js.TypedArray2.ArrayBuffer.t> = "arrayBuffer"

let extractZipFromResp = resp => {
  resp
  ->Promise.then(response => response->arrayBuffer)
  ->Promise.then(async arraybuffer =>
    arraybuffer->inflate({
      to: "string",
    })
  )
  ->Promise.then(async data => data)
}

let extractJson = async resp => {
  try {
    JSON.parseExn(await extractZipFromResp(resp))
  } catch {
  | _ => JSON.Encode.null
  }
}
