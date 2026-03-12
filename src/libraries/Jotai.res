type atom<'value> = Atom('value)
type writableAtom<'value, 'args, 'result> = WritableAtom('value, 'args, 'result)

module Provider = {
  @module("jotai") @react.component
  external make: (~children: React.element) => React.element = "Provider"
}

@module("jotai")
external atom: 'value => atom<'value> = "atom"

@module("jotai")
external useAtom: atom<'value> => ('value, ('value => 'value) => unit) = "useAtom"

@module("jotai")
external useAtomValue: atom<'value> => 'value = "useAtomValue"

@module("jotai")
external useSetAtom: atom<'value> => ('value => 'value) => unit = "useSetAtom"

@module("jotai/utils")
external atomFamily: ('param => atom<'value>) => 'param => atom<'value> = "atomFamily"

@module("jotai/utils")
external atomWithStorage: (string, 'value) => atom<'value> = "atomWithStorage"

@module("jotai/utils")
external useResetAtom: atom<'value> => unit => unit = "useResetAtom"

type atomReducer<'value, 'action> = ('value, 'action) => 'value
@module("jotai/utils")
external atomWithReducer: ('value, atomReducer<'value, 'action>) => atom<'value> = "atomWithReducer"

@module("jotai/utils")
external useAtomDebugValue: (atom<'value>, string) => unit = "useDebugValue"
