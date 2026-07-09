const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(root, file), "utf8");

const files = {
  demoTelemetry: read("src/DemoTelemetry.res"),
  paymentHelpers: read("src/Utilities/PaymentHelpers.res"),
  googlePayHelpers: read("src/Utilities/GooglePayHelpers.res"),
  applePayHelpers: read("src/Utilities/ApplePayHelpers.res"),
  elements: read("src/hyper-loader/Elements.res"),
  loaderPaymentElement: read("src/hyper-loader/LoaderPaymentElement.res"),
  gpay: read("src/Payments/GPay.res"),
  applePay: read("src/Payments/ApplePay.res"),
  vgsVault: read("src/Payments/VGSVault.res"),
  parentCardComponent: read("src/Payments/ParentCardComponent.res"),
  savedMethods: read("src/Components/SavedMethods.res"),
  nextActionHelpers: read("src/Utilities/NextActionHelpers.res"),
  threeDsMethod: read("src/ThreeDSMethod.res"),
  threeDsAuth: read("src/ThreeDSAuth.res"),
};

const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message);
  }
};

const legacyThreeDsMethodCollection = "three_ds_method" + "_collection";

const eventPayloadBlocks = (source, eventName) => {
  const blocks = [];
  const marker = `eventName="${eventName}"`;
  let offset = 0;

  while (offset < source.length) {
    const eventStart = source.indexOf(marker, offset);
    if (eventStart === -1) {
      break;
    }

    const payloadStart = source.indexOf("~payload=[", eventStart);
    const payloadEnd = source.indexOf("]->getJsonFromArrayOfJson", payloadStart);
    if (payloadStart !== -1 && payloadEnd !== -1) {
      blocks.push(source.slice(payloadStart, payloadEnd));
      offset = payloadEnd + 1;
    } else {
      offset = eventStart + marker.length;
    }
  }

  return blocks;
};

[
  '"type", "DEMO_EVENT"->JSON.Encode.string',
  '"payload", eventPayload',
  '"data", payload->Option.getOr(emptyPayload())',
  "let isEnabled = () => true",
  "emitForPaymentType",
  "flowOverride",
  "Card => Some(\"card\")",
  "Gpay => Some(\"google_pay\")",
  "Applepay => Some(\"apple_pay\")",
].forEach(marker => {
  assert(files.demoTelemetry.includes(marker), `DemoTelemetry.res missing marker: ${marker}`);
});

assert(
  !files.demoTelemetry.includes("hyperswitchSdkDemoEvent"),
  "Demo telemetry messages must use { type: \"DEMO_EVENT\", payload: ... }, not hyperswitchSdkDemoEvent",
);

assert(
  !files.demoTelemetry.includes('"demo"') &&
    !files.demoTelemetry.includes("merchant-demo-vgs-external-3ds"),
  "Demo telemetry payload must not include a fixed demo name",
);

assert(
  !files.demoTelemetry.includes('"demoEvent"') &&
    !files.demoTelemetry.includes('"payload", payload->Option.getOr(emptyPayload())'),
  "Demo telemetry payload must use one eventName field and event-specific data, not demoEvent or payload.payload",
);

assert(
  !files.demoTelemetry.includes("hyperswitchDemoTelemetryEnabled") &&
    !files.demoTelemetry.includes("__HYPERSWITCH_SDK_DEMO_TELEMETRY__") &&
    !files.demoTelemetry.includes("hyperswitchSdkDemoTelemetry") &&
    !files.demoTelemetry.includes("sdkDemoTelemetry") &&
    !files.demoTelemetry.includes("localStorage"),
  "Demo telemetry must be enabled in all cases without opt-in flags",
);

assert(
  !files.paymentHelpers.includes('"requestBodyJson"') &&
    !files.paymentHelpers.includes('("status", intent.status->JSON.Encode.string') &&
    !files.paymentHelpers.includes('"demoFlow", demoFlow->JSON.Encode.string') &&
    !files.paymentHelpers.includes('"threeDsMethodComp", threeDsMethodComp->JSON.Encode.string'),
  "Payment API demo payloads must not repeat values already present in body/response/top-level flow",
);

