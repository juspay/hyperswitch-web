// Synthetic numbers with independent checksum generation for length boundaries.
// Every test number begins with the given issuer prefix; no live card data.
export function cardNumber(prefix: string, length: number) {
  const body = prefix.padEnd(length - 1, "0");
  let sum = 0;
  for (
    let index = body.length - 1, doubled = true;
    index >= 0;
    index--, doubled = !doubled
  ) {
    const digit = Number(body[index]) * (doubled ? 2 : 1);
    sum += digit > 9 ? digit - 9 : digit;
  }
  return body + ((10 - (sum % 10)) % 10);
}

export const cardLengthContracts: [string, string, number[], number[]][] = [
  ["Maestro", "6759", [12, 13, 14, 15, 16, 17, 18, 19], [3, 4]],
  ["UnionPay", "62", [16, 17, 18, 19], [3]],
  ["Interac", "4506", [16], [3]],
  ["RuPay", "652150", [16], [3]],
  ["DinersClub", "36", [14, 15, 16, 17, 18, 19], [3]],
  ["Discover", "6011", [16], [3]],
  ["Mastercard", "5555", [16], [3]],
  ["AmericanExpress", "37", [14, 15], [4]],
  ["Visa", "41", [13, 14, 15, 16, 19], [3]],
  ["CartesBancaires", "401005", [16, 17, 18, 19], [3]],
  ["SODEXO", "637513", [16], [3]],
  ["BAJAJ", "203040", [16], [3]],
  ["JCB", "3530", [16], [3]],
];
