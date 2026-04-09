import {
  getPaymentMode,
  getPaymentModeToString,
  getPaymentModeToStrMapper,
} from '../Types/CardThemeType.bs.js';

describe('CardThemeType', () => {
  describe('getPaymentMode', () => {
    describe('card related modes', () => {
      it('should return Card for "card"', () => {
        expect(getPaymentMode('card')).toBe('Card');
      });

      it('should return CardNumberElement for "cardNumber"', () => {
        expect(getPaymentMode('cardNumber')).toBe('CardNumberElement');
      });

      it('should return CardExpiryElement for "cardExpiry"', () => {
        expect(getPaymentMode('cardExpiry')).toBe('CardExpiryElement');
      });

      it('should return CardCVCElement for "cardCvc"', () => {
        expect(getPaymentMode('cardCvc')).toBe('CardCVCElement');
      });
    });

    describe('wallet modes', () => {
      it('should return GooglePayElement for "googlePay"', () => {
        expect(getPaymentMode('googlePay')).toBe('GooglePayElement');
      });

      it('should return ApplePayElement for "applePay"', () => {
        expect(getPaymentMode('applePay')).toBe('ApplePayElement');
      });

      it('should return SamsungPayElement for "samsungPay"', () => {
        expect(getPaymentMode('samsungPay')).toBe('SamsungPayElement');
      });

      it('should return PayPalElement for "payPal"', () => {
        expect(getPaymentMode('payPal')).toBe('PayPalElement');
      });

      it('should return KlarnaElement for "klarna"', () => {
        expect(getPaymentMode('klarna')).toBe('KlarnaElement');
      });

      it('should return PazeElement for "paze"', () => {
        expect(getPaymentMode('paze')).toBe('PazeElement');
      });

      it('should return ExpressCheckoutElement for "expressCheckout"', () => {
        expect(getPaymentMode('expressCheckout')).toBe('ExpressCheckoutElement');
      });
    });

    describe('other modes', () => {
      it('should return Payment for "payment"', () => {
        expect(getPaymentMode('payment')).toBe('Payment');
      });

      it('should return PaymentMethodCollectElement for "paymentMethodCollect"', () => {
        expect(getPaymentMode('paymentMethodCollect')).toBe('PaymentMethodCollectElement');
      });

      it('should return PaymentMethodsManagement for "paymentMethodsManagement"', () => {
        expect(getPaymentMode('paymentMethodsManagement')).toBe('PaymentMethodsManagement');
      });
    });

    describe('default fallback', () => {
      it('should return NONE for unknown string', () => {
        expect(getPaymentMode('unknown')).toBe('NONE');
      });

      it('should return NONE for empty string', () => {
        expect(getPaymentMode('')).toBe('NONE');
      });

      it('should return NONE for random string', () => {
        expect(getPaymentMode('xyz123')).toBe('NONE');
      });
    });
  });

  describe('getPaymentModeToString', () => {
    describe('card related modes', () => {
      it('should return "card" for Card', () => {
        expect(getPaymentModeToString('Card')).toBe('card');
      });

      it('should return "cardNumber" for CardNumberElement', () => {
        expect(getPaymentModeToString('CardNumberElement')).toBe('cardNumber');
      });

      it('should return "cardExpiry" for CardExpiryElement', () => {
        expect(getPaymentModeToString('CardExpiryElement')).toBe('cardExpiry');
      });

      it('should return "cardCvc" for CardCVCElement', () => {
        expect(getPaymentModeToString('CardCVCElement')).toBe('cardCvc');
      });
    });

    describe('wallet modes', () => {
      it('should return "googlePay" for GooglePayElement', () => {
        expect(getPaymentModeToString('GooglePayElement')).toBe('googlePay');
      });

      it('should return "applePay" for ApplePayElement', () => {
        expect(getPaymentModeToString('ApplePayElement')).toBe('applePay');
      });

      it('should return "samsungPay" for SamsungPayElement', () => {
        expect(getPaymentModeToString('SamsungPayElement')).toBe('samsungPay');
      });

      it('should return "payPal" for PayPalElement', () => {
        expect(getPaymentModeToString('PayPalElement')).toBe('payPal');
      });

      it('should return "klarna" for KlarnaElement', () => {
        expect(getPaymentModeToString('KlarnaElement')).toBe('klarna');
      });

      it('should return "paze" for PazeElement', () => {
        expect(getPaymentModeToString('PazeElement')).toBe('paze');
      });

      it('should return "expressCheckout" for ExpressCheckoutElement', () => {
        expect(getPaymentModeToString('ExpressCheckoutElement')).toBe('expressCheckout');
      });
    });

    describe('other modes', () => {
      it('should return "payment" for Payment', () => {
        expect(getPaymentModeToString('Payment')).toBe('payment');
      });

      it('should return "paymentMethodCollect" for PaymentMethodCollectElement', () => {
        expect(getPaymentModeToString('PaymentMethodCollectElement')).toBe('paymentMethodCollect');
      });

      it('should return "paymentMethodsManagement" for PaymentMethodsManagement', () => {
        expect(getPaymentModeToString('PaymentMethodsManagement')).toBe('paymentMethodsManagement');
      });

      it('should return "none" for NONE', () => {
        expect(getPaymentModeToString('NONE')).toBe('none');
      });
    });
  });

  describe('getPaymentModeToStrMapper', () => {
    it('should return the input string unchanged', () => {
      expect(getPaymentModeToStrMapper('card')).toBe('card');
    });

    it('should return any string unchanged', () => {
      expect(getPaymentModeToStrMapper('googlePay')).toBe('googlePay');
    });

    it('should return empty string unchanged', () => {
      expect(getPaymentModeToStrMapper('')).toBe('');
    });

    it('should return any value passed through', () => {
      expect(getPaymentModeToStrMapper('anyRandomString')).toBe('anyRandomString');
    });
  });

  describe('round-trip conversion', () => {
    it('should round-trip card modes correctly', () => {
      const modes = ['card', 'cardNumber', 'cardExpiry', 'cardCvc'];
      modes.forEach((mode) => {
        const element = getPaymentMode(mode);
        const result = getPaymentModeToString(element);
        expect(result).toBe(mode);
      });
    });

    it('should round-trip wallet modes correctly', () => {
      const modes = ['googlePay', 'applePay', 'samsungPay', 'payPal', 'klarna', 'paze', 'expressCheckout'];
      modes.forEach((mode) => {
        const element = getPaymentMode(mode);
        const result = getPaymentModeToString(element);
        expect(result).toBe(mode);
      });
    });

    it('should round-trip other modes correctly', () => {
      const modes = ['payment', 'paymentMethodCollect', 'paymentMethodsManagement'];
      modes.forEach((mode) => {
        const element = getPaymentMode(mode);
        const result = getPaymentModeToString(element);
        expect(result).toBe(mode);
      });
    });
  });
});
