@react.component
let make = React.memo((~name: string) => {
  let (_, setPortalNodes) = Recoil.useRecoilState(RecoilAtoms.portalNodes)
  let setDiv = React.useCallback2((elem: Nullable.t<Dom.element>) => {
    setPortalNodes(.
      prevDict => {
        let clonedDict =
          prevDict
          ->Dict.toArray
          ->Array.filter(
            entry => {
              let (key, _val) = entry
              key !== name
            },
          )
          ->Dict.fromArray

        switch elem->Nullable.toOption {
        | Some(elem) => Dict.set(clonedDict, name, elem)
        | None => ()
        }

        clonedDict
      },
    )
  }, (setPortalNodes, name))

  <div id="sss" ref={ReactDOM.Ref.callbackDomRef(setDiv)} />
})
