@react.component
let make = (~bankName: string) => {
  <Icon
    size=Utils.brandIconSize iconType="banks" name={BankLogoResolver.resolveIconName(~bankName)}
  />
}

let default = make
