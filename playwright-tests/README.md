# Hyperswitch Web SDK — end-to-end tests

Playwright tests that drive the real web SDK (HyperLoader + payment element iframes) inside the
demo shop (`Hyperswitch-React-Demo-App`). The suite runs in two tiers:

- **hermetic**: every router response is served from `recordings/`, so no sandbox, no keys and no
  network. Fast, deterministic, and the pull-request gate.
- **live**: the same specs against a real router (sandbox, integ or a local one) with real
  connectors, redirects, 3DS challenges and popups. Runs on `main` and nightly.

One spec serves both tiers: tests are hermetic-capable unless tagged `@live`, and every hermetic
mutator is a no-op on live.

```
playwright-tests/
├── playwright.config.ts        projects: hermetic, live-setup, live, live-webkit
├── setup/
│   ├── credentials.setup.ts    live-setup project: loads or provisions merchant credentials
│   └── merchant-setup.js       creates merchant, API key, one profile + MCA per connector
├── fixtures/                   everything specs import (import from "../../fixtures")
│   ├── index.ts                test, expect + every export below
│   ├── sdk.ts                  payment-element frame helpers (sdk fixture)
│   ├── checkout.ts             create payment + open demo shop (checkout fixture), getClientURL
│   ├── api.ts                  Node-side router calls (api fixture)
│   ├── helpers.ts              cross-group spec helpers: typeCard, confirm capture, redirects, ...
│   ├── payment-body.ts         immutable paymentBody() builder, confirmBody(), test card numbers
│   ├── cards.ts, types.ts, test-data.ts, connectors.ts, test-ids.ts
│   ├── credentials.ts, env.ts, demo-shop.ts
│   └── hermetic/               engine (context.route replay), recorder (RECORD=1), types
├── recordings/                 router responses for the hermetic tier
│   ├── base/*.json             shared defaults: card checkout on the Stripe profile
│   ├── <group>/_group.json     optional, one per e2e group
│   ├── <group>/<spec>.json     optional, one per spec file (auto-loaded)
│   └── _recorded/              RECORD=1 output (gitignored, review before copying)
└── e2e/
    ├── 01-sdk-core             init, lifecycle, layouts, locales, themes, errors, submit states
    ├── 02-cards                validation, formatting, 3DS / no-3DS per connector, saved cards, mandates
    ├── 03-bank-transfers       redirect bank transfers (Trustpay, Stripe, Fiuu)
    ├── 04-alternative-payments crypto, wallets, vouchers, Interac, Klarna, popups
    └── 05-external-3ds         Redsys, Netcetera, Juspay 3DS
```

## Running

Prerequisites (repo root): `npm install`, `git submodule update --init`, and
`cd Hyperswitch-React-Demo-App && npm install`. Then:

```bash
cd playwright-tests
npm ci
npx playwright install chromium          # add webkit for live-webkit
```

### Hermetic

```bash
npm run test:hermetic                                          # everything not tagged @live
npx playwright test --project=hermetic e2e/02-cards/01-card-validation.spec.ts
npx playwright test --project=hermetic -g "RuPay" --headed
npm run show-report                                            # HTML report; traces kept on failure
```

Playwright starts the two servers it needs (`webServer` in the config) and reuses them if they are
already up (never on CI):

| server      | command (cwd)                                                               | default URL             |
| ----------- | --------------------------------------------------------------------------- | ----------------------- |
| sdk         | `npm run re:build && npx webpack serve --config webpack.dev.js` (repo root) | `http://localhost:9150` |
| demo-client | `npx webpack serve --config webpack.dev.js` (Hyperswitch-React-Demo-App)    | `http://localhost:9160` |

The ports are deliberately not the dev defaults (9050/9060/5252), so a test run never collides with,
or silently reuses, a developer's dev servers. The demo app's node server (`server.js`) is not
started: its only test-mode duties, `/payments/config` and `/payments/urls`, are answered by the
harness in every project (`fixtures/demo-shop.ts`), which also sidesteps its 300 req/min rate limit.

To keep the servers warm between runs:

```bash
# terminal 1 — repo root
npm run re:build && PORT=9150 ENV_SDK_URL=http://localhost:9150 sdkEnv=local npx webpack serve --config webpack.dev.js
# terminal 2 — Hyperswitch-React-Demo-App
DEMO_PORT=9160 DEMO_SERVER_PORT=5352 npx webpack serve --config webpack.dev.js
# terminal 3 — playwright-tests
npm run test:hermetic
```

