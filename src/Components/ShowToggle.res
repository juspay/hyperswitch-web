@react.component
let make = (~isMergedSavedMethodsList, ~dropDownOptionsDetails, ~showMore, ~setShowMore) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  <RenderIf condition={isMergedSavedMethodsList && dropDownOptionsDetails->Array.length > 0}>
    <div
      className="Label flex flex-row gap-1 items-end cursor-pointer mt-3"
      style={
        fontSize: "14px",
        float: "left",
        fontWeight: "500",
        width: "fit-content",
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
