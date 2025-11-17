# Analysis: When `payment_method_data.card_token.card_holder_name` Gets Set

## Location in Code

The value is set in the `useRequiredFieldsBody` hook within `DynamicFieldsUtils.res` (lines ~590-604).

## Complete Conditions (ALL must be true)

### 1. **Saved Card Flow Context**

- `isSavedCardFlow === true`
- This means the user is working with a previously saved payment method, not creating a new one

### 2. **Field Type Requirements (OR condition)**

- `item.field_type === BillingName` **OR** `item.field_type === FullName`
- The field being processed must be either a billing name field or full name field

### 3. **Display Name Requirement**

- `item.display_name === "card_holder_name"`
- The field must be specifically designated as a card holder name field

### 4. **Required Field Path Requirement**

- `item.required_field === "payment_method_data.card.card_holder_name"`
- The original required field path must be targeting the standard card holder name location

### 5. **Value Not Empty**

- `value != ""`
- The actual name value must not be empty (this is checked earlier in the function)

### 6. **Not All Stored Cards Have Names**

- `!isAllStoredCardsHaveName === true`
- This is the key condition: the system determines that NOT all stored cards already have cardholder names associated with them

## What `isAllStoredCardsHaveName` Means

This boolean is calculated using:

```res
let isAllStoredCardsHaveName = React.useMemo(() => {
  PaymentType.getIsStoredPaymentMethodHasName(savedMethod)
}, [savedMethod])
```

The function `PaymentType.getIsStoredPaymentMethodHasName` checks if the saved payment method already contains cardholder name information.

## Business Logic Explanation

When **all 6 conditions** are met, the system:

- Sets `"payment_method_data.card_token.card_holder_name"` instead of the normal `"payment_method_data.card.card_holder_name"`
- This appears to be for **updating/adding** cardholder name to an existing saved card token
- If `isAllStoredCardsHaveName` is `true`, it means the saved card already has name info, so no update is needed

## Summary

`"payment_method_data.card_token.card_holder_name"` gets set **only when**:

1. Using a saved card (`isSavedCardFlow=true`)
2. Processing a name field (billing or full name) designated as card holder name
3. The saved card(s) don't already have complete name information
4. The user has provided a non-empty name value

This is essentially a **conditional update mechanism** for adding missing cardholder names to existing saved payment methods.