### Live

```bash
# First run: provisions a fresh merchant and caches it in playwright-tests/test-credentials-<env>.json
ADMIN_API_KEY=... CONNECTOR_AUTH_FILE_PATH=./creds.json npm run test:sandbox
# Later runs reuse the cached merchant (delete the file to get a new one)
npm run test:sandbox

npm run test:integ | npm run test:local       # TEST_ENV=integ|local (LOCAL_API_URL for local)
npm run test:webkit                           # live-webkit project (Safari engine)
npm run test:record                           # live + RECORD=1, see "Recording"
```

`live` and `live-webkit` depend on the `live-setup` project (`setup/credentials.setup.ts`), which
acts as the global setup and never runs for `--project=hermetic`. It uses the credentials file if
it exists and has profile IDs for stripe/adyen/fiuu/trustpay; otherwise it calls
`setupAllCredentials()` from `setup/merchant-setup.js` (needs `ADMIN_API_KEY` +
`CONNECTOR_AUTH_FILE_PATH`) and writes the file. Credentials only ever live in that one file:
`CREDENTIALS_OUTPUT_PATH` if set, else `playwright-tests/test-credentials-<env>.json` (gitignored,
as is `playwright-tests/creds.json`).

To provision a merchant without running tests:

```bash
TEST_ENV=sandbox HYPERSWITCH_API_URL=https://sandbox.hyperswitch.io \
ADMIN_API_KEY=... CONNECTOR_AUTH_FILE_PATH=./creds.json node setup/merchant-setup.js
```

### Environment variables

| variable                                    | default                                        | meaning                                                                    |
| ------------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------- |
| `TEST_ENV`                                  | `sandbox`                                      | `sandbox` \| `integ` \| `local`                                            |
| `LOCAL_API_URL`                             | `http://localhost:8080`                        | router URL when `TEST_ENV=local`                                           |
| `CREDENTIALS_OUTPUT_PATH`                   | `playwright-tests/test-credentials-<env>.json` | live credentials file (read, and written by live-setup)                    |
| `ADMIN_API_KEY`, `CONNECTOR_AUTH_FILE_PATH` | none                                           | needed only when live-setup must create a merchant                         |
| `SDK_PORT` / `SDK_URL`                      | `9150` / `http://localhost:9150`               | SDK dev server                                                             |
| `DEMO_PORT` / `CLIENT_BASE_URL`             | `9160` / `http://localhost:9160`               | demo shop                                                                  |
| `DEMO_SERVER_PORT`                          | `5352`                                         | demo shop's `/payments` proxy target (nothing needs to listen)             |
| `SDK_ENV`                                   | `local`                                        | `sdkEnv` for the SDK dev build                                             |
| `PW_SKIP_WEBSERVER=1`                       | off                                            | don't start or check servers (you run them)                                |
| `PW_REUSE_SERVERS=0\|1`                     | `1` locally, `0` on CI                         | reuse already-running servers                                              |
| `PW_WORKERS`                                | Playwright default, `4` on CI                  | total workers, a number or `"50%"`                                         |
| `PW_LIVE_WORKERS`                           | `2`, `4` on CI                                 | max concurrent files on the live projects                                  |
| `PW_OUTPUT_DIR` / `PW_HTML_REPORT_DIR`      | `test-results` / `playwright-report`           | give each concurrent run on one checkout its own (Playwright empties them) |
| `RECORD=1`                                  | off                                            | save router responses during live runs                                     |
| `CI`                                        | none                                           | forbids `.only`, adds the GitHub reporter, disables server reuse           |

## Projects, tags and parallelism

