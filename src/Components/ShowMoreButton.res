@react.component
let make = (~displayMergedSavedMethods, ~dropDownOptionsDetails, ~showMore, ~setShowMore) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  <RenderIf condition={displayMergedSavedMethods && dropDownOptionsDetails->Array.length > 0}>
    <div
      className="Label flex flex-row gap-1 items-end cursor-pointer mt-3 text-[14px] font-medium float-left w-fit"
      style={
        color: themeObj.colorPrimary,
      }
      onClick={_ => {
        setShowMore(_ => !showMore)
      }}>
      {showMore ? React.string("Show more") : React.string("Show Less")}
      <div className="m-1">
        {showMore ? <Icon name="arrow-down" size=10 /> : <Icon name="arrow-up" size=10 />}
      </div>
    </div>
  </RenderIf>
}
