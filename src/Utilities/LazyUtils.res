type lazyScreen

type lazyScreenLoader = unit => Promise.t<lazyScreen>

@val
external import_: string => Promise.t<lazyScreen> = "import"

type reactLazy<'component> = lazyScreenLoader => 'component

@module("react") @val
external reactLazy: reactLazy<'a> = "lazy"
