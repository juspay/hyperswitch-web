# RetrievePaymentMethod API Implementation

## Overview
This implementation adds complete support for the Payment Methods Retrieve API (`/payment_methods/{payment_method_id}` GET endpoint) to the Hyperswitch Web SDK.

## Files Modified

### 1. `src/Utilities/APIHelpers/APIUtils.res`
- Added `RetrievePaymentMethod` to `apiCallV1` type
- Added path mapping: `payment_methods/${paymentMethodIdVal}`
- Added query parameters mapping (no special params needed)

### 2. `src/Types/HyperLoggerTypes.res`
- Added `RETRIEVE_PAYMENT_METHOD_CALL_INIT` event type
- Added `RETRIEVE_PAYMENT_METHOD_CALL` event type

### 3. `src/Utilities/LoggerUtils.res`
- Added event to init event mapping
- Added init event to events without init list

### 4. `src/Utilities/PaymentHelpers.res`
- Implemented `retrievePaymentMethod` function
- Proper error handling and logging integration
- Follows same patterns as existing payment method APIs

## Function Signature
```rescript
let retrievePaymentMethod = async (
  ~ephemeralKey: string,
  ~paymentMethodId: string,
  ~logger: LoggerUtils.loggerMake,
  ~customPodUri: string,
) => promise<option<JSON.t>>
```

## Usage
```rescript
let result = await PaymentHelpers.retrievePaymentMethod(
  ~ephemeralKey="pk_test_...",
  ~paymentMethodId="pm_1234567890",
  ~logger=loggerInstance,
  ~customPodUri="",
)
```

## API Details
- **Method**: GET
- **Path**: `/payment_methods/{payment_method_id}`
- **Authentication**: Ephemeral key (publishable key)
- **Response**: Payment method details as JSON

## Related Work
This supports the Smithy Framework work in hyperswitch repository (issue #9484) by providing the web SDK implementation for the Payment Methods Retrieve API.
