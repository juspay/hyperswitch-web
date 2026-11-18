const { canonical } = require("./contract.cjs");
// Independent synthetic inputs, never imported by the renderer/planner as an oracle generator.
const { sha256, loadPack } = require("../required-fields-sync/contract.cjs");
function fixture() {
  const cases = ["projected_before", "projected_after", "post_apply"].map(
    (phase, i) => {
      const label = i === 0 ? "Before billing" : "After billing";
      const response = {
        raw_configs: {
          contexts: [],
          overrides: {},
          default_configs: {
            "dynamic_fields.billing.address.line1._is_required": true,
            "dynamic_fields.billing.address.line1._field_render_type":
              "Generic",
            "dynamic_fields.billing.address.line1._confirm_request_write_path":
              "payment_method_data.billing.address.line1",
            "dynamic_fields.billing.address.line1._default_label_text": label,
            "dynamic_fields.billing.address.line1._field_display_order": 1,
            "dynamic_fields.billing.address.line1._render_when_prefilled": false,
          },
        },
        payment_methods: [
          {
            payment_method: "card",
            payment_method_types: [
              {
                payment_method_type: "debit",
                criteria_rules: [
                  {
                    criteria_value: "default",
                    eligible_connectors: ["stripe", "adyen"],
                  },
                ],
              },
            ],
          },
        ],
      };
      const input = {
        method: "card",
        type: "debit",
        country: "US",
        client: { intent_data: { payment_type: "normal" } },
      };
      return {
        phase,
        response_utf8: JSON.stringify(response),
        response_sha256: sha256(JSON.stringify(response)),
        input,
        input_sha256: sha256(canonical(input)),
        expected: {
          context: {
            payment_method: "card",
            payment_method_type: "debit",
            country: "US",
            mandate_type: "non_mandate",
            platform: "web",
            always_collect_billing_details_from_wallet_connector: true,
            always_collect_shipping_details_from_wallet_connector: false,
          },
          connectors: ["stripe", "adyen"],
          label,
          path: "payment_method_data.billing.address.line1",
          value: "Fixture lane",
        },
      };
    },
  );
  return {
    schema_version: 1,
    run: sha256("synthetic-step11-run"),
    target: sha256("synthetic-step11-target"),
    plan: sha256("synthetic-step11-plan"),
    reader: sha256(canonical(loadPack().pack.provenance)),
    parent_pack_sha256: loadPack().pack_sha256,
    cases,
  };
}
module.exports = { fixture };
