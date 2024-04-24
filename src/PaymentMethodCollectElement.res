open RecoilAtoms

@react.component
let make = (
  ~enabled_payment_methods: array<PaymentMethodCollectUtils.paymentMethodType>,
  ~integrateError,
  ~logger,
) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(elementOptions)

  if integrateError {
    <ErrorOccured />
  } else {
    <div disabled=options.disabled className="flex flex-col">
      <div className="flex flex-row m-auto w-full justify-between items-center">
        {React.string("Hey")}
      </div>
    </div>
  }
}

let default = make
