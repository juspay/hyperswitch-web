type observer = {observe: Dom.element => unit}
type dimensions = {
  height: float,
  width: float,
}
type ele = {contentRect: dimensions}
@new external newResizerObserver: (array<ele> => unit) => observer = "ResizeObserver"
