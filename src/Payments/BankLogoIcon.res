/*
 Renders the bank logo for a saved bank_redirect method.

 Kept in its own module - reached only through BankLogoIconLazy - so BankLogoResolver, and with
 it BankLogoMapping.json, stays out of the entry bundles; every other saved-method brand is a
 static icon name. The logos also live in their own sprite (public/icons/banks.svg) rather than
 the prefetched core sprite, so they download only when this component renders. Every id
 BankLogoResolver can return - the values of BankLogoMapping.json plus `defaultIcon` - must
 exist in that sprite.
 */
@react.component
let make = (~bankName: string) => {
  <Icon
    size=Utils.brandIconSize iconType="banks" name={BankLogoResolver.resolveIconName(~bankName)}
  />
}

let default = make
