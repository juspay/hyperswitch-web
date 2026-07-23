// Jotai v2 ReScript bindings
//
// DESIGN NOTE — Provider:
//   Jotai v2's Provider component is optional; without it all atoms use the
//   global default store. We keep Provider in Index.res to match the semantics
//   of the previous root provider: each SDK mount gets its own isolated store.
//   This matters when multiple SDK instances run on the same page (e.g. stacked
//   iframes) — without a Provider they would share state across instances.
module Provider = {
  @module("jotai") @react.component
  external make: (~children: React.element) => React.element = "Provider"
}

// Abstract atom type — mirrors Jotai's WritableAtom at the JS level.
// We expose only the primitive atom shape; derived/async atoms are out of scope.
type atom<'v>

// atom(initialValue) — Jotai does not require a string key.
// Atom identity is object identity; each module-level `let` creates one atom.
@module("jotai") external atom: 'v => atom<'v> = "atom"

// useAtom — returns a (value, setter) 2-tuple.
//
// DESIGN NOTE — updater-only setter:
//   Jotai v2's setter accepts EITHER a direct value (T) OR an updater function
//   ((prev: T) => T). We bind it here as the updater-function form only —
//   ('v => 'v) => unit — because every setter call site in this
//   codebase uses the updater pattern: setter(prev => {...prev, field: newVal})
//   Binding the full discriminated union would require wrapping every setter site
//   with an Update(...) constructor. The updater-only binding is the correct
//   tradeoff. For new code wanting direct assignment, use: setter(_ => newValue)
//
// Runtime note: ReScript 2-tuples compile to JS 2-element arrays.
// Jotai returns [value, setter] from useAtom, which destructures correctly.
@module("jotai") external useAtom: atom<'v> => ('v, ('v => 'v) => unit) = "useAtom"

// useSetAtom — subscribe to the setter ONLY. Component does NOT re-render on value change.
@module("jotai") external useSetAtom: atom<'v> => ('v => 'v) => unit = "useSetAtom"

// useAtomValue — read-only. Component re-renders when value changes; no setter.
@module("jotai") external useAtomValue: atom<'v> => 'v = "useAtomValue"
