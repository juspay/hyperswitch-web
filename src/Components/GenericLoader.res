@react.component
let make = (~className="") => {
  <div className={`Loader flex items-center justify-center ${className}`}>
    <div
      className="LoaderSpinner inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-[#0069FD] border-r-transparent align-[-0.125em] motion-reduce:animate-[spin_1.5s_linear_infinite]"
      role="status">
      <span
        className="!absolute !-m-px !h-px !w-px !overflow-hidden !whitespace-nowrap !border-0 !p-0 ![clip:rect(0,0,0,0)]">
        {"Loading..."->React.string}
      </span>
    </div>
  </div>
}