| project       | browser                                                      | runs                                  | retries | trace               | parallelism                                                             |
| ------------- | ------------------------------------------------------------ | ------------------------------------- | ------- | ------------------- | ----------------------------------------------------------------------- |
| `hermetic`    | Chromium                                                     | all tests **except `@live`**          | 0       | `retain-on-failure` | `fullyParallel`: every test isolated                                    |
| `live`        | Chromium with a desktop UA (Netcetera's ACS blocks headless) | all tests **except `@hermetic-only`** | 1       | `on-first-retry`    | files in parallel (`PW_LIVE_WORKERS`), tests in a file serial, in order |
| `live-webkit` | WebKit                                                       | same as live                          | 1       | `on-first-retry`    | same as live                                                            |

**Tags.** Use Playwright's `tag` option, with a comment giving the reason:

```ts
test("redirects to the Trustpay iDEAL page", { tag: "@live" }, async ({ ... }) => { ... });
test.describe("Netcetera 3DS", { tag: "@live" }, () => { ... });        // whole block
test("shows the router's 500 message", { tag: "@hermetic-only" }, ...); // needs an injected failure
```

- `@live`: needs something a recording can't stand in for — a real connector redirect or bank page,
  a real 3DS/ACS challenge, a cross-origin third-party flow, or an outcome only meaningful when a
  real connector produces it.
- `@hermetic-only`: injects responses the real router can't be made to return (5xx, malformed
  bodies, timeouts).
- Untagged: renders the SDK, validates input, submits, and checks what the SDK does with the
  response. Runs in both tiers; live additionally checks the real outcome.

**Isolation.** Each test gets a fresh browser context and, in hermetic mode, its own engine, intent
and call log, so hermetic tests can't race. Live tests share one merchant, and each spec uses its own
`customer_id`, so saved cards and mandates from one file never leak into another running
concurrently. Tests within a file run in order on live; if they depend on each other (test 2 uses the
card saved by test 1), add `test.describe.configure({ mode: "serial" })` so hermetic keeps them
ordered too — or better, give each test a fixture that already has the saved card.

## CI

Two workflows, one job each; parallelism comes from Playwright workers inside the job.

| workflow                   | triggers                                                                                  | job                                                                                                                                                                                                                                                                                                            | artifacts                                                               |
| -------------------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `playwright-pr-checks.yml` | pull requests, merge queue, pushes to `main`                                              | `hermetic`: `npx playwright test --project=hermetic --retries=0`. No secrets, no environment; superseded PR runs are cancelled                                                                                                                                                                                 | `playwright-report-hermetic` (14 days), `traces-hermetic` on failure    |
| `playwright-live-e2e.yml`  | pushes to `main`, nightly 21:30 UTC, manual (`test_env`: sandbox/integ, `include_webkit`) | `live` (environment `Testing`): decrypts `creds.json` from S3 into the runner's temp dir, then runs `--project=live` (plus `--project=live-webkit` nightly or on request). `live-setup` creates a fresh merchant in-process; its credentials file is written outside the workspace, so keys are never uploaded | `playwright-report-live-<env>`, `traces-live-<env>` on failure (7 days) |

Both use Node 20, cache browsers keyed on the locked Playwright version, and compile ReScript in its
own step. Live secrets: `CYPRESS_ADMIN_KEY` (passed as `ADMIN_API_KEY`), `CONNECTOR_CREDS_AWS_*`,
`CONNECTOR_CREDS_S3_BUCKET_URI`, `CONNECTOR_AUTH_PASSPHRASE`.

## Fixture API

```ts
import {
  test,
  expect,
  testIds,
  paymentBody,
  stripeCards,
  connectorEnum,
} from "../../fixtures";
```

### `checkout` (test)

| member                                 | notes                                                                                                                                                                                                                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `open(opts?): Promise<OpenedCheckout>` | Creates the payment and opens the demo shop on it. `opts`: `body?` (default `paymentBody()`), `locale?`, `theme?`, `layout?: string \| object`, `options?: object`, `publishableKey?`, `profileId?`, `waitForReady?`. Returns `{ paymentId, clientSecret, profileId, body, response, url }` |
| `createPaymentIntent(body?)`           | `POST /payments` with the secret key; fills in the Stripe profile if `body.profile_id` is empty. Hermetic: no network, returns a fake `pay_hermetic…` id/secret                                                                                                                             |
| `url(intentOrClientSecret, opts?)`     | Demo shop URL (`isTestMode=true&clientSecret&publishableKey&profileId&locale&theme&layout&options`)                                                                                                                                                                                         |
| `lastIntent`                           | Last intent created in this test                                                                                                                                                                                                                                                            |

`getClientURL(clientSecret, publishableKey, { profileId, locale, theme, layout, options }, baseUrl?)`
is exported too. `isTestMode=true` makes the demo app take keys and client secret from the URL.

### `sdk` (test): frames and input

