let cnpjLength = 14

let invalidCNPJs = [
  "00000000000000",
  "11111111111111",
  "22222222222222",
  "33333333333333",
  "44444444444444",
  "55555555555555",
  "66666666666666",
  "77777777777777",
  "88888888888888",
  "99999999999999",
]

let isNumeric = str => %re("/^\d*$/")->RegExp.test(str)
let isAlphanumeric = str => %re("/^[A-Z0-9]*$/")->RegExp.test(str)

// A valid CNPJ must have alphanumeric (A-Z / 0-9) characters in the first 12
// positions and strictly numeric digits in the last 2 (check digit) positions.
let isCNPJValidFormat = cnpj => {
  let base = cnpj->String.slice(~start=0, ~end=12)
  let checkDigits = cnpj->String.slice(~start=12, ~end=14)
  isAlphanumeric(base) && isNumeric(checkDigits)
}

// Convert a single character to its CNPJ numeric value.
// '0'–'9'  →  0–9   (ASCII code − 48 - 57)
// 'A'–'Z'  →  17–42 (ASCII code − 65 - 90)
let charToValue = ch => {
  let code = ch->String.charCodeAt(0)->Float.toInt
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 65 && code <= 90 {
    code - 48
  } else {
    0
  }
}

// Calculate a single CNPJ check digit from value and weight arrays.
// sum = Σ values[i] × weights[i];  remainder = sum mod 11
// result = remainder < 2 ? 0 : 11 − remainder
let calculateCheckDigit = (values: array<int>, weights: array<int>) => {
  let sum = values->Array.reduceWithIndex(0, (acc, v, i) => {
    acc + v * weights->Array.get(i)->Option.getOr(0)
  })
  let remainder = mod(sum, 11)
  remainder < 2 ? 0 : 11 - remainder
}

// Validate a CNPJ (numeric or alphanumeric) using the Modulo-11 algorithm.
// Each character is mapped to an integer via charToValue before computation.
// Works for both the classic all-digit format and the new alphanumeric format.
let validateCNPJ = cnpj => {
  let chars = cnpj->String.split("")
  let base = chars->Array.slice(~start=0, ~end=12)->Array.map(charToValue)

  let firstDigit = calculateCheckDigit(base, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
  let secondDigit = calculateCheckDigit(
    [...base, firstDigit],
    [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
  )

  let checkDigit1 = chars->Array.get(12)->Option.getOr("")->charToValue
  let checkDigit2 = chars->Array.get(13)->Option.getOr("")->charToValue

  firstDigit === checkDigit1 && secondDigit === checkDigit2
}

let isValidCNPJ = cnpj => {
  if (
    cnpj->String.length !== cnpjLength ||
    invalidCNPJs->Array.includes(cnpj) ||
    !isCNPJValidFormat(cnpj)
  ) {
    false
  } else {
    validateCNPJ(cnpj)
  }
}
