import React from "react";
import type { PrimitiveAtom, WritableAtom } from "jotai";
import type { RenderOptions } from "@testing-library/react";
import { createStore, Provider } from "jotai";
import { render } from "@testing-library/react";
import { configAtom } from "../../src/Utilities/JotaiAtoms.bs.js";
import { defaultJotaiConfig } from "../../src/CardTheme.bs.js";
import { context as PaymentTypeContext } from "../../src/Context/PaymentTypeContext.bs.js";

export * from "@testing-library/react";

// Locale defaults contain formatter functions. Clone mutable data recursively
// while retaining those functions instead of using structuredClone/JSON.
function cloneDefaults<T>(value: T): T {
  if (Array.isArray(value)) return value.map(cloneDefaults) as T;
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, cloneDefaults(child)])) as T;
  }
  return value;
}

declare const initialValueBrand: unique symbol;
export type InitialValue = readonly [WritableAtom<unknown, never[], unknown>, unknown] & { readonly [initialValueBrand]: true };

// Validate each atom/value pair before erasing its type for heterogeneous storage.
// NoInfer prevents the value from broadening the atom's own value type.
export function initialValue<T>(atom: PrimitiveAtom<T>, value: NoInfer<T>): InitialValue {
  return [atom, value] as unknown as InitialValue;
}
type SdkRenderOptions = RenderOptions & { initialValues?: Iterable<InitialValue>; paymentType?: string };

export function renderWithSdk(ui: React.ReactNode, { initialValues = [], paymentType, wrapper: Wrapper, ...renderOptions }: SdkRenderOptions = {}) {
  const store = createStore();
  store.set(configAtom, cloneDefaults(defaultJotaiConfig));
  // Entry construction checks correlation; erase only the heterogeneous store write.
  for (const [atom, value] of initialValues) store.set(atom as WritableAtom<unknown, [unknown], unknown>, value);

  function SdkProvider({ children }: React.PropsWithChildren) {
    const wrappedChildren = Wrapper ? <Wrapper>{children}</Wrapper> : children;
    const content = paymentType === undefined ? wrappedChildren : (
      <PaymentTypeContext.Provider value={{ paymentType }}>{wrappedChildren}</PaymentTypeContext.Provider>
    );
    return <Provider store={store}>{content}</Provider>;
  }

  return { ...render(ui, { ...renderOptions, wrapper: SdkProvider }), store };
}
