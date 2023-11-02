module RecoilRoot = {
  @module("recoil") @react.component
  external make: (~children: React.element) => React.element = "RecoilRoot"
}

type recoilAtom<'v> = RecoilAtom('v)
type recoilSelector<'v> = RecoilSelector('v)

@module("./recoil")
external atom: (. string, 'v) => recoilAtom<'v> = "atom"

@module("recoil")
external useRecoilState: recoilAtom<'valueT> => ('valueT, (. 'valueT => 'valueT) => unit) =
  "useRecoilState"

@module("recoil")
external useSetRecoilState: (recoilAtom<'valueT>, . 'valueT => 'valueT) => unit =
  "useSetRecoilState"

@module("recoil")
external useRecoilValueFromAtom: recoilAtom<'valueT> => 'valueT = "useRecoilValue"

let useLoggedRecoilState = (atomName, type_, logger: OrcaLogger.loggerMake) => {
  let (state, setState) = useRecoilState(atomName)
  let newSetState = (. value) => {
    LoggerUtils.logInputChangeInfo(type_, logger)
    setState(. value)
  }
  (state, newSetState)
}

let useLoggedSetRecoilState = (atomName, type_, logger: OrcaLogger.loggerMake) => {
  let setState = useSetRecoilState(atomName)
  let newSetState = (. value) => {
    LoggerUtils.logInputChangeInfo(type_, logger)
    setState(. value)
  }
  newSetState
}
