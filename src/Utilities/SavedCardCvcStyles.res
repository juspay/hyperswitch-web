// Geometry of the saved-card (return user) CVC field.
//
// The field itself is rendered inside the nested paymentMethodsSDK iframe — by
// CardCVCElement in the raw flow, by VGSInputComponent in the VGS vault flow — while
// ParentCardComponent reserves the same box in the outer frame before that iframe has
// booted. Both frames must agree on the height or the stand-in stops matching the real
// field, so it lives here rather than as a literal on either side.

// Height of the CVC input itself. Deliberately small: the saved-card row holds the CVC
// inline next to the card details, not as a full-width new-card field.
let fieldHeight = "1.8rem"

// Box the outer frame reserves for the field. The inner iframe's body wrapper
// (PaymentMethodsSDK) pads it by 2px on every side, so the reserved box is 4px taller
// than the field — the stand-in insets itself by the same 2px.
let reservedBoxHeight = `calc(${fieldHeight} + 4px)`
