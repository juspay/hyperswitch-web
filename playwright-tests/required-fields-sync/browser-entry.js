// Component-contract entry only. Imports the actual compiled W/U modules.
// It does not impersonate a complete checkout or change production SDK code.
import React from "react";
import { createRoot } from "react-dom/client";
import { Provider, createStore } from "jotai";
import * as Parser from "../../shared-code/sdk-utils/utils/SdkConfigParser.bs.js";
import * as Service from "../../shared-code/sdk-utils/hooks/ConfigurationService.bs.js";
import * as Common from "../../shared-code/sdk-utils/utils/CommonUtils.bs.js";
import { CacReader } from "../../shared-code/sdk-utils/superposition/superposition.js";
import * as Dynamic from "../../src/Utilities/DynamicFieldsUtils.bs.js";
import * as Fields from "../../src/Components/DynamicFields.bs.js";
import * as Methods from "../../src/Payments/PaymentMethodsRecord.bs.js";
import * as PaymentUtils from "../../src/Utilities/PaymentUtils.bs.js";
import * as Atoms from "../../src/Utilities/JotaiAtoms.bs.js";
import * as Utils from "../../src/Utilities/Utils.bs.js";
import * as S3 from "../../src/Utilities/S3Utils.bs.js";
import * as Country from "../../src/Country.bs.js";
import * as Refs from "../../src/CountryStateDataRefs.bs.js";
import states from "../../src/States.json";

let root;
let snapshot;
const actualEvaluate = CacReader.prototype.evaluateConfig;
let injectedFaults = 0;
const copy = (value) => JSON.parse(JSON.stringify(value));
function Probe({ input, parsed, client }) {
  const context = Dynamic.buildSuperpositionBaseContext(
    input.method,
    input.type,
    "web",
    input.country || "US",
    client,
    parsed.account_config,
    parsed.context_used,
  );
  const connectors = Parser.getEligibleConnectorsFromPaymentMethods(
    parsed.payment_methods,
    input.method,
    input.type,
  );
  const resolve = Service.useConfigurationService(parsed.raw_configs);
  const [descriptors, visible, initial] = resolve(
    connectors,
    context,
    client.intent_data.intentDataObject,
    input.forceBilling || false,
    input.suppressPrefill || false,
  );
  snapshot = copy({ context, connectors, descriptors, visible, initial });
  const [body, setBody] = React.useState({});
  return React.createElement(
    React.Fragment,
    null,
    React.createElement("pre", { id: "probe" }, JSON.stringify(snapshot)),
    React.createElement(Fields.make, {
      paymentMethod: input.method,
      paymentMethodType: input.type,
      setRequiredFieldsBody: setBody,
    }),
    React.createElement("pre", { id: "form-values" }, JSON.stringify(body)),
    React.createElement(
      "button",
      {
        id: "fixture-confirm",
        onClick: async () => {
          // Same payload merge function used by PaymentMethodsWrapper. The only
          // destination is a fixture path, intercepted by Playwright before I/O.
          const payload = Object.fromEntries(
            Utils.mergeAndFlattenToTuples([], body),
          );
          try {
            await fetch("/fixture-confirm", {
              method: "POST",
              headers: { "content-type": "application/json" },
              body: JSON.stringify(payload),
            });
          } catch (_) {
            /* Playwright deliberately aborts the fixture request. */
          }
        },
      },
      "Inspect fixture payload",
    ),
  );
}
window.rf = {
  mount(input) {
    root?.unmount();
    snapshot = undefined;
    injectedFaults = 0;
    // Explicit negative-test fault injection. Every unaffected connector still
    // executes the original pinned evaluator; the hook catches the thrown fault.
    CacReader.prototype.evaluateConfig = function (context) {
      if (input.failConnector && context.connector === input.failConnector) {
        injectedFaults++;
        throw new Error("synthetic connector evaluation failure");
      }
      return actualEvaluate.call(this, context);
    };
    Refs.countryDataRef.contents = Country.country;
    Refs.stateDataRef.contents = input.states || states.states;
    const parsed = Parser.itemToObjMapper(input.response);
    const client = Methods.itemToObjMapperFromClientList(
      input.client || { intent_data: { payment_type: "normal" } },
    );
    const store = createStore();
    store.set(PaymentUtils.sdkConfigsValue, parsed);
    store.set(PaymentUtils.paymentMethodListValue, client);
    store.set(Atoms.userCountry, input.countryName || "United States");
    const options = store.get(Atoms.optionAtom);
    store.set(Atoms.optionAtom, {
      ...options,
      billingAddress: {
        ...options.billingAddress,
        isUseBillingAddress: input.forceBilling || false,
        usePrefilledValues: input.suppressPrefill ? "Never" : "Auto",
      },
    });
    root = createRoot(document.getElementById("root"));
    root.render(
      React.createElement(
        Provider,
        { store },
        React.createElement(Probe, { input, parsed, client }),
      ),
    );
  },
  snapshot: () => copy(snapshot),
  injectedFaults: () => injectedFaults,
  labels: (values) => values.map(Common.snakeToPascalCase),
  countryNames: (values) => Utils.isoOptionsToCountryNames(values),
  methodName: (method, type) => PaymentUtils.getPaymentMethodName(method, type),
  assets: (locale) => S3.getCountryStateData(locale, undefined),
};