assert(
  eventPayloadBlocks(files.vgsVault, "vgs_token_received").every(
    block => !block.includes('"vgsCardData"'),
  ) &&
    eventPayloadBlocks(files.vgsVault, "saved_card_cvc_token_received").every(
      block => !block.includes('"cvcToken"'),
    ),
  "VGS token demo payloads must not repeat token aliases already present in the VGS response",
);

const vgsConfirmPayloadBlocks = [
  ...eventPayloadBlocks(files.parentCardComponent, "vgs_confirm_body_built"),
  ...eventPayloadBlocks(files.savedMethods, "vgs_confirm_body_built"),
];

assert(
  vgsConfirmPayloadBlocks.every(
    block =>
      !block.includes('"baseBody"') &&
      !block.includes('"vgsCardData"') &&
      !block.includes('"paymentToken"') &&
      !block.includes('"customerId"') &&
      !block.includes('"cvcToken"'),
  ),
  "VGS confirm-body demo payloads must keep finalBody/confirmParams only, not source values already inside finalBody",
);

assert(
  eventPayloadBlocks(files.threeDsAuth, "three_ds_authentication_response").every(
    block =>
      !block.includes('"error"') &&
      !block.includes('"transStatus"') &&
      !block.includes('"acsUrl"'),
  ),
  "3DS auth response demo payloads must not repeat fields extracted from the full response",
);

assert(
  eventPayloadBlocks(files.threeDsAuth, "three_ds_authentication_started").every(
    block =>
      block.includes('"metadata"') &&
      !block.includes('"threeDsMethodComp"') &&
      !block.includes('"threeDsAuthoriseUrl"'),
  ),
  "3DS auth started demo payloads must not repeat values derived from metadata",
);

assert(
  eventPayloadBlocks(files.threeDsMethod, "ddc_collection_started").every(
    block =>
      block.includes('"metadata"') &&
      !block.includes('"threeDSData"') &&
      !block.includes('"consumePostMessageForCompletion"'),
  ),
  "3DS method DDC started demo payloads must not repeat values derived from metadata.threeDSData",
);

assert(
  [
    ...eventPayloadBlocks(files.threeDsMethod, "ddc_collection_completed"),
    ...eventPayloadBlocks(files.threeDsMethod, "ddc_collection_failed"),
  ].every(
    block =>
      block.includes('"metadata"') &&
      !block.includes('"iframeId"') &&
      !block.includes('"result"'),
  ),
  "3DS method DDC completed/failed demo payloads must not repeat iframeId/result values already represented by metadata",
);

assert(
  !files.threeDsMethod.includes(legacyThreeDsMethodCollection),
  "3DS method demo telemetry must use DDC event names, not the legacy 3DS method collection name",
);

assert(
  eventPayloadBlocks(files.paymentHelpers, "netcetera_flow_initiated").every(
    block =>
      block.includes('"metadata"') &&
      !block.includes('"threeDSData"') &&
      !block.includes('"do3dsMethodCall"'),
  ),
  "Netcetera demo payloads must not repeat threeDSData or method flags already derivable from metadata",
);

assert(
  !files.nextActionHelpers.includes('"paymentMethod", paymentMethod->JSON.Encode.string') &&
    !files.nextActionHelpers.includes('"redirectUrl", redirectUrl->JSON.Encode.string') &&
    !files.nextActionHelpers.includes('"redirectMode", redirectMode->JSON.Encode.string'),
  "DDC demo payloads must not repeat card flow or fields already present in nextAction",
);

