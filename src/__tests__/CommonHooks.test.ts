import { renderHook, act } from '@testing-library/react';
import * as CommonHooks from "../Hooks/CommonHooks.bs.js";

describe("CommonHooks", () => {
  describe("useScript", () => {
    let createElementSpy: jest.SpyInstance;
    let querySelectorSpy: jest.SpyInstance;
    let appendChildSpy: jest.SpyInstance;
    let mockScriptElement: any;
    let container: HTMLDivElement;

    beforeEach(() => {
      container = document.createElement('div');
      document.body.appendChild(container);
      
      mockScriptElement = {
        src: '',
        type: '',
        async: false,
        setAttribute: jest.fn(),
        getAttribute: jest.fn(),
        addEventListener: jest.fn(),
        removeEventListener: jest.fn(),
        remove: jest.fn(),
      };

      const originalCreateElement = document.createElement.bind(document);
      createElementSpy = jest.spyOn(document, 'createElement').mockImplementation((tagName: string) => {
        if (tagName === 'script') return mockScriptElement;
        return originalCreateElement(tagName);
      });
      querySelectorSpy = jest.spyOn(document, 'querySelector').mockReturnValue(null);
      appendChildSpy = jest.spyOn(document.body, 'appendChild').mockImplementation(() => mockScriptElement);
    });

    afterEach(() => {
      if (container.parentNode) {
        container.parentNode.removeChild(container);
      }
      createElementSpy.mockRestore();
      querySelectorSpy.mockRestore();
      appendChildSpy.mockRestore();
      jest.clearAllMocks();
    });

    it("returns 'idle' when src is empty", () => {
      const { result } = renderHook(() => CommonHooks.useScript(""), { container });
      expect(result.current).toBe("idle");
    });

    it("returns 'loading' when src is provided and script doesn't exist", () => {
      querySelectorSpy.mockReturnValue(null);
      const { result } = renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });
      expect(result.current).toBe("loading");
    });

    it("creates script element with correct attributes", () => {
      renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      expect(createElementSpy).toHaveBeenCalledWith("script");
      expect(mockScriptElement.src).toBe("https://example.com/script.js");
      expect(mockScriptElement.async).toBe(true);
      expect(mockScriptElement.setAttribute).toHaveBeenCalledWith("data-status", "loading");
    });

    it("sets script type when provided", () => {
      renderHook(() => CommonHooks.useScript("https://example.com/script.js", "module"), { container });

      expect(mockScriptElement.type).toBe("module");
    });

    it("does not set script type when not provided", () => {
      renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      expect(mockScriptElement.type).toBe("");
    });

    it("appends script to document body", () => {
      renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      expect(appendChildSpy).toHaveBeenCalledWith(mockScriptElement);
    });

    it("returns existing script status when script already exists", () => {
      const existingScript = {
        getAttribute: jest.fn().mockReturnValue("ready"),
      };
      querySelectorSpy.mockReturnValue(existingScript);

      const { result } = renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      expect(result.current).toBe("ready");
      expect(createElementSpy).not.toHaveBeenCalled();
    });

    it("sets up load event listener", () => {
      renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      expect(mockScriptElement.addEventListener).toHaveBeenCalledWith("load", expect.any(Function));
    });

    it("sets up error event listener", () => {
      renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      expect(mockScriptElement.addEventListener).toHaveBeenCalledWith("error", expect.any(Function));
    });

    it("updates status to 'ready' on load event", () => {
      let loadHandler: Function | null = null;
      mockScriptElement.addEventListener.mockImplementation((event: string, handler: Function) => {
        if (event === 'load') loadHandler = handler;
      });

      const { result } = renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      act(() => {
        loadHandler?.({ type: 'load' });
      });

      expect(result.current).toBe("ready");
    });

    it("updates status to 'error' on error event", () => {
      let errorHandler: Function | null = null;
      mockScriptElement.addEventListener.mockImplementation((event: string, handler: Function) => {
        if (event === 'error') errorHandler = handler;
      });

      const { result } = renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      act(() => {
        errorHandler?.({ type: 'error' });
      });

      expect(result.current).toBe("error");
    });

    it("removes event listeners on unmount", () => {
      const { unmount } = renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      unmount();

      expect(mockScriptElement.removeEventListener).toHaveBeenCalledWith("load", expect.any(Function));
      expect(mockScriptElement.removeEventListener).toHaveBeenCalledWith("error", expect.any(Function));
    });

    it("removes script on unmount if not ready", () => {
      mockScriptElement.getAttribute.mockReturnValue("error");

      const { unmount } = renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      unmount();

      expect(mockScriptElement.remove).toHaveBeenCalled();
    });

    it("does not remove script on unmount if ready", () => {
      mockScriptElement.getAttribute.mockReturnValue("ready");

      const { unmount } = renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      unmount();

      expect(mockScriptElement.remove).not.toHaveBeenCalled();
    });

    it("sets data-status attribute on load", () => {
      let loadHandler: Function | null = null;
      mockScriptElement.addEventListener.mockImplementation((event: string, handler: Function) => {
        if (event === 'load') loadHandler = handler;
      });

      renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      act(() => {
        loadHandler?.({ type: 'load' });
      });

      expect(mockScriptElement.setAttribute).toHaveBeenCalledWith("data-status", "ready");
    });

    it("sets data-status attribute on error", () => {
      let errorHandler: Function | null = null;
      mockScriptElement.addEventListener.mockImplementation((event: string, handler: Function) => {
        if (event === 'error') errorHandler = handler;
      });

      renderHook(() => CommonHooks.useScript("https://example.com/script.js"), { container });

      act(() => {
        errorHandler?.({ type: 'error' });
      });

      expect(mockScriptElement.setAttribute).toHaveBeenCalledWith("data-status", "error");
    });
  });

  describe("useLink", () => {
    let createElementSpy: jest.SpyInstance;
    let querySelectorSpy: jest.SpyInstance;
    let appendChildSpy: jest.SpyInstance;
    let mockLinkElement: any;
    let container: HTMLDivElement;

    beforeEach(() => {
      container = document.createElement('div');
      document.body.appendChild(container);
      
      mockLinkElement = {
        href: '',
        rel: '',
        setAttribute: jest.fn(),
        getAttribute: jest.fn(),
        addEventListener: jest.fn(),
        removeEventListener: jest.fn(),
      };

      const originalCreateElement = document.createElement.bind(document);
      createElementSpy = jest.spyOn(document, 'createElement').mockImplementation((tagName: string) => {
        if (tagName === 'link') return mockLinkElement;
        return originalCreateElement(tagName);
      });
      querySelectorSpy = jest.spyOn(document, 'querySelector').mockReturnValue(null);
      appendChildSpy = jest.spyOn(document.body, 'appendChild').mockImplementation(() => mockLinkElement);
    });

    afterEach(() => {
      if (container.parentNode) {
        container.parentNode.removeChild(container);
      }
      createElementSpy.mockRestore();
      querySelectorSpy.mockRestore();
      appendChildSpy.mockRestore();
      jest.clearAllMocks();
    });

    it("returns 'idle' when src is empty", () => {
      const { result } = renderHook(() => CommonHooks.useLink(""), { container });
      expect(result.current).toBe("idle");
    });

    it("returns 'loading' when src is provided and link doesn't exist", () => {
      querySelectorSpy.mockReturnValue(null);
      const { result } = renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });
      expect(result.current).toBe("loading");
    });

    it("creates link element with correct attributes", () => {
      renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      expect(createElementSpy).toHaveBeenCalledWith("link");
      expect(mockLinkElement.href).toBe("https://example.com/styles.css");
      expect(mockLinkElement.rel).toBe("stylesheet");
      expect(mockLinkElement.setAttribute).toHaveBeenCalledWith("data-status", "loading");
    });

    it("appends link to document body", () => {
      renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      expect(appendChildSpy).toHaveBeenCalledWith(mockLinkElement);
    });

    it("returns existing link status when link already exists", () => {
      const existingLink = {
        getAttribute: jest.fn().mockReturnValue("ready"),
      };
      querySelectorSpy.mockReturnValue(existingLink);

      const { result } = renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      expect(result.current).toBe("ready");
      expect(createElementSpy).not.toHaveBeenCalled();
    });

    it("sets up load event listener", () => {
      renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      expect(mockLinkElement.addEventListener).toHaveBeenCalledWith("load", expect.any(Function));
    });

    it("sets up error event listener", () => {
      renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      expect(mockLinkElement.addEventListener).toHaveBeenCalledWith("error", expect.any(Function));
    });

    it("updates status to 'ready' on load event", () => {
      let loadHandler: Function | null = null;
      mockLinkElement.addEventListener.mockImplementation((event: string, handler: Function) => {
        if (event === 'load') loadHandler = handler;
      });

      const { result } = renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      act(() => {
        loadHandler?.({ type: 'load' });
      });

      expect(result.current).toBe("ready");
    });

    it("updates status to 'error' on error event", () => {
      let errorHandler: Function | null = null;
      mockLinkElement.addEventListener.mockImplementation((event: string, handler: Function) => {
        if (event === 'error') errorHandler = handler;
      });

      const { result } = renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      act(() => {
        errorHandler?.({ type: 'error' });
      });

      expect(result.current).toBe("error");
    });

    it("removes event listeners on unmount", () => {
      const { unmount } = renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      unmount();

      expect(mockLinkElement.removeEventListener).toHaveBeenCalledWith("load", expect.any(Function));
      expect(mockLinkElement.removeEventListener).toHaveBeenCalledWith("error", expect.any(Function));
    });

    it("sets data-status attribute on load", () => {
      let loadHandler: Function | null = null;
      mockLinkElement.addEventListener.mockImplementation((event: string, handler: Function) => {
        if (event === 'load') loadHandler = handler;
      });

      renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      act(() => {
        loadHandler?.({ type: 'load' });
      });

      expect(mockLinkElement.setAttribute).toHaveBeenCalledWith("data-status", "ready");
    });

    it("sets data-status attribute on error", () => {
      let errorHandler: Function | null = null;
      mockLinkElement.addEventListener.mockImplementation((event: string, handler: Function) => {
        if (event === 'error') errorHandler = handler;
      });

      renderHook(() => CommonHooks.useLink("https://example.com/styles.css"), { container });

      act(() => {
        errorHandler?.({ type: 'error' });
      });

      expect(mockLinkElement.setAttribute).toHaveBeenCalledWith("data-status", "error");
    });
  });

  describe("updateKeys", () => {
    it("updates paymentId when key is 'paymentId' and dict has the key", () => {
      const dict = { paymentId: "pay_12345" };
      const keyPair = ["paymentId", "pay_12345"];
      let updatedState: any = null;
      const setKeys = (fn: (prev: any) => any) => {
        updatedState = fn({
          paymentId: "",
          publishableKey: "",
          profileId: "",
          iframeId: "",
          parentURL: "*",
          sdkHandleOneClickConfirmPayment: true,
        });
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(updatedState).not.toBeNull();
      expect(updatedState.paymentId).toBe("pay_12345");
    });

    it("updates publishableKey when key is 'publishableKey' and dict has the key", () => {
      const dict = { publishableKey: "pk_test_123" };
      const keyPair = ["publishableKey", "pk_test_123"];
      let updatedState: any = null;
      const setKeys = (fn: (prev: any) => any) => {
        updatedState = fn({
          paymentId: "",
          publishableKey: "",
          profileId: "",
          iframeId: "",
          parentURL: "*",
          sdkHandleOneClickConfirmPayment: true,
        });
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(updatedState).not.toBeNull();
      expect(updatedState.publishableKey).toBe("pk_test_123");
    });

    it("updates profileId when key is 'profileId' and dict has the key", () => {
      const dict = { profileId: "prof_123" };
      const keyPair = ["profileId", "prof_123"];
      let updatedState: any = null;
      const setKeys = (fn: (prev: any) => any) => {
        updatedState = fn({
          paymentId: "",
          publishableKey: "",
          profileId: "",
          iframeId: "",
          parentURL: "*",
          sdkHandleOneClickConfirmPayment: true,
        });
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(updatedState).not.toBeNull();
      expect(updatedState.profileId).toBe("prof_123");
    });

    it("updates iframeId when key is 'iframeId' and dict has the key", () => {
      const dict = { iframeId: "iframe_123" };
      const keyPair = ["iframeId", "iframe_123"];
      let updatedState: any = null;
      const setKeys = (fn: (prev: any) => any) => {
        updatedState = fn({
          paymentId: "",
          publishableKey: "",
          profileId: "",
          iframeId: "",
          parentURL: "*",
          sdkHandleOneClickConfirmPayment: true,
        });
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(updatedState).not.toBeNull();
      expect(updatedState.iframeId).toBe("iframe_123");
    });

    it("updates parentURL when key is 'parentURL' and dict has the key", () => {
      const dict = { parentURL: "https://example.com" };
      const keyPair = ["parentURL", "https://example.com"];
      let updatedState: any = null;
      const setKeys = (fn: (prev: any) => any) => {
        updatedState = fn({
          paymentId: "",
          publishableKey: "",
          profileId: "",
          iframeId: "",
          parentURL: "*",
          sdkHandleOneClickConfirmPayment: true,
        });
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(updatedState).not.toBeNull();
      expect(updatedState.parentURL).toBe("https://example.com");
    });

    it("updates sdkHandleOneClickConfirmPayment when key is 'sdkHandleOneClickConfirmPayment' and dict has the key", () => {
      const dict = { sdkHandleOneClickConfirmPayment: false };
      const keyPair = ["sdkHandleOneClickConfirmPayment", false];
      let updatedState: any = null;
      const setKeys = (fn: (prev: any) => any) => {
        updatedState = fn({
          paymentId: "",
          publishableKey: "",
          profileId: "",
          iframeId: "",
          parentURL: "*",
          sdkHandleOneClickConfirmPayment: true,
        });
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(updatedState).not.toBeNull();
      expect(updatedState.sdkHandleOneClickConfirmPayment).toBe(false);
    });

    it("does not update state when key is not in dict", () => {
      const dict = {};
      const keyPair = ["paymentId", "pay_12345"];
      let called = false;
      const setKeys = () => {
        called = true;
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(called).toBe(false);
    });

    it("does not update state for unknown keys", () => {
      const dict = { unknownKey: "value" };
      const keyPair = ["unknownKey", "value"];
      let called = false;
      const setKeys = () => {
        called = true;
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(called).toBe(false);
    });

    it("preserves other state fields when updating one field", () => {
      const dict = { paymentId: "pay_12345" };
      const keyPair = ["paymentId", "pay_12345"];
      let updatedState: any = null;
      const setKeys = (fn: (prev: any) => any) => {
        updatedState = fn({
          paymentId: "old_payment",
          publishableKey: "pk_old",
          profileId: "prof_old",
          iframeId: "iframe_old",
          parentURL: "https://old.com",
          sdkHandleOneClickConfirmPayment: false,
        });
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(updatedState.paymentId).toBe("pay_12345");
      expect(updatedState.publishableKey).toBe("pk_old");
      expect(updatedState.profileId).toBe("prof_old");
      expect(updatedState.iframeId).toBe("iframe_old");
      expect(updatedState.parentURL).toBe("https://old.com");
      expect(updatedState.sdkHandleOneClickConfirmPayment).toBe(false);
    });

    it("updates sdkHandleOneClickConfirmPayment to true when value is true", () => {
      const dict = { sdkHandleOneClickConfirmPayment: true };
      const keyPair = ["sdkHandleOneClickConfirmPayment", true];
      let updatedState: any = null;
      const setKeys = (fn: (prev: any) => any) => {
        updatedState = fn({
          paymentId: "",
          publishableKey: "",
          profileId: "",
          iframeId: "",
          parentURL: "*",
          sdkHandleOneClickConfirmPayment: false,
        });
      };

      CommonHooks.updateKeys(dict, keyPair, setKeys);

      expect(updatedState.sdkHandleOneClickConfirmPayment).toBe(true);
    });
  });

  describe("defaultkeys", () => {
    it("has expected default values", () => {
      expect(CommonHooks.defaultkeys.paymentId).toBe("");
      expect(CommonHooks.defaultkeys.publishableKey).toBe("");
      expect(CommonHooks.defaultkeys.profileId).toBe("");
      expect(CommonHooks.defaultkeys.iframeId).toBe("");
      expect(CommonHooks.defaultkeys.parentURL).toBe("*");
      expect(CommonHooks.defaultkeys.sdkHandleOneClickConfirmPayment).toBe(true);
    });

    it("is an object with all required keys", () => {
      expect(CommonHooks.defaultkeys).toHaveProperty("paymentId");
      expect(CommonHooks.defaultkeys).toHaveProperty("publishableKey");
      expect(CommonHooks.defaultkeys).toHaveProperty("profileId");
      expect(CommonHooks.defaultkeys).toHaveProperty("iframeId");
      expect(CommonHooks.defaultkeys).toHaveProperty("parentURL");
      expect(CommonHooks.defaultkeys).toHaveProperty("sdkHandleOneClickConfirmPayment");
    });
  });
});
