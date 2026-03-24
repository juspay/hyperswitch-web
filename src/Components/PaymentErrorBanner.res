@react.component
let make = () => {
  let errorMessage = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentFailedErrorMessage)

  <RenderIf condition={errorMessage->String.length > 0}>
    <div
      className="flex flex-row items-center gap-2 p-3 rounded-lg"
      style={
        backgroundColor: "#FEF0F0",
        border: "1px solid #F5C6C6",
      }>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="#545454"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="flex-shrink-0">
        <circle cx="12" cy="12" r="10" />
        <line x1="12" y1="16" x2="12" y2="12" />
        <line x1="12" y1="8" x2="12.01" y2="8" />
      </svg>
      <span
        className="text-sm"
        style={
          color: "#545454",
        }>
        {React.string(errorMessage)}
      </span>
    </div>
  </RenderIf>
}
