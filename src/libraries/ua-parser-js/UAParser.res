type browser = {name: option<string>, version: option<string>}
type os = {name: option<string>, version: option<string>}
type engine = {name: option<string>, version: option<string>}
type device = {model: option<string>, \"type": option<string>, vendor: option<string>}
type cpu = {architecture: option<string>}

type result = {
  browser: browser,
  os: os,
  device: device,
  engine: engine,
  cpu: cpu,
}

@module("./ua-parser.js") external make: unit => result = "UAParser"
