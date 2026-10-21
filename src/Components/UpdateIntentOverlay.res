@react.component
let make = () => {
  let isUpdateIntentLoading = Jotai.useAtomValue(JotaiAtoms.isUpdateIntentLoading)

  <RenderIf condition=isUpdateIntentLoading>
    <Loader className="Loader--overlay absolute inset-0 z-[999] rounded-[inherit]" />
  </RenderIf>
}
