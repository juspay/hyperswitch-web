import { renderHook, act } from '@testing-library/react';
import { defaultNetworkState, getNetworkState, useNetworkInformation } from '../Hooks/NetworkInformation.bs.js';

declare global {
  var navigator: Navigator;
}

describe('NetworkInformation', () => {
  describe('defaultNetworkState', () => {
    describe('structure', () => {
      it('should have isOnline property defaulting to true', () => {
        expect(defaultNetworkState.isOnline).toBe(true);
      });

      it('should have empty effectiveType string', () => {
        expect(defaultNetworkState.effectiveType).toBe('');
      });

      it('should have zero downlink value', () => {
        expect(defaultNetworkState.downlink).toBe(0);
      });

      it('should have zero rtt value', () => {
        expect(defaultNetworkState.rtt).toBe(0);
      });
    });

    describe('type checking', () => {
      it('should be an object', () => {
        expect(typeof defaultNetworkState).toBe('object');
      });

      it('should have exactly 4 properties', () => {
        expect(Object.keys(defaultNetworkState)).toHaveLength(4);
      });

      it('should have isOnline as boolean', () => {
        expect(typeof defaultNetworkState.isOnline).toBe('boolean');
      });

      it('should have effectiveType as string', () => {
        expect(typeof defaultNetworkState.effectiveType).toBe('string');
      });

      it('should have downlink as number', () => {
        expect(typeof defaultNetworkState.downlink).toBe('number');
      });

      it('should have rtt as number', () => {
        expect(typeof defaultNetworkState.rtt).toBe('number');
      });
    });
  });

  describe('getNetworkState', () => {
    const originalNavigator = globalThis.navigator;

    beforeEach(() => {
      Object.defineProperty(globalThis, 'navigator', {
        value: {} as Navigator,
        writable: true,
        configurable: true,
      });
    });

    afterEach(() => {
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        writable: true,
        configurable: true,
      });
    });

    describe('when navigator.connection is not available', () => {
      it('should return "NOT_AVAILABLE" when connection is null', () => {
        Object.defineProperty(globalThis.navigator, 'connection', {
          value: null,
          configurable: true,
        });
        expect(getNetworkState()).toBe('NOT_AVAILABLE');
      });

      it('should return "NOT_AVAILABLE" when connection is undefined', () => {
        Object.defineProperty(globalThis.navigator, 'connection', {
          value: undefined,
          configurable: true,
        });
        expect(getNetworkState()).toBe('NOT_AVAILABLE');
      });
    });

    describe('when navigator.connection is available', () => {
      it('should return network state object with valid connection', () => {
        Object.defineProperty(globalThis.navigator, 'connection', {
          value: {
            effectiveType: '4g',
            downlink: 10,
            rtt: 50,
          },
          configurable: true,
        });
        Object.defineProperty(globalThis.navigator, 'onLine', {
          value: true,
          configurable: true,
        });

        const result = getNetworkState() as { TAG: string; _0: { isOnline: boolean; effectiveType: string; downlink: number; rtt: number } };

        expect(result).toHaveProperty('TAG', 'Value');
        expect(result._0).toEqual({
          isOnline: true,
          effectiveType: '4g',
          downlink: 10,
          rtt: 50,
        });
      });

      it('should return correct values when offline', () => {
        Object.defineProperty(globalThis.navigator, 'connection', {
          value: {
            effectiveType: '3g',
            downlink: 5,
            rtt: 100,
          },
          configurable: true,
        });
        Object.defineProperty(globalThis.navigator, 'onLine', {
          value: false,
          configurable: true,
        });

        const result = getNetworkState() as { TAG: string; _0: { isOnline: boolean; effectiveType: string; downlink: number; rtt: number } };

        expect(result._0.isOnline).toBe(false);
        expect(result._0.effectiveType).toBe('3g');
      });

      it('should handle slow connection types', () => {
        Object.defineProperty(globalThis.navigator, 'connection', {
          value: {
            effectiveType: '2g',
            downlink: 0.5,
            rtt: 300,
          },
          configurable: true,
        });
        Object.defineProperty(globalThis.navigator, 'onLine', {
          value: true,
          configurable: true,
        });

        const result = getNetworkState() as { TAG: string; _0: { isOnline: boolean; effectiveType: string; downlink: number; rtt: number } };

        expect(result._0.effectiveType).toBe('2g');
        expect(result._0.downlink).toBe(0.5);
        expect(result._0.rtt).toBe(300);
      });
    });
  });

  describe('useNetworkInformation', () => {
    let addEventListenerSpy: jest.SpyInstance;
    let removeEventListenerSpy: jest.SpyInstance;

    beforeEach(() => {
      addEventListenerSpy = jest.spyOn(window, 'addEventListener');
      removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
    });

    afterEach(() => {
      addEventListenerSpy.mockRestore();
      removeEventListenerSpy.mockRestore();
    });

    it('should return NOT_AVAILABLE when navigator.connection is null', () => {
      const originalConnection = Object.getOwnPropertyDescriptor(navigator, 'connection');
      Object.defineProperty(navigator, 'connection', {
        value: null,
        configurable: true,
      });

      const { result } = renderHook(() => useNetworkInformation());
      expect(result.current).toBe('NOT_AVAILABLE');

      if (originalConnection) {
        Object.defineProperty(navigator, 'connection', originalConnection);
      }
    });

    it('should return network state value when connection is available', () => {
      const { result } = renderHook(() => useNetworkInformation());
      
      const state = result.current;
      expect(state).toBeDefined();
      
      if (state !== 'NOT_AVAILABLE') {
        const networkState = state as { TAG: string; _0: { isOnline: boolean; effectiveType: string; downlink: number; rtt: number } };
        expect(networkState).toHaveProperty('TAG', 'Value');
        expect(networkState._0).toHaveProperty('isOnline');
        expect(networkState._0).toHaveProperty('effectiveType');
        expect(networkState._0).toHaveProperty('downlink');
        expect(networkState._0).toHaveProperty('rtt');
      }
    });

    it('should register event listeners on mount', () => {
      renderHook(() => useNetworkInformation());
      expect(addEventListenerSpy).toHaveBeenCalledWith('load', expect.any(Function));
      expect(addEventListenerSpy).toHaveBeenCalledWith('online', expect.any(Function));
      expect(addEventListenerSpy).toHaveBeenCalledWith('offline', expect.any(Function));
    });

    it('should remove event listeners on unmount', () => {
      const { unmount } = renderHook(() => useNetworkInformation());
      unmount();
      expect(removeEventListenerSpy).toHaveBeenCalledWith('load', expect.any(Function));
      expect(removeEventListenerSpy).toHaveBeenCalledWith('online', expect.any(Function));
      expect(removeEventListenerSpy).toHaveBeenCalledWith('offline', expect.any(Function));
    });
  });
});
