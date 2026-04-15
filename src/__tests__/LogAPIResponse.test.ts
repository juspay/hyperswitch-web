import { logApiResponse } from '../hyper-log-catcher/LogAPIResponse.bs.js';

describe('LogAPIResponse', () => {
  describe('logApiResponse', () => {
    let mockLogger: { setLogApi: jest.Mock };

    beforeEach(() => {
      mockLogger = {
        setLogApi: jest.fn(),
      };
    });

    it('should call logger.setLogApi with Success status mapping', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/payments',
        'CONFIRM_CALL',
        'Success',
        200,
        { id: 'payment_123' },
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[1]).toBe('CONFIRM_CALL');
      expect(call[3]).toBe('INFO');
      expect(call[6]).toBe('Response');
    });

    it('should call logger.setLogApi with Error status mapping', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/payments',
        'CONFIRM_CALL',
        'Error',
        400,
        { error: 'Invalid request' },
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[3]).toBe('ERROR');
      expect(call[6]).toBe('Err');
    });

    it('should call logger.setLogApi with Exception status mapping', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/payments',
        'SESSIONS_CALL',
        'Exception',
        504,
        { message: 'Timeout' },
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[3]).toBe('ERROR');
      expect(call[6]).toBe('NoResponse');
    });

    it('should call logger.setLogApi with Request status mapping', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/payments',
        'PAYMENT_METHODS_CALL',
        'Request',
        0,
        {},
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[3]).toBe('INFO');
      expect(call[6]).toBe('Request');
    });

    it('should return early if eventName is undefined', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/payments',
        undefined,
        'Success',
        200,
        { id: 'payment_123' },
        false
      );

      expect(mockLogger.setLogApi).not.toHaveBeenCalled();
    });

    it('should pass isPaymentSession parameter', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/payments',
        'CONFIRM_CALL',
        'Success',
        200,
        { id: 'payment_123' },
        true
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[7]).toBe(true);
    });

    it('should pass logCategory as API', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/payments',
        'RETRIEVE_CALL',
        'Success',
        200,
        { payment: { id: 'pay_123' } },
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[4]).toBe('API');
    });

    it('should pass data object with url and statusCode for Success', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/test',
        'CONFIRM_CALL',
        'Success',
        200,
        { id: 'pay_123' },
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[0].TAG).toBe('ArrayType');
      expect(call[0]._0).toEqual([
        ['url', 'https://api.example.com/test'],
        ['statusCode', 200],
      ]);
    });

    it('should pass data object with url for Request', () => {
      logApiResponse(
        mockLogger as any,
        'https://api.example.com/request',
        'SESSIONS_CALL',
        'Request',
        0,
        {},
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[0].TAG).toBe('ArrayType');
      expect(call[0]._0).toEqual([['url', 'https://api.example.com/request']]);
    });
  });
});
