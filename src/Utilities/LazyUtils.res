type componentProps
type lazyScreen

type lazyScreenLoader = unit => Js.Promise.t<lazyScreen>

@val
external import_: string => Js.Promise.t<lazyScreen> = "import"

type componentMake<'props> = 'props => React.element
type component = componentProps => React.element
type reactLazy<'props> = (. lazyScreenLoader) => component

@module("react") @val
external reactLazy: reactLazy<'a> = "lazy"
