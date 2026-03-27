@react.component
let make = () => {
  let isUpdateIntentLoading = Recoil.useRecoilValueFromAtom(RecoilAtoms.isUpdateIntentLoading)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  <RenderIf condition=isUpdateIntentLoading>
    <div
      className="absolute inset-0 flex flex-col items-center justify-center gap-2 backdrop-blur-sm bg-white/40"
      style={
        zIndex: "999",
        borderRadius: "inherit",
      }>
      <div
        className="w-6 h-6 animate-spin rounded-full"
        style={
          border: "3px solid rgba(0, 0, 0, 0.1)",
          borderTopColor: "rgba(0, 0, 0, 0.6)",
        }
      />
      <div
        style={
          fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
          fontSize: "13px",
          color: "rgba(0, 0, 0, 0.55)",
          letterSpacing: "0.2px",
        }>
        {localeString.refreshingText->React.string}
      </div>
    </div>
  </RenderIf>
}
