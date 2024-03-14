@react.component
let make = () => {
  let loaderUI =
    <div className={`flex flex-col justify-center m-auto visible`}>
      <Loader />
    </div>
  <div className="h-screen w-screen bg-black/80 flex m-auto items-center backdrop-blur-md">
    {loaderUI}
  </div>
}
