@react.component
let make = () => {
  let isUpdateIntentLoading = Recoil.useRecoilValueFromAtom(RecoilAtoms.isUpdateIntentLoading)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  <RenderIf condition=isUpdateIntentLoading>
    <div
      className="absolute inset-0 flex flex-col items-center justify-center gap-2 backdrop-blur-sm bg-white/40 z-[999] rounded-[inherit]">
      <div
        className="w-6 h-6 animate-spin rounded-full border-3 border-black/10 border-t-black/60"
      />
      <div className="text-fs-13 text-black/55 tracking-[0.2px]">
        {localeString.refreshingText->React.string}
      </div>
    </div>
  </RenderIf>
}
