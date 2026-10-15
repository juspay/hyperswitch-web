@react.component
let make = () => {
  let isUpdateIntentLoading = Jotai.useAtomValue(JotaiAtoms.isUpdateIntentLoading)

  <RenderIf condition=isUpdateIntentLoading>
    <div
      className="absolute inset-0 flex items-center justify-center backdrop-blur-sm bg-white/40 z-[999] rounded-[inherit]">
      <GenericLoader />
    </div>
  </RenderIf>
}
