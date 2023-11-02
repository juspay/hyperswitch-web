import {
    RecoilRoot,
    atom as recoilAtom,
    selector,
    useRecoilState,
    useRecoilValue,
} from "recoil";

export function atom(key, defaultVal) {
    return recoilAtom({ key, default: defaultVal });
}
