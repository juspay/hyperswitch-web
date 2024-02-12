module Shimmer = {
  @react.component
  let make = (~children, ~classname="") => {
    <div
      className={`relative
      ${classname}
    before:absolute before:inset-0
    before:-translate-x-full
    before:animate-[shimmer_1s_infinite]
    before:bg-gradient-to-r
    before:px-1
    before: rounded
    before:from-transparent before:via-slate-200 before:to-transparent overflow-hidden w-full`}>
      children
    </div>
  }
}

module ElementShimmer = {
  @react.component
  let make = (~n=1) => {
    Belt.Array.range(0, n - 1)
    ->Js.Array2.map(index => {
      <Shimmer key={index->Belt.Int.toString}>
        <div className="animate-pulse w-full h-12 rounded bg-slate-200 ">
          <div className="flex flex-row  my-auto">
            <div className=" w-10 h-5 rounded-full m-3 bg-white bg-opacity-70 " />
            <div className=" my-auto w-24 h-2 rounded m-3 bg-white bg-opacity-70 " />
          </div>
        </div>
      </Shimmer>
    })
    ->React.array
  }
}

@react.component
let make = () => {
  <div className="flex flex-col gap-4">
    <ElementShimmer n=2 />
    <div className="flex flex-row gap-4 w-full">
      <ElementShimmer n=2 />
    </div>
  </div>
}
