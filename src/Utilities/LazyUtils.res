type lazyScreen

type lazyScreenLoader = unit => Js.Promise.t<lazyScreen>

@val
external import_: string => Js.Promise.t<lazyScreen> = "import"

type reactLazy<'component> = (. lazyScreenLoader) => 'component

@module("react") @val
external reactLazy: reactLazy<'a> = "lazy"
