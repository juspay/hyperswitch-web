let useResizeObserver = (
  ~elementRef: React.ref<Nullable.t<Dom.element>>,
  ~enabled=true,
  ~refreshKey="",
  ~onResize: unit => unit,
) => {
  let onResizeRef = React.useRef(onResize)
  onResizeRef.current = onResize

  React.useEffect(() => {
    if enabled {
      let observer = ResizeObserver.newResizerObserver(_ => onResizeRef.current())
      switch elementRef.current->Nullable.toOption {
      | Some(el) =>
        onResizeRef.current()
        observer.observe(el)
      | None => ()
      }
      Some(() => observer.disconnect())
    } else {
      None
    }
  }, (enabled, refreshKey))
}
