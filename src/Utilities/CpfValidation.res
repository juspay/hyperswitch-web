let cpfLength = 11

let invalidCPFs = [
  "00000000000",
  "11111111111",
  "22222222222",
  "33333333333",
  "44444444444",
  "55555555555",
  "66666666666",
  "77777777777",
  "88888888888",
  "99999999999",
]

let isValidCPFFormat = (cpf: string) => {
  %re("/^\d*$/")->RegExp.test(cpf) &&
  cpf->String.length === cpfLength &&
  !(invalidCPFs->Array.includes(cpf))
}

let calculateCheckDigit = numbers => {
  let weight = numbers->Array.length + 1
  let sum = numbers->Array.reduceWithIndex(0, (acc, num, index) => {acc + num * (weight - index)})
  let remainder = mod(sum, 11)
  remainder < 2 ? 0 : 11 - remainder
}

let isValidCPF = (cpf: string) => {
  open CardValidations
  if !isValidCPFFormat(cpf) {
    false
  } else {
    let digits = cpf->String.split("")->Array.map(s => s->toInt)
    let baseCPF = digits->Array.slice(~start=0, ~end=9)

    let firstDigit = calculateCheckDigit(baseCPF)
    let secondDigit = calculateCheckDigit([...baseCPF, firstDigit])

    firstDigit === digits->Array.get(9)->Option.getOr(-1) &&
      secondDigit === digits->Array.get(10)->Option.getOr(-1)
  }
}
