import React, { useEffect, useState } from "react";
import { HyperElements } from "@juspay-tech/react-hyper-js";
import CheckoutForm from "./CheckoutForm";
import {
  getQueryParam,
  fetchConfigAndUrls,
  getPaymentIntentData,
  loadHyperScript,
  hyperOptionsV1,
  hyperOptionsV2,
} from "./utils";

function Payment() {
  const [hyperPromise, setHyperPromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");
  const [paymentId, setPaymentId] = useState("");
  const [error, setError] = useState(null);
  const [isScriptLoaded, setIsScriptLoaded] = useState(false);

  const isCypressTestMode = getQueryParam("isCypressTestMode") === "true";
  const publishableKeyQueryParam = getQueryParam("publishableKey");
  const clientSecretQueryParam = getQueryParam("clientSecret");

  const baseUrl = SELF_SERVER_URL || ENDPOINT;

  useEffect(() => {
    let isMounted = true;

    const initializePayment = async () => {
      try {
        const { configData, urlsData } = await fetchConfigAndUrls(baseUrl);

        const publishableKey = isCypressTestMode
          ? publishableKeyQueryParam
          : configData.publishableKey;

        const paymentIntentData = await getPaymentIntentData({
          baseUrl,
          isCypressTestMode,
          clientSecretQueryParam,
          setError,
        });

        if (!paymentIntentData) return;

        const hyper = await loadHyperScript({
          clientUrl: urlsData.clientUrl,
          publishableKey,
          profileId: configData?.profileId,
          customBackendUrl: urlsData.serverUrl,
          isScriptLoaded,
          setIsScriptLoaded,
        });

        if (isMounted) {
          setClientSecret(paymentIntentData.clientSecret);
          if (SDK_VERSION === "v2") {
            setPaymentId(paymentIntentData.paymentId);
          }
          setHyperPromise(Promise.resolve(hyper));
        }
      } catch (err) {
        console.error("Initialization error:", err);
        setError("Failed to load payment. Please refresh.");
      }
    };

    initializePayment();

    return () => {
      isMounted = false;
    };
  }, []);

  let selectedOptions;
  if (SDK_VERSION === "v1") {
    selectedOptions = hyperOptionsV1(clientSecret);
  } else {
    selectedOptions = hyperOptionsV2(clientSecret, paymentId);
  }

  selectedOptions = {
    ...selectedOptions,
    preLoadedParams: {
      payment_method_list: {
        redirect_url: "https://google.com/success",
        currency: "USD",
        payment_methods: [
          {
            payment_method: "pay_later",
            payment_method_types: [
              {
                payment_method_type: "klarna",
                payment_experience: [
                  {
                    payment_experience_type: "redirect_to_url",
                    eligible_connectors: ["stripe"],
                  },
                ],
                card_networks: null,
                bank_names: null,
                bank_debits: null,
                bank_transfers: null,
                required_fields: {
                  "billing.email": {
                    required_field: "payment_method_data.billing.email",
                    display_name: "email",
                    field_type: "user_email_address",
                    value: "abhishek.c@juspay.in",
                  },
                  "billing.address.country": {
                    required_field:
                      "payment_method_data.billing.address.country",
                    display_name: "country",
                    field_type: {
                      user_address_country: {
                        options: [
                          "AU",
                          "AT",
                          "BE",
                          "CA",
                          "CZ",
                          "DK",
                          "FI",
                          "FR",
                          "GR",
                          "DE",
                          "IE",
                          "IT",
                          "NL",
                          "NZ",
                          "NO",
                          "PL",
                          "PT",
                          "RO",
                          "ES",
                          "SE",
                          "CH",
                          "GB",
                          "US",
                        ],
                      },
                    },
                    value: "US",
                  },
                },
                surcharge_details: null,
                pm_auth_connector: null,
              },
              {
                payment_method_type: "afterpay_clearpay",
                payment_experience: [
                  {
                    payment_experience_type: "redirect_to_url",
                    eligible_connectors: ["stripe"],
                  },
                ],
                card_networks: null,
                bank_names: null,
                bank_debits: null,
                bank_transfers: null,
                required_fields: {
                  "billing.address.city": {
                    required_field: "payment_method_data.billing.address.city",
                    display_name: "city",
                    field_type: "user_address_city",
                    value: "San Fransico",
                  },
                  "billing.address.zip": {
                    required_field: "payment_method_data.billing.address.zip",
                    display_name: "zip",
                    field_type: "user_address_pincode",
                    value: "94122",
                  },
                  "billing.email": {
                    required_field: "payment_method_data.billing.email",
                    display_name: "email",
                    field_type: "user_email_address",
                    value: "abhishek.c@juspay.in",
                  },
                  "billing.address.first_name": {
                    required_field:
                      "payment_method_data.billing.address.first_name",
                    display_name: "billing_first_name",
                    field_type: "user_billing_name",
                    value: "joseph",
                  },
                  "shipping.address.first_name": {
                    required_field: "shipping.address.first_name",
                    display_name: "shipping_first_name",
                    field_type: "user_shipping_name",
                    value: "joseph",
                  },
                  "billing.address.line1": {
                    required_field: "payment_method_data.billing.address.line1",
                    display_name: "line1",
                    field_type: "user_address_line1",
                    value: "1467",
                  },
                  "billing.address.last_name": {
                    required_field:
                      "payment_method_data.billing.address.last_name",
                    display_name: "billing_last_name",
                    field_type: "user_billing_name",
                    value: "Doe",
                  },
                  "shipping.address.state": {
                    required_field: "shipping.address.state",
                    display_name: "state",
                    field_type: "user_shipping_address_state",
                    value: "California",
                  },
                  "shipping.address.line1": {
                    required_field: "shipping.address.line1",
                    display_name: "line1",
                    field_type: "user_shipping_address_line1",
                    value: "1467",
                  },
                  "billing.address.country": {
                    required_field:
                      "payment_method_data.billing.address.country",
                    display_name: "country",
                    field_type: {
                      user_address_country: {
                        options: ["GB", "AU", "CA", "US", "NZ"],
                      },
                    },
                    value: "US",
                  },
                  "shipping.address.zip": {
                    required_field: "shipping.address.zip",
                    display_name: "zip",
                    field_type: "user_shipping_address_pincode",
                    value: "94122",
                  },
                  "billing.address.state": {
                    required_field: "payment_method_data.billing.address.state",
                    display_name: "state",
                    field_type: "user_address_state",
                    value: "California",
                  },
                  "shipping.address.last_name": {
                    required_field: "shipping.address.last_name",
                    display_name: "shipping_last_name",
                    field_type: "user_shipping_name",
                    value: "Doe",
                  },
                  "shipping.address.country": {
                    required_field: "shipping.address.country",
                    display_name: "country",
                    field_type: {
                      user_shipping_address_country: {
                        options: ["ALL"],
                      },
                    },
                    value: "US",
                  },
                  "shipping.address.city": {
                    required_field: "shipping.address.city",
                    display_name: "city",
                    field_type: "user_shipping_address_city",
                    value: "San Fransico",
                  },
                },
                surcharge_details: null,
                pm_auth_connector: null,
              },
              {
                payment_method_type: "affirm",
                payment_experience: [
                  {
                    payment_experience_type: "redirect_to_url",
                    eligible_connectors: ["stripe"],
                  },
                ],
                card_networks: null,
                bank_names: null,
                bank_debits: null,
                bank_transfers: null,
                required_fields: {},
                surcharge_details: null,
                pm_auth_connector: null,
              },
            ],
          },
          {
            payment_method: "card",
            payment_method_types: [
              {
                payment_method_type: "debit",
                payment_experience: null,
                card_networks: [
                  {
                    card_network: "AmericanExpress",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "UnionPay",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "CartesBancaires",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "Discover",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "Interac",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "JCB",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "DinersClub",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "Visa",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "Mastercard",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                ],
                bank_names: null,
                bank_debits: null,
                bank_transfers: null,
                required_fields: {
                  "payment_method_data.card.card_exp_year": {
                    required_field: "payment_method_data.card.card_exp_year",
                    display_name: "card_exp_year",
                    field_type: "user_card_expiry_year",
                    value: null,
                  },
                  "payment_method_data.card.card_number": {
                    required_field: "payment_method_data.card.card_number",
                    display_name: "card_number",
                    field_type: "user_card_number",
                    value: null,
                  },
                  "payment_method_data.card.card_cvc": {
                    required_field: "payment_method_data.card.card_cvc",
                    display_name: "card_cvc",
                    field_type: "user_card_cvc",
                    value: null,
                  },
                  "payment_method_data.card.card_exp_month": {
                    required_field: "payment_method_data.card.card_exp_month",
                    display_name: "card_exp_month",
                    field_type: "user_card_expiry_month",
                    value: null,
                  },
                },
                surcharge_details: null,
                pm_auth_connector: null,
              },
              {
                payment_method_type: "credit",
                payment_experience: null,
                card_networks: [
                  {
                    card_network: "CartesBancaires",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "UnionPay",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "Interac",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "DinersClub",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "JCB",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "Discover",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "Visa",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "Mastercard",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                  {
                    card_network: "AmericanExpress",
                    surcharge_details: null,
                    eligible_connectors: ["stripe"],
                  },
                ],
                bank_names: null,
                bank_debits: null,
                bank_transfers: null,
                required_fields: {
                  "payment_method_data.card.card_exp_year": {
                    required_field: "payment_method_data.card.card_exp_year",
                    display_name: "card_exp_year",
                    field_type: "user_card_expiry_year",
                    value: null,
                  },
                  "payment_method_data.card.card_number": {
                    required_field: "payment_method_data.card.card_number",
                    display_name: "card_number",
                    field_type: "user_card_number",
                    value: null,
                  },
                  "payment_method_data.card.card_cvc": {
                    required_field: "payment_method_data.card.card_cvc",
                    display_name: "card_cvc",
                    field_type: "user_card_cvc",
                    value: null,
                  },
                  "payment_method_data.card.card_exp_month": {
                    required_field: "payment_method_data.card.card_exp_month",
                    display_name: "card_exp_month",
                    field_type: "user_card_expiry_month",
                    value: null,
                  },
                },
                surcharge_details: null,
                pm_auth_connector: null,
              },
            ],
          },
        ],
        mandate_payment: null,
        merchant_name: "NewAge Retailer",
        show_surcharge_breakup_screen: false,
        payment_type: "normal",
        request_external_three_ds_authentication: false,
        collect_shipping_details_from_wallets: false,
        collect_billing_details_from_wallets: false,
        is_tax_calculation_enabled: false,
        sdk_next_action: {
          next_action: "confirm",
        },
      },
      customer_methods_list: {
        customer_payment_methods: [],
        is_guest_customer: true,
      },
      session_tokens: {
        payment_id: "pay_dLqQGf9oR5hceZ5VsEOo",
        client_secret: "pay_dLqQGf9oR5hceZ5VsEOo_secret_Ignju1G1x8pp6fjBgaD3",
        session_token: [],
      },
      blocked_bins: {},
    },
  };

  return (
    <div className="mainContainer">
      <div className="heading">
        <h2>Hyperswitch Unified Checkout</h2>
      </div>

      {error && <p className="text-red-600">{error}</p>}

      {clientSecret && hyperPromise && (
        <HyperElements hyper={hyperPromise} options={selectedOptions}>
          <CheckoutForm />
        </HyperElements>
      )}
    </div>
  );
}

export default Payment;
