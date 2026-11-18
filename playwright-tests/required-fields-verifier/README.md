# Required-fields browser verifier

Step 11 local companion package for H. Runs the pinned W `939f45786aee1c3b14e3f0b134bb42cb2cf2dd39` and U `1af3e5dabf9d5a17dd864ac7312151ebac4367c6` functions, actual components, SDK loader/frames and demo checkout. It does not modify either SDK or the submodule. H's Step 1 case pack remains the independent regression oracle.

`run.cjs` requires the explicitly registered disposable source/build copy described in `../required-fields-sync/README.md`. It refuses execution in the source checkout. Compile ReScript and the component webpack first, using locked dependencies with lifecycle scripts disabled. Never use the normal postinstall, submodule updater, default/live test project or dev server.

Provide `REQUIRED_FIELDS_CASE_PACK`, `PLAYWRIGHT_BROWSERS_PATH` and `RF_VERIFIER_INPUT`. Input must be a regular provisioned file inside that fixture. For synthetic local checks only, `fixture-input.cjs` exports a handwritten three-phase fixture. Run:

```sh
node --test playwright-tests/required-fields-verifier/contract.test.cjs
node playwright-tests/node_modules/typescript/bin/tsc -p playwright-tests/required-fields-verifier/tsconfig.json --noEmit
node playwright-tests/required-fields-verifier/run.cjs
```

The runner builds actual checkout artifacts with explicit synthetic URLs, serves sealed static files on owned loopback ports, then executes all Step 1 browser-component/checkout and JS resolver cases. It executes seven additional response-bound cases through the actual constructor, connector aggregation, components and full checkout: projected-before, projected-after, post-apply, and retained/fresh snapshots. Each phase asserts required validation and intercepts the actual card-plus-dynamic billing confirm before network submission. JS resolution, component execution and complete checkout remain separate reports. Rust is independently executed by H; it is never impersonated by this package.

The response-bound full-checkout driver currently supports provisioned Card/Debit, US, normal payment, and `billing.address.line1`. Other cases must have an independently specified driver; unsupported inputs refuse. The full Step 1 regressions additionally exercise inheritance, aliases, connector orders, options, prefill, country/state assets and error cases. They do **not** certify those behaviors for every new arbitrary response. The Step 6 partition matrix is not automatically converted to fabricated browser dimensions.

The bounded contract rejects duplicate keys, unsafe numbers/keys, unknown envelope fields, input drift, unsupported cases and missing/failed reports. Exact request bytes, response bytes, canonical input JSON (object keys sorted; arrays preserved), case pack, provenance, runtime/browser files and every emitted asset are hashed. Ordered arrays retain order. H reads the envelope and nested unchanged Step 1 reports independently. Reports contain hashes rather than input values or card data. A candidate report becomes `report.json` only after successful process exit, regression results and final source/asset/input integrity checks.

Child environments use a whitelist without HOME, NODE_OPTIONS, proxy, cloud, writer or payment credentials. A sentinel test verifies actual child inheritance. Children have deadlines and owned process-group cancellation. Browser routes block external traffic, service workers and confirm submission; Node fixture fetch is disabled. Local checks additionally deny non-loopback network at the OS boundary. No hosted server or payment target is contacted.

**This is a local package, not a certified deployed companion image.** Runtime image digest, Linux/cluster execution, read-only mounts, service-account absence, filesystem/process credential isolation, resource limits and same-Job wiring need platform evidence. Pod-scoped NetworkPolicy cannot prove per-container isolation. The envelope explicitly records `scope: synthetic_local` and `platform_credential_isolation: pending`; H refuses it as certified-server evidence. Old/mobile reader images, live country assets, new browser matrices and target access remain pending. No success flag or JSON field can enable hosted apply.

Use only the owned marker's cleanup scope. Source checkout, U, user caches, remote workspaces and unrelated processes are never cleanup targets. See H `docs/required_fields_sync_contracts/verification-v1/` for executed results and limitations.
