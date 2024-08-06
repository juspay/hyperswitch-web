<h1 align="center">Hyperswitch SDK Web Testing</h1>

## Quick Start Locally

Steps to get started with Hyperswitch-web sdk testing locally:

1. Set up hyperswitch web following the [Docs](https://github.com/juspay/hyperswitch-web?tab=readme-ov-file#hyperswitch-unified-checkout).

2. Now that you have three terminals open,opena a fourth terminal run `npm test` in the main repo terminal (hyperswitch-web)

3. Cypress should open the window to test separate flows.

## Coding patterns:

1. Test cases to be written in [Typescript](https://www.typescriptlang.org/) and type-safety to be used in all cases.
   (Note: Try to avoid using `any` keyword as much as possible)

2. In order to add test-ids to the components follow the following cases:
   1. Create a new key in `hyperswitch-web/src/Utilities/TestUtils.res`
   2. Add the key in: `dataTestId={TestUtils.paymentMethodListTestId}` as the property for the tag to be tested.
