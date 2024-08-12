<h1 align="center">Hyperswitch SDK Web Testing</h1>

## Quick Start Locally

Steps to get started with Hyperswitch-web sdk testing locally:

1. Set up hyperswitch web following the [Docs](https://github.com/juspay/hyperswitch-web?tab=readme-ov-file#hyperswitch-unified-checkout).

2. Now that you have three terminals open, spin up a fourth terminal and do `cd cypress-tests && npm start` in the main repo terminal (hyperswitch-web)
   (Note: In case Cypress is running for the first time, and cypress script runs into an error, uninstall and re install cypress as a dev module inside the cypress-tests folder)

3. Cypress should open the window to test separate flows.

💡 Note: Incase you are setting cypress for the first time and run into a cypress error, try to uninstall and re-install cypress inside cypress-tests folder by running the following commands :

```
   npm uninstall cypress
   npm install cypress --save-dev
```

## Adding test cases:

1. Test cases to be written in [Typescript](https://www.typescriptlang.org/) and type-safety to be used in all cases.<br/>
   💡 Note: Try to avoid using `any` keyword as much as possible

2. In order to add test-ids to the components follow the following cases:

   1. Create a new key in `hyperswitch-web/src/Utilities/TestUtils.res`
   2. Add the key in: `dataTestId={TestUtils.paymentMethodListTestId}` as the property for the tag to be tested.

   💡 Note: Either run the `re:build` command or keep the `re:start` command server running to generate the necessary js code
