type observer = {observe: (. Dom.element) => unit}
type dimensions = {
  height: float,
  width: float,
}
type ele = {contentRect: dimensions}
@new external newResizerObserver: (Js.Array2.t<ele> => unit) => observer = "ResizeObserver"
