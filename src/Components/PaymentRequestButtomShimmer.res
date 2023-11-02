module Shimmer = {
  @react.component
  let make = (~children) => {
    <div
      className="relative
    before:absolute before:inset-0
    before:-translate-x-full
    before:animate-[shimmer_1s_infinite]
    before:bg-gradient-to-r
    before:px-1
    before: rounded
    before:from-transparent before:via-slate-200 before:to-transparent overflow-hidden w-full">
      children
    </div>
  }
}

@react.component
let make = () => {
  <div className="flex flex-col gap-4">
    <Shimmer>
      <div className="animate-pulse w-full h-12 rounded bg-slate-200 flex justify-around ">
        <div className="flex flex-col items-center gap-2 place-content-center">
          <div className=" w-36 h-2 rounded p-1 bg-white bg-opacity-70 " />
          <div className=" w-24 h-2 rounded p-1 bg-white bg-opacity-70 " />
        </div>
      </div>
    </Shimmer>
  </div>
}
