import { renderHook, act } from '@testing-library/react';
import * as React from 'react';
import * as OutsideClick from '../Hooks/OutsideClick.bs.js';

describe('useOutsideClick', () => {
  let addEventListenerSpy: jest.SpyInstance;
  let removeEventListenerSpy: jest.SpyInstance;
  let setTimeoutSpy: jest.SpyInstance;

  beforeEach(() => {
    addEventListenerSpy = jest.spyOn(window, 'addEventListener');
    removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
    setTimeoutSpy = jest.spyOn(window, 'setTimeout').mockImplementation((fn: any) => {
      fn();
      return 0 as any;
    });
  });

  afterEach(() => {
    addEventListenerSpy.mockRestore();
    removeEventListenerSpy.mockRestore();
    setTimeoutSpy.mockRestore();
  });

  describe('with ArrayOfRef', () => {
    it('calls callback when click is outside the ref element', () => {
      const callback = jest.fn();
      const mockElement = {
        contains: jest.fn().mockReturnValue(false),
      };
      const ref = { current: mockElement };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).toHaveBeenCalled();
    });

    it('does not call callback when click is inside the ref element', () => {
      const callback = jest.fn();
      const mockElement = {
        contains: jest.fn().mockReturnValue(true),
      };
      const ref = { current: mockElement };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).not.toHaveBeenCalled();
    });

    it('handles null ref element gracefully', () => {
      const callback = jest.fn();
      const ref = { current: null };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).toHaveBeenCalled();
    });
  });

  describe('with RefArray', () => {
    it('calls callback when click is outside all ref elements', () => {
      const callback = jest.fn();
      const mockElement = {
        contains: jest.fn().mockReturnValue(false),
      };
      const containerRef = {
        current: {
          slice: jest.fn().mockReturnValue([mockElement]),
        },
      };
      const refs = { TAG: 'RefArray', _0: containerRef };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).toHaveBeenCalled();
    });

    it('does not call callback when click is inside one of the ref elements', () => {
      const callback = jest.fn();
      const mockElement = {
        contains: jest.fn().mockReturnValue(true),
      };
      const containerRef = {
        current: {
          slice: jest.fn().mockReturnValue([mockElement]),
        },
      };
      const refs = { TAG: 'RefArray', _0: containerRef };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).not.toHaveBeenCalled();
    });

    it('handles null element in ref array gracefully', () => {
      const callback = jest.fn();
      const containerRef = {
        current: {
          slice: jest.fn().mockReturnValue([null]),
        },
      };
      const refs = { TAG: 'RefArray', _0: containerRef };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).toHaveBeenCalled();
    });
  });

  describe('with containerRefs', () => {
    it('calls callback when click is inside container but outside refs', () => {
      const callback = jest.fn();
      const mockElement = {
        contains: jest.fn().mockReturnValue(false),
      };
      const mockContainer = {
        contains: jest.fn().mockReturnValue(true),
      };
      const ref = { current: mockElement };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };
      const containerRefs = { current: mockContainer };

      renderHook(() => OutsideClick.useOutsideClick(refs, containerRefs, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).toHaveBeenCalled();
    });

    it('does not call callback when click is outside container', () => {
      const callback = jest.fn();
      const mockElement = {
        contains: jest.fn().mockReturnValue(false),
      };
      const mockContainer = {
        contains: jest.fn().mockReturnValue(false),
      };
      const ref = { current: mockElement };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };
      const containerRefs = { current: mockContainer };

      renderHook(() => OutsideClick.useOutsideClick(refs, containerRefs, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).not.toHaveBeenCalled();
    });

    it('handles null containerRefs.current gracefully - does not call callback', () => {
      const callback = jest.fn();
      const mockElement = {
        contains: jest.fn().mockReturnValue(false),
      };
      const ref = { current: mockElement };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };
      const containerRefs = { current: null };

      renderHook(() => OutsideClick.useOutsideClick(refs, containerRefs, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).not.toHaveBeenCalled();
    });

    it('calls callback when containerRefs is undefined (no container restriction)', () => {
      const callback = jest.fn();
      const mockElement = {
        contains: jest.fn().mockReturnValue(false),
      };
      const ref = { current: mockElement };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      const clickHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'click'
      )?.[1];

      if (clickHandler) {
        act(() => {
          clickHandler({ target: document.createElement('div') });
        });
      }

      expect(callback).toHaveBeenCalled();
    });
  });

  describe('isActive parameter', () => {
    it('does not add event listener when isActive is false', () => {
      const callback = jest.fn();
      const ref = { current: null };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, false, undefined, callback));

      expect(addEventListenerSpy).not.toHaveBeenCalled();
    });

    it('adds event listener when isActive is true', () => {
      const callback = jest.fn();
      const ref = { current: null };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      expect(addEventListenerSpy).toHaveBeenCalledWith('click', expect.any(Function));
    });
  });

  describe('custom events', () => {
    it('uses custom events when provided', () => {
      const callback = jest.fn();
      const ref = { current: null };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };
      const customEvents = ['mousedown', 'touchstart'];

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, customEvents, callback));

      expect(addEventListenerSpy).toHaveBeenCalledWith('mousedown', expect.any(Function));
      expect(addEventListenerSpy).toHaveBeenCalledWith('touchstart', expect.any(Function));
    });

    it('defaults to click event when no events provided', () => {
      const callback = jest.fn();
      const ref = { current: null };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };

      renderHook(() => OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback));

      expect(addEventListenerSpy).toHaveBeenCalledWith('click', expect.any(Function));
    });
  });

  describe('cleanup', () => {
    it('removes event listeners on unmount', () => {
      const callback = jest.fn();
      const ref = { current: null };
      const refs = { TAG: 'ArrayOfRef', _0: [ref] };

      const { unmount } = renderHook(() =>
        OutsideClick.useOutsideClick(refs, undefined, true, undefined, callback)
      );

      unmount();

      expect(removeEventListenerSpy).toHaveBeenCalledWith('click', expect.any(Function));
    });
  });
});
