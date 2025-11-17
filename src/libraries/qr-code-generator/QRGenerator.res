type typeNumber = int // 0-40, where 0 is default
type errorCorrectionLevel = [#L | #M | #Q | #H]
type mode = [#Numeric | #Alphanumeric | #Byte | #Kanji]

type qrCode = {
  addData: (string, string) => unit,
  make: unit => unit,
  getModuleCount: unit => int,
  isDark: (int, int) => bool,
  createImgTag: (int, int) => string,
  createSvgTag: (int, int) => string,
  createDataURL: (int, int) => string,
  createTableTag: (int, int) => string,
  createASCII: (int, int) => string,
}

@module("./qr-generator.js") external make: (typeNumber, string) => qrCode = "default"