[
  ["sdk_mounted", files.parentCardComponent],
  ["confirm_object", files.paymentHelpers + files.parentCardComponent + files.savedMethods],
  ["api_request", files.paymentHelpers],
  ["api_response", files.paymentHelpers],
  ["api_error_response", files.paymentHelpers],
  ["api_exception", files.paymentHelpers],
  ["netcetera_flow_initiated", files.paymentHelpers],
  ["payment_success", files.paymentHelpers],
  ["payment_failed", files.paymentHelpers],
  ["challenge_completed", files.paymentHelpers],
  ["ddc_collection_started", files.nextActionHelpers],
  ["ddc_collection_completed", files.nextActionHelpers],
  ["ddc_collection_failed", files.nextActionHelpers],
  ["ddc_collection_started", files.threeDsMethod],
  ["ddc_collection_completed", files.threeDsMethod],
  ["ddc_collection_failed", files.threeDsMethod],
  ["three_ds_authentication_started", files.threeDsAuth],
  ["three_ds_authentication_response", files.threeDsAuth],
  ["three_ds_challenge_presented", files.threeDsAuth],
  ["vgs_script_ready", files.vgsVault],
  ["vgs_form_rendered", files.vgsVault],
  ["vgs_field_state_changed", files.vgsVault],
  ["vgs_form_submitted", files.vgsVault],
  ["vgs_token_received", files.vgsVault],
  ["vgs_token_failed", files.vgsVault],
  ["saved_card_cvc_token_received", files.vgsVault],
  ["google_pay_button_clicked", files.gpay],
  ["google_pay_sheet_requested", files.googlePayHelpers],
  ["google_pay_sheet_opened", files.elements],
  ["google_pay_sheet_authorized", files.elements],
  ["google_pay_sheet_cancelled", files.elements],
  ["google_pay_response_received", files.googlePayHelpers],
  ["google_pay_error_received", files.googlePayHelpers],
  ["apple_pay_button_clicked", files.applePay],
  ["apple_pay_sheet_opened", files.applePayHelpers],
  ["apple_pay_payment_authorized", files.applePayHelpers],
  ["apple_pay_sheet_cancelled", files.applePayHelpers],
  ["apple_pay_response_received", files.applePayHelpers],
].forEach(([eventName, source]) => {
  assert(source.includes(eventName), `Missing demo telemetry event: ${eventName}`);
});

assert(
  /paymentTypeToFlow[\s\S]*\| _ => None/.test(files.demoTelemetry),
  "Demo telemetry must explicitly ignore non-demo payment types",
);

assert(
  /if isDemoFlow\(paymentType\)/.test(files.demoTelemetry),
  "emitForPaymentType must gate postMessages to demo payment types",
);

assert(
  /if isEnabled\(\) && isKnownFlow\(flow\)/.test(files.demoTelemetry),
  "DemoTelemetry.emit must remain flow-gated while isEnabled is unconditional",
);

assert(
  files.demoTelemetry.includes("postMessageToDemoTargets") &&
    files.demoTelemetry.includes("window.top !== window.parent") &&
    files.demoTelemetry.includes('postMessage(message, "*")') &&
    !files.demoTelemetry.includes("targetOrigin"),
  "DemoTelemetry must emit globally with '*' to parent/top without origin filtering or duplicating direct iframe events",
);

assert(
  !files.loaderPaymentElement.includes("DemoTelemetry.isEnabled()") &&
    !files.loaderPaymentElement.includes("hyperswitchSdkDemoTelemetry=true") &&
    files.loaderPaymentElement.includes("fullscreenIndex.html"),
  "LoaderPaymentElement must not append demo telemetry opt-in params because telemetry is always enabled",
);

assert(
  !files.paymentHelpers.includes("if isConfirm || isCompleteAuthorize") &&
    /if isConfirm \{[\s\S]*eventName="confirm_object"/.test(files.paymentHelpers),
  "confirm_object must only be emitted for /confirm calls, not complete_authorize",
);

assert(
  !files.paymentHelpers.includes(`eventName="${legacyThreeDsMethodCollection}_started"`) &&
    !files.paymentHelpers.includes('eventName="three_ds_authentication_started"'),
  "3DS started events must be emitted by the mounted 3DS components, not duplicated in PaymentHelpers",
);

assert(
  files.paymentHelpers.includes('apiKind", "three_ds_auth"') &&
    files.paymentHelpers.includes('eventName="api_request"') &&
    files.paymentHelpers.includes('eventName="api_response"') &&
    files.paymentHelpers.includes('~demoFlow="card"'),
  "threeDsAuth must emit demo API request/response telemetry because it bypasses intentCall",
);

assert(
  files.savedMethods.includes('DemoTelemetry.markNextCardFlow("saved_card")'),
  "Saved-card VGS confirm must mark the next shared card API telemetry as saved_card",
);

assert(
  files.paymentHelpers.includes('metaData->Dict.set("demoFlow"') &&
    files.threeDsMethod.includes('getString("demoFlow", "card")') &&
    files.threeDsAuth.includes('getString("demoFlow", "card")') &&
    files.threeDsAuth.includes("~demoFlow"),
  "3DS metadata must carry demoFlow into fullscreen method/auth stages",
);

console.log("Demo telemetry contract passed");
