import {
  defaultShipping,
  defaultOrderDetails,
  getLabel,
  getShippingDetails,
  paypalShippingDetails,
  getOrderDetails,
  shippingAddressItemToObjMapper,
} from '../Types/PaypalSDKTypes.bs.js';

describe('PaypalSDKTypes', () => {
  describe('defaultShipping', () => {
    it('should have all fields undefined', () => {
      expect(defaultShipping.recipientName).toBeUndefined();
      expect(defaultShipping.line1).toBeUndefined();
      expect(defaultShipping.line2).toBeUndefined();
      expect(defaultShipping.city).toBeUndefined();
      expect(defaultShipping.countryCode).toBeUndefined();
      expect(defaultShipping.postalCode).toBeUndefined();
      expect(defaultShipping.state).toBeUndefined();
      expect(defaultShipping.phone).toBeUndefined();
    });
  });

  describe('defaultOrderDetails', () => {
    it('should have default flow of "vault"', () => {
      expect(defaultOrderDetails.flow).toBe('vault');
    });

    it('should have undefined optional fields', () => {
      expect(defaultOrderDetails.billingAgreementDescription).toBeUndefined();
      expect(defaultOrderDetails.enableShippingAddress).toBeUndefined();
      expect(defaultOrderDetails.shippingAddressEditable).toBeUndefined();
      expect(defaultOrderDetails.shippingAddressOverride).toBeUndefined();
    });
  });

  describe('getLabel', () => {
    it('should return "paypal" for "Paypal"', () => {
      expect(getLabel('Paypal')).toBe('paypal');
    });

    it('should return "checkout" for "Checkout"', () => {
      expect(getLabel('Checkout')).toBe('checkout');
    });

    it('should return "buynow" for "Buynow"', () => {
      expect(getLabel('Buynow')).toBe('buynow');
    });

    it('should return "pay" for "Pay"', () => {
      expect(getLabel('Pay')).toBe('pay');
    });

    it('should return "installment" for "Installment"', () => {
      expect(getLabel('Installment')).toBe('installment');
    });
  });

  describe('getShippingDetails', () => {
    it('should return undefined when any required field is missing', () => {
      const shippingObj = {
        recipient_name: 'John Doe',
        line1: '123 Main St',
      };
      const result = getShippingDetails(shippingObj);
      expect(result).toBeUndefined();
    });

    it('should return undefined for invalid input', () => {
      const result = getShippingDetails('not an object');
      expect(result).toBeUndefined();
    });

    it('should handle empty object', () => {
      const result = getShippingDetails({});
      expect(result).toBeUndefined();
    });

    it('should return undefined when fields have undefined values', () => {
      const shippingObj = {
        recipient_name: 'John Doe',
        line1: undefined,
      };
      const result = getShippingDetails(shippingObj);
      expect(result).toBeUndefined();
    });

    it('should return object when all fields are present', () => {
      const shippingObj = {
        recipient_name: 'John Doe',
        line1: '123 Main St',
        line2: 'Apt 4',
        city: 'San Francisco',
        country_code: 'US',
        postal_code: '94105',
        state: 'CA',
        phone: '+14155551234',
      };
      const result = getShippingDetails(shippingObj);
      expect(result).toBeDefined();
      expect(result!.recipientName).toBe('John Doe');
      expect(result!.line1).toBe('123 Main St');
      expect(result!.city).toBe('San Francisco');
      expect(result!.countryCode).toBe('US');
    });
  });

  describe('paypalShippingDetails', () => {
    it('should extract shipping details from purchase unit and payer', () => {
      const purchaseUnit = {
        shipping: {
          address: {
            address_line_1: '456 Oak Ave',
            address_line_2: 'Suite 100',
            admin_area_2: 'Los Angeles',
            country_code: 'US',
            postal_code: '90001',
            admin_area_1: 'CA',
          },
          name: {
            full_name: 'Jane Smith',
          },
        },
      };
      const payerDetails = {
        email: 'jane@example.com',
        phone: '+12125551234',
      };
      const result = paypalShippingDetails(purchaseUnit, payerDetails);
      expect(result.email).toBe('jane@example.com');
      expect(result.phone).toBe('+12125551234');
      expect(result.shippingAddress.recipientName).toBe('Jane Smith');
      expect(result.shippingAddress.line1).toBe('456 Oak Ave');
      expect(result.shippingAddress.line2).toBe('Suite 100');
      expect(result.shippingAddress.city).toBe('Los Angeles');
      expect(result.shippingAddress.countryCode).toBe('US');
      expect(result.shippingAddress.postalCode).toBe('90001');
      expect(result.shippingAddress.state).toBe('CA');
    });

    it('should handle missing optional fields', () => {
      const purchaseUnit = {
        shipping: {
          address: {},
          name: {},
        },
      };
      const payerDetails = {
        email: undefined,
        phone: undefined,
      };
      const result = paypalShippingDetails(purchaseUnit, payerDetails);
      expect(result.email).toBe('');
      expect(result.phone).toBeUndefined();
    });
  });

  describe('getOrderDetails', () => {
    it('should extract flow from order details object', () => {
      const orderDetailsObj = { flow: 'checkout' };
      const result = getOrderDetails(orderDetailsObj, 'PayPalElement');
      expect(result.flow).toBe('checkout');
    });

    it('should return default vault flow when not specified', () => {
      const orderDetailsObj = {};
      const result = getOrderDetails(orderDetailsObj, 'card');
      expect(result.flow).toBe('vault');
    });

    it('should extract enableShippingAddress for wallet element payment type', () => {
      const orderDetailsObj = {
        flow: 'checkout',
        enable_shipping_address: true,
      };
      const result = getOrderDetails(orderDetailsObj, 'PayPalElement');
      expect(result.flow).toBe('checkout');
      expect(result.enableShippingAddress).toBe(true);
    });

    it('should return default values for non-wallet payment type', () => {
      const orderDetailsObj = {
        flow: 'vault',
        enable_shipping_address: true,
      };
      const result = getOrderDetails(orderDetailsObj, 'card');
      expect(result.flow).toBe('vault');
      expect(result.enableShippingAddress).toBeUndefined();
      expect(result.shippingAddressOverride).toBeUndefined();
    });

    it('should handle invalid input gracefully', () => {
      const result = getOrderDetails('invalid', 'card');
      expect(result.flow).toBe('vault');
    });

    it('should return flow value from input object', () => {
      const orderDetailsObj = { flow: 'custom' };
      const result = getOrderDetails(orderDetailsObj, 'card');
      expect(result.flow).toBe('custom');
    });
  });

  describe('shippingAddressItemToObjMapper', () => {
    it('should map all shipping address fields', () => {
      const dict = {
        recipientName: 'John Doe',
        line1: '123 Main St',
        line2: 'Apt 5',
        city: 'Boston',
        countryCode: 'US',
        postalCode: '02101',
        state: 'MA',
        phone: '+16175551234',
      };
      const result = shippingAddressItemToObjMapper(dict);
      expect(result.recipientName).toBe('John Doe');
      expect(result.line1).toBe('123 Main St');
      expect(result.line2).toBe('Apt 5');
      expect(result.city).toBe('Boston');
      expect(result.countryCode).toBe('US');
      expect(result.postalCode).toBe('02101');
      expect(result.state).toBe('MA');
      expect(result.phone).toBe('+16175551234');
    });

    it('should handle empty dict with undefined values', () => {
      const result = shippingAddressItemToObjMapper({});
      expect(result.recipientName).toBeUndefined();
      expect(result.line1).toBeUndefined();
      expect(result.line2).toBeUndefined();
      expect(result.city).toBeUndefined();
      expect(result.countryCode).toBeUndefined();
      expect(result.postalCode).toBeUndefined();
      expect(result.state).toBeUndefined();
      expect(result.phone).toBeUndefined();
    });

    it('should handle partial shipping address', () => {
      const dict = {
        countryCode: 'GB',
        postalCode: 'SW1A 1AA',
        city: 'London',
      };
      const result = shippingAddressItemToObjMapper(dict);
      expect(result.countryCode).toBe('GB');
      expect(result.postalCode).toBe('SW1A 1AA');
      expect(result.city).toBe('London');
      expect(result.recipientName).toBeUndefined();
    });
  });
});
