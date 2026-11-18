# Required-fields SDK contract fixtures

Step 1 of H's required-fields sync playbook. H `docs/required_fields_sync_contracts/sdk-v1/cases.json` supplies the independent synthetic oracle; no expected result is generated from a renderer or seed. No production SDK, business data or pinned submodule behavior is changed. Owner review remains pending.

## Executed layers

2026-11-18: **22 Node tests, 14 actual Rust resolver tests, 38 browser-component tests and five full-checkout tests pass.** TypeScript, pinned W/U ReScript, component webpack and actual SDK/demo webpack builds pass. See H `sdk-v1/browser-checks.md` for commands, exact artifacts, initial failures and remaining gates.

- `contract.test.cjs` / `run-resolver.cjs` use the actual pinned U CacReader in a fresh bounded VM per case. JS results never stand in for Rust or browser execution.
- `browser-entry.js` / `browser.spec.ts` mount the actual W/U parser, constructor, configuration hook, DynamicFields, dropdowns and payload merge. Synthetic `/fixture-confirm` requests are observed and aborted. An explicit negative case injects one evaluator exception; unaffected connectors still execute the pinned evaluator. Component CSS is loaded as text, so this layer does not certify styling.
- `../e2e/required-fields-sync.spec.ts` runs the actual SDK loader/card frames and demo checkout with hermetic protocol fixtures. It covers Card/Debit, retained/fresh/restored snapshots, whole-form failure on SDK-config error, required-field validation, an actual card-plus-dynamic-billing confirm payload and mandate option inheritance. Confirm is aborted before the synthetic router; no payment is submitted.
- H's standalone Rust probe executes `superposition_core = 0.119.0` with independent Rust expectations. It does not build H's router or certify a server.

`contract.cjs` and H's schemas define bounded input/report shapes. Each stage requires its exact case set, pack/provenance hashes and executed artifact digest; skipped/missing/failed results cannot become a passing report. A passing negative probe records observed behavior, not acceptance of malformed data. Reports are local evidence, not deployment attestations or permission for hosted apply.

## Isolated setup

Do not invoke the normal postinstall/start/submodule updater or default/live Playwright projects. Their lifecycle and server behavior differ from these fixtures.

From W:

```sh
export REQUIRED_FIELDS_CASE_PACK=/Users/deepanshu.bansal/hyperswitch/docs/required_fields_sync_contracts/sdk-v1/cases.json
node --test playwright-tests/required-fields-sync/contract.test.cjs
node playwright-tests/required-fields-sync/prepare-fixture.cjs
```

Preparation verifies revisions and hashes, archives W and its pinned U locally, copies the test additions, excludes archive dotenv files without reading their values, creates empty npm user/global configs, and prints an owned temporary root. It does not fetch or change Git.

In **the returned web directory only**, the following setup downloads locked public packages. The continuation request authorized these downloads; test execution itself uses synthetic/local resources. Use the empty configs and fixture-owned cache to avoid ambient npm credentials:

```sh
npm ci --ignore-scripts --no-audit --no-fund --update-notifier=false --registry=https://registry.npmjs.org --userconfig=../npm-user.npmrc --globalconfig=../npm-global.npmrc --cache=../npm-cache
npm ci --prefix playwright-tests --ignore-scripts --no-audit --no-fund --update-notifier=false --registry=https://registry.npmjs.org --userconfig=../npm-user.npmrc --globalconfig=../npm-global.npmrc --cache=../npm-cache
npm ci --prefix Hyperswitch-React-Demo-App --ignore-scripts --no-audit --no-fund --update-notifier=false --registry=https://registry.npmjs.org --userconfig=../npm-user.npmrc --globalconfig=../npm-global.npmrc --cache=../npm-cache
PLAYWRIGHT_BROWSERS_PATH=../browsers node playwright-tests/node_modules/@playwright/test/cli.js install chromium --only-shell
npm run re:build --ignore-scripts
node playwright-tests/node_modules/typescript/bin/tsc -p playwright-tests/required-fields-sync/tsconfig.json --noEmit
node node_modules/webpack-cli/bin/cli.js --config playwright-tests/required-fields-sync/webpack.config.cjs
node playwright-tests/required-fields-sync/run-browser.cjs
node playwright-tests/required-fields-sync/run-checkout.cjs
```

Compile before typechecking: existing fixtures import generated `TestUtils.bs.js`. Stop on failures. Never regenerate lockfiles or advance U to make setup work. The earlier offline-only attempts lacked cached packages; public-registry setup now succeeds.

## Fixture and report boundaries

Each runner validates the source-copy ownership marker, uses fresh loopback ports and a separate owned run directory, and closes its servers in `finally`. Static servers have no proxy, allow only GET/HEAD over a sealed emitted-file manifest, and refuse changed assets/writes. Manifest hashes cover every emitted chunk/HTML/CSS/asset, and files are verified again after tests.

The checkout runner uses the pinned SDK/demo entry points and webpack loaders/templates with explicit synthetic configuration. It bypasses normal dev servers and normal Playwright config. Dotenv inputs and optional Sentry uploads are disabled. Child processes receive an explicit minimal environment. Router identity is `https://required-fields-router.invalid`; browser routes serve synthetic fixtures, Node fetch is forbidden, and service workers are blocked. There are no live credentials, existing-server reuse, seeding or API-server dependencies.

Reports record Playwright, Chromium and Node versions plus the executed manifest digest. Registration/report creation is exclusive within a fresh run directory, so repeated runs can reuse the owned dependency/build copy without overwriting earlier evidence. Only the root named by its verified ownership marker may be cleaned up; retain sanitized evidence first. Original source checkouts, user caches and unrelated processes are not cleanup targets.

## Remaining acceptance

The synthetic/local browser gate is green. Exhaustive Rust enum/CIT/partial-filter comparisons, approved full ALL/EPS catalogs, dummy/retirement policy, all supported payment-method checkout combinations, old/mobile/deployed reader artifacts and live presentation metadata remain separate gates. No production country asset was fetched. The four-code country sample is not an approved universal catalog.

Keep Nordea comma, bank-type defaults, legacy path corrections and SDK card/aggregation/dimension decisions in separate reviewed changes. Hosted apply remains disabled pending all required contracts, journal, coordination, restoration and target V1–V4 evidence.