```
page
├─ #orca-payment-element-iframeRef-orca-elements-payment-element-payment-element   sdk.paymentElement
│    tabs / payment-method list + dropdown, billing & dynamic fields, saved methods, "Add new card"
│  └─ iframe[id^="orca-payment-element-iframeRef-"][src*="componentName=paymentMethodsSDK"]  sdk.cardFields
│       card number / expiry / CVC and their ".Error.pt-1" messages (first *visible* such iframe;
│       the saved-card CVC lives in a second one)
└─ #orca-fullscreen   3DS / QR / voucher overlays → sdk.nestedIFrame(selector)
```

Playwright can't put frame locators inside `locator.or()`, so lookups are split by frame:

| member                                                                      | notes                                                                                                                                                                                            |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `paymentElement`, `cardFields`                                              | the two `FrameLocator`s                                                                                                                                                                          |
| `field(testId)`                                                             | **sync**. Card number / expiry / CVC resolve in `cardFields`, every other test id in `paymentElement` (`CARD_FRAME_TEST_IDS`)                                                                    |
| `find(css)`, `findInCard(css)`, `text(textOrRegExp, {exact?})`              | outer frame / card frame / text in the outer frame                                                                                                                                               |
| `await locate(css)`, `await locateTestId(id)`                               | **async** "either frame" lookup: polls both frames, returns whichever matches (the outer frame's after the timeout)                                                                              |
| `cardErrors`, `formErrors`                                                  | `.Error.pt-1` in the card frame / outer frame                                                                                                                                                    |
| `submitButton`, `submit()`                                                  | the demo shop's `#submit` ("Pay now"), top-level page                                                                                                                                            |
| `waitForReady({timeout?})`                                                  | outer iframe, card iframe and card number input attached                                                                                                                                         |
| `type(testId, text, {delay?})`                                              | key by key, no clearing                                                                                                                                                                          |
| `safeType(testId, text, {delay = 50})`                                      | waits visible + enabled, clears, types                                                                                                                                                           |
| `enterCardDetails(card)` / `payWithCard(card)`                              | number, `card_exp_month + card_exp_year`, CVC via `safeType` / plus `waitForReady` and `submit`. Assert the outcome yourself                                                                     |
| `selectPaymentMethod(name)`                                                 | clicks "Add new card" if saved methods show, then `name`                                                                                                                                         |
| `selectPaymentMethodOrSkip(name, {timeout = 15000, onMissing?})`            | waits for `name`; if it never appears, logs the router's `payment_methods_enabled` and **skips** the test. Otherwise clicks the tab or picks it in the dropdown (`PAYMENT_METHOD_SELECT_VALUES`) |
| `clickAddNewCardIfPresent()`                                                | returns whether it clicked                                                                                                                                                                       |
| `await nestedIFrame(selector)`                                              | a frame inside `#orca-fullscreen`, once visible and non-empty                                                                                                                                    |
| `testDynamicFields(customerData, requiredFields, idsToRemove?, isThreeDS?)` | fills every required field; get `requiredFields` from `api.cardRequiredFields(clientSecret)`                                                                                                     |

### `api` (test): Node-side router calls

Hermetic: answered by the same engine and recordings as the browser. Live: Node's global `fetch`,
**not** Playwright's `request` fixture, because `APIRequestContext` puts every call, `api-key`
header included, in traces and the uploaded HTML report. A redacted `api.callLog` is attached as
`api-calls.json` to failed tests instead. Never log `credentials.secretKey` or a full client secret
(`redactClientSecrets()` in `fixtures/api.ts` helps).

| member                                                                                                              | notes                                                                               |
| ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `createPaymentIntent(body)`                                                                                         | what `checkout` uses                                                                |
| `retrievePayment(paymentId, {forceSync = true})`                                                                    | `GET /payments/:id` with the secret key                                             |
| `pollPaymentStatus(paymentId, expectedStatus, {timeoutMs = 20000, intervalMs = 2000})`                              | throws on timeout. Hermetic: reads the intent status set by confirm's `intentPatch` |
| `clientList`, `accountPaymentMethods`, `cardRequiredFields(clientSecret, type = "debit")`, `describePaymentMethods` | debugging and dynamic-field helpers                                                 |
| `call(method, path, {apiKey?, data?})`                                                                              | anything else                                                                       |

### `credentials`, `mode` (worker)

`credentials.publishableKey`, `.secretKey`, `.merchantId`, `.connectorProfileIds`,
`.profileId(connectorEnum.X)` and `.defaultProfileId` (Stripe). `connectorEnum` values are the keys
`merchant-setup.js` writes; `PLAID` isn't provisioned yet, so it is `undefined` on live. In hermetic
mode everything is fake (`pk_snd_hermetic…`, `pro_hermetic_<connector>`). `mode` is `"hermetic"` or
`"live"`.

### `hermetic` (test)

Every mutator is a **no-op on live**. The fixtures extend `context`, so every browser context a test
uses (`page`, popups, `sdk`, `checkout`) gets the demo-shop config routes and, in hermetic mode, the
engine. A test that only uses `api`, `hermetic` or `credentials` never creates a browser context.

| member                                           | notes                                                                                                                                                                                                                                    |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`                                        | `true` on the hermetic project                                                                                                                                                                                                           |
| `use(...routes)`                                 | per-test routes with top priority                                                                                                                                                                                                        |
| `override(name, patch \| (route) => route)`      | object: deep-merged into the effective route's `body` (arrays replaced, `undefined` deletes). Function: gets a clone, returns the new route                                                                                              |
| `load(file)`                                     | extra fixture file (relative to `recordings/`) as a new top layer                                                                                                                                                                        |
| `calls(nameOrRegExp?)`, `await waitForCall(...)` | requests the engine served: `{ name, method, url, path, requestBody, status, responseBody, matched, source }`. A string matches the route name, a RegExp matches `"METHOD url"`. `source` is the fixture file, `"stub"` or `"unmatched"` |
| `intent`, `setIntent(patch)`                     | the fake payment (`payment_id`, `client_secret`, `status`, plus the create body)                                                                                                                                                         |
| `unmatched`                                      | router requests nothing matched (answered 404)                                                                                                                                                                                           |

Spec-level extra files: `test.use({ hermeticFixtures: ["02-cards/saved-card-customer.json"] })`.

### Helpers and data

`fixtures/helpers.ts` (hermetic-only checks are no-ops live):

| helper                                                                                         | notes                                                                                                       |
| ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `typeCard(sdk, card)`                                                                          | number, month, year, CVC key by key, no clearing (`sdk.enterCardDetails()` clears)                          |
| `waitForConfirm(page)`, `isConfirmResponse(r)`                                                 | the SDK's `POST /payments/:id/confirm` response, both tiers                                                 |
| `expectConfirmedWith(hermetic, ...fragments)`                                                  | hermetic: the confirm body contains each fragment (whitespace stripped)                                     |
| `slowConfirm(hermetic, ms)`                                                                    | hermetic: delay confirm so the processing state is observable                                               |
| `payAndCaptureConfirm(page, sdk, hermetic)`, `submitAndCaptureConfirm(page, hermetic, fn)`     | click Pay, return `{ request, status, body }` of the confirm                                                |
| `expectConfirmRequest(confirm, { payment_method, payment_method_type, payment_method_data? })` | partial match on the confirm body                                                                           |
| `expectRedirectedTo(page, hermetic, urlPattern, confirm?)`                                     | left the demo shop for `urlPattern`; hermetic: exactly `next_action.redirect_to_url`, served by the fixture |
| `expectRedirectedToNextAction(hermetic)`                                                       | hermetic: confirm asked for a redirect and the SDK requested exactly that URL                               |
| `expectCheckoutTitle(page)`, `expectPaymentElementLoaded(page, sdk)`                           | page title rendered / payment element iframe loaded                                                         |
| `captureConsoleErrors(page)`                                                                   | records explicit `console.error` calls in the top window. Call before `goto`                                |

Helpers used by one group stay in that group (`e2e/01-sdk-core/core-a-helpers.ts`,
`e2e/05-external-3ds/threeds-helpers.ts`).

Data: `paymentBody(overrides?)` (an `undefined` override removes the key), `withoutKeys()`,
`DEFAULT_PAYMENT_BODY`, `confirmBody()`, test card numbers (`payment-body.ts`); `stripeCards`,
`trustpayCards`, `redsysCards`, `cybersourceCards`, `bankOfAmericaCards`, `cobadgeCards`
(`cards.ts`); `testCustomer`, `connectorEnum`; and `testIds`, which comes straight from the ReScript
output `src/Utilities/TestUtils.bs.js` (gitignored; the config runs `npm run re:build` if it is
missing). Never copy the test ids by hand.

Specs that need no fixture at all (e.g. `e2e/01-sdk-core/locale-strings.spec.ts`, a browser-free
data table) import `test` from `@playwright/test` directly, which keeps them independent of live
credentials.

## Hermetic fixtures

In hermetic mode the `context` fixture installs `context.route()` on every browser context, covering
the page, all iframes and popups:

- The SDK and demo shop origins go to the local servers, except `/assets/v1/jsons/location/*`
  (country/state data), which is served from a fixture if one matches and otherwise gets a plain-text
  404 so the SDK uses its bundled data. (A JSON 404 would be decoded as an empty country list.)
- **Every other request** is matched against the loaded routes. Unmatched third-party scripts and
  styles become empty 200s, documents a blank page (logged with `source: "stub"`, so a navigation can
  be asserted without a route), images/fonts a 404, logging calls `200 {}`. Anything else — normally
  a router call — gets `404 {"error":{"type":"hermetic_unmatched"}}`, a warning, and a
  `hermetic-unmatched.txt` attachment. Failed tests also get `hermetic-calls.json`.
- `path` routes ignore the host and strip the router base path (`/api` on integ). On
  `*.hyperswitch.io` `/api` is always stripped: the SDK's fullscreen frames call
  `GlobalVars.backendEndPoint`, not the merchant's backend, and base routes must still answer them.
- `checkout.open()` creates a fake intent (`pay_hermetic…`, status `requires_payment_method`, plus
  the create body). Recordings are templated with it, so ids always line up.

### Layers (lowest priority first)

1. `recordings/base/*.json`: card checkout on the Stripe profile — `clientList` (card, no saved
   methods), `sdkConfigs` (no `raw_configs`, so no superposition required fields), `sessionTokens` (no
   wallets), `confirm` (`succeeded`), `retrieve`, `accountPaymentMethods`, `customerPaymentMethods`.
2. `recordings/<group>/_group.json`: optional.
3. `recordings/<group>/<spec>.json`: optional, **auto-loaded** for `e2e/<group>/<spec>.spec.ts`.
4. `test.use({ hermeticFixtures: [...] })`: explicit extra files.
5. `hermetic.use()` / `hermetic.override()`: per test, at runtime.

The first matching route wins, searching the top layer first. To change a base response for one
spec, add a route with the **same name, method and path** to the spec's file; shared files never
need editing.

### File format

<!-- prettier-ignore -->
```jsonc
{
  "_source": "synthetic",          // or "recorded" (RECORD=1). Required, so reviewers know what they trust
  "_note": "why this exists / what it simulates",
  "routes": [
    {
      "name": "clientList",                        // stable name: override(), calls(), reports
      "method": "GET",                             // default GET; "*" = any
      "path": "/payments/:paymentId/client",       // router path; host and /api ignored
      // "url": "https://pay.example.com/**",      // alternative: full-URL glob for non-router hosts
      "match": {                                   // optional, all templated
        "query":  { "force_sync": "true" },
        "body":   { "payment_method_type": "klarna" },     // deep-partial match on the request body
        "intent": { "profile_id": "{{profiles.trustpay}}" } // deep-partial match on the fake intent
      },
      "status": 200,
      "headers": {}, "contentType": "application/json",
      "times": 1,                                  // serve N times, then fall through
      "delayMs": 0,
      "intentPatch": { "status": "{{response.status}}" },  // applied to the intent after serving
      "body": { "intent_data": { "amount": "{{intent.amount}}", "billing": "{{intent.billing}}" } }
    }
  ]
}
```

A string that is exactly `"{{path}}"` is replaced by the raw JSON value (dropped if `undefined`);
placeholders inside longer strings are interpolated. Context: `intent.*`, `publishable_key`,
`merchant_id`, `profiles.<connector>`, `api_url`, `now`, `request.body.*`, `request.query.*`, and
`response.*` (in `intentPatch` only). Route names used by base and the recorder: `clientList`,
`sdkConfigs`, `sessionTokens`, `confirm`, `completeAuthorize`, `eligibility`,
`threeDsAuthentication`, `calculateTax`, `postSessionTokens`, `retrieve`, `accountPaymentMethods`,
`customerPaymentMethods`, `pollStatus`.

```ts
// A decline in both tiers: live gets it from the connector, hermetic fakes the router's answer.
test("shows the decline", async ({ checkout, sdk, hermetic, page }) => {
  hermetic.override("confirm", {
    status: "failed",
    error_code: "card_declined",
    error_message: "Your card was declined.",
  });
  await checkout.open();
  await sdk.payWithCard(DECLINING_CARD);
  await expect(page.locator("#payment-message")).toBeVisible();
});

// A router error the sandbox can't produce on demand -> @hermetic-only.
test(
  "surfaces a confirm error",
  { tag: "@hermetic-only" },
  async ({ checkout, sdk, hermetic, page }) => {
    hermetic.use({
      name: "confirm",
      method: "POST",
      path: "/payments/:paymentId/confirm",
      status: 400,
      body: {
        error: {
          type: "invalid_request",
          message: "Hermetic says no",
          code: "IR_00",
        },
      },
    });
    await checkout.open();
    await sdk.payWithCard(stripeCards.successCard);
    await expect(page.locator("#payment-message")).toContainText(
      "Hermetic says no",
    );
  },
);
```

## Recording

```bash
RECORD=1 npx playwright test --project=live e2e/02-cards/07-saved-cards.spec.ts
```

Router responses (API origin only) of every test are written to
`recordings/_recorded/<group>/<spec>/<test-title>.json` (gitignored), already in fixture format: ids
templated (`{{intent.payment_id}}`, `{{profiles.<connector>}}`, …), secrets and tokens redacted,
known endpoints named, repeated calls ordered with `times`, and `confirm` given
`intentPatch: {status: "{{response.status}}"}`. Review the file for anything the redactor missed,
copy the routes you need into `recordings/<group>/<spec>.json`, set `"_source": "recorded"`, and run
the hermetic project. Location data is not recorded.

All fixtures in `recordings/` are currently **synthetic** (hand-written from the SDK's decoders); see
[Open follow-ups](#open-follow-ups).

## Writing a new test

1. Put the spec in the matching `e2e/<group>/`, import everything from `../../fixtures`, and build
   the exact payment body it needs with `paymentBody({...})` — nothing is shared between tests.
2. Give the spec its own `customer_id` if it saves cards or creates mandates.
3. Wait for conditions, never for time: locators and web-first assertions (`toBeVisible`,
   `toHaveValue`, `toHaveURL`, `expect.poll`) retry on their own.
4. Run it hermetic first: `npx playwright test --project=hermetic <file>`. If a router call is
   unmatched, add a route to `recordings/<group>/<spec>.json` (or record one, above).
5. Tag it `@live` / `@hermetic-only` only when needed, with a comment saying why.
6. Before pushing: `npx tsc --noEmit`, `npx playwright test --list`, `npm run format`.

Code goes where it is used: a helper for one spec stays in the spec, one for a group in
`e2e/<group>/*-helpers.ts`, one for several groups in `fixtures/helpers.ts`.

**Gotchas**

- The SDK needs `ENV_SDK_URL` set to the URL it is served from, or HyperLoader loads its iframes
  from `localhost:9050`. The config sets it.
- `sdk.field()` is routed by test id. If the SDK moves a field into another frame, use
  `sdk.locateTestId()` or update `CARD_FRAME_TEST_IDS`.
- Base `sdkConfigs` has no `raw_configs`, so no billing/dynamic required fields render; specs that
  test those need their own `sdkConfigs` route.
- In `page.route()` handlers use `route.fallback()`, never `route.continue()`, so the hermetic engine
  still answers what you don't handle. Page routes beat the context route, so `route.abort()` /
  `route.fulfill()` work in both tiers.
- Never run `npm run re:format` in this repo.

## Known SDK issues found by this suite

- **Italian `localeDirection` is `"lrt"`** (`src/LocaleStrings/ItalianLocale.res`), not `"ltr"`.
  The `dir` attribute gets an invalid value, which browsers ignore, so it only looks right by accident.
- **`fields.billingDetails` is ignored for card dynamic fields.** Superposition-driven required
  fields (`DynamicFields.res`) never read the option; only the legacy `*PaymentInput` components do.
  `billing-fields.spec.ts` › "should hide the billing name field when set to never" is marked
  `test.fail()`; remove that line when the SDK is fixed. A "field does not exist" check that runs
  before the fields render passes falsely, so the spec waits for them first.
- **A failed payment-methods fetch is never retried.** After one network failure of
  `GET /payments/:id/client` the element stays on "Oops, something went wrong!" instead of recovering;
  `sdk-error-handling-test.spec.ts` › "should recover from temporary network failures" therefore
  only asserts the outer iframe.
- **Fullscreen frames ignore `customBackendUrl`.** QR polling, 3DS (`complete_authorize`,
  `3ds/authentication`) and Plaid status calls go to `GlobalVars.backendEndPoint`
  (`https://beta.hyperswitch.io/api` in local/sandbox builds) instead of the merchant's backend. Seen
  in the local dev build; needs confirmation on a real sandbox/prod build.
- **The country/state data loader ignores the HTTP status** (`S3Utils`): an error response with a
  JSON body is decoded as data, so a `404 {}` empties the Country/State dropdowns instead of falling
  back to the bundled list.

## Open follow-ups

1. **First green live run on sandbox.** The live tier has never run yet: dispatch
   `playwright-live-e2e.yml` manually. It needs the `CYPRESS_ADMIN_KEY` secret in the `Testing`
   environment; the name is legacy and can be renamed in GitHub settings together with the workflow.
2. **Re-record the synthetic fixtures** with `RECORD=1` on sandbox, review, and flip `_source` to
   `"recorded"` (base first, then per spec).
3. **Provision PayPal and Klarna with the SDK flow** (`invoke_sdk_client` + session tokens) and a
   Plaid open-banking connector in `setup/merchant-setup.js`, so the `@live` popup tests in
   `popups.spec.ts` stop skipping.
4. **Make the Playwright checks required** in branch protection: `hermetic` on PRs; watch `live` on
   `main`.
5. **Point the hyperswitch-demo-store Test Coverage tool** at this suite.

## Appendix: coming from Cypress

Specs are plain `async` functions: every step is `await`ed, and locators and assertions retry until
their condition holds, so there is no command queue, no `.then()` chaining and no `cy.wait(ms)`.

| Cypress                                                     | Playwright                                                                                              |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `describe` / `it` / `beforeEach`                            | `test.describe` / `test` / `test.beforeEach(async ({ checkout }) => …)`                                 |
| `cy.visit(url)` after creating an intent                    | `const { paymentId, clientSecret } = await checkout.open({ body, locale, layout })`                     |
| `cy.get(iframe).its("0.contentDocument")…find(sel)`         | `sdk.field(testId)`, `sdk.find(sel)`, or `await sdk.locate(sel)` when unsure which frame                |
| `.type(v)` / `.clear()` / `.select(v)`                      | `await sdk.type(id, v)` / `await sdk.field(id).clear()` / `await sdk.field(id).selectOption(v)`         |
| `.should("have.value", v)`                                  | `await expect(sdk.field(id)).toHaveValue(v)`                                                            |
| `.should("be.visible" / "not.exist" / "be.disabled")`       | `toBeVisible()` / `toHaveCount(0)` / `toBeDisabled()`                                                   |
| `.should("have.class", c)` / `"have.attr"` / `"have.focus"` | `toContainClass(c)` / `toHaveAttribute(name, v)` / `toBeFocused()`                                      |
| `cy.contains(text).click()`                                 | `await sdk.text(text).first().click()` (in the SDK) or `page.getByText(text)`                           |
| `cy.intercept(...).as("c")` + `cy.wait("@c")`               | `const res = page.waitForResponse(pred)` before the action, then `await res`; or `waitForConfirm(page)` |
| `cy.intercept(glob, { statusCode, body })`                  | `page.route(glob, (r) => r.fulfill({ status, body }))`, or `hermetic.use()` for router calls            |
| `cy.intercept(glob, { forceNetworkError: true })`           | `page.route(glob, (r) => r.abort())`                                                                    |
| `cy.request(...)`                                           | `api.call(method, path, { data })` (never the `request` fixture for authenticated calls)                |
| `cy.url().should("include", host)` / `cy.origin(...)`       | `await page.waitForURL(/host/)`, then keep using `page`                                                 |
| `cy.on("uncaught:exception", () => false)`                  | not needed: third-party page errors don't fail tests                                                    |
| `cy.stub(win.console, "error")`                             | `const errors = await captureConsoleErrors(page)` before `goto`, then `await errors()`                  |
| popups                                                      | `const popup = page.waitForEvent("popup")` around the click                                             |
| `Cypress.env("…")`                                          | `credentials.*`, `HYPERSWITCH_API_URL`, `CLIENT_BASE_URL` (exported from fixtures)                      |
| `cy.log` / `cy.task("log")`                                 | `console.log` (shows in the report); `testInfo.attach()` for anything big                               |
| clearing cookies / storage between tests                    | not needed: every test gets a fresh context                                                             |
