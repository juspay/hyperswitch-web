@react.component
let make = () => {
  let isUpdateIntentLoading = Jotai.useAtomValue(JotaiAtoms.isUpdateIntentLoading)

  <RenderIf condition=isUpdateIntentLoading>
    <GenericLoader
      className="Loader--overlay absolute inset-0 z-[999] rounded-[inherit] backdrop-blur-sm bg-white/40"
    />
  </RenderIf>
}
