open PaymentMethodCollectTypes
open PaymentMethodCollectUtils
open RecoilAtoms

@react.component
let make = (~integrateError, ~logger) => {
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(paymentMethodCollectOptionAtom)

  // Component states
  let (availablePaymentMethods, setAvailablePaymentMethods) = React.useState(_ =>
    defaultAvailablePaymentMethods
  )
  let (availablePaymentMethodTypes, setAvailablePaymentMethodTypes) = React.useState(_ =>
    defaultAvailablePaymentMethodTypes
  )
  let (apiError, setApiError) = React.useState(_ => None)
  let (apiResponse, setApiResponse) = React.useState(_ => None)
  let (amount, setAmount) = React.useState(_ => options.amount)
  let (currency, setCurrency) = React.useState(_ => options.currency)
  let (flow, setFlow) = React.useState(_ => options.flow)
  let (linkId, setLinkId) = React.useState(_ => options.linkId)
  let (loader, setLoader) = React.useState(_ => false)
  let (showStatus, setShowStatus) = React.useState(_ => false)
  let (payoutId, setPayoutId) = React.useState(_ => options.payoutId)
  let (merchantLogo, setMerchantLogo) = React.useState(_ => options.logo)
  let (merchantName, setMerchantName) = React.useState(_ => options.collectorName)
  let (merchantTheme, setMerchantTheme) = React.useState(_ => options.theme)

  // Form a list of available payment methods
  React.useEffect(() => {
    let availablePMT = {
      card: [],
      bankTransfer: [],
      wallet: [],
    }
    let _ = options.enabledPaymentMethods->Array.map(pm => {
      switch pm {
      | Card(cardType) =>
        if !(availablePMT.card->Array.includes(cardType)) {
          availablePMT.card->Array.push(cardType)
        }
      | BankTransfer(bankTransferType) =>
        if !(availablePMT.bankTransfer->Array.includes(bankTransferType)) {
          availablePMT.bankTransfer->Array.push(bankTransferType)
        }
      | Wallet(walletType) =>
        if !(availablePMT.wallet->Array.includes(walletType)) {
          availablePMT.wallet->Array.push(walletType)
        }
      }
    })

    let availablePM: array<paymentMethod> = []
    if !(availablePM->Array.includes(BankTransfer)) && availablePMT.bankTransfer->Array.length > 0 {
      availablePM->Array.push(BankTransfer)
    }
    if !(availablePM->Array.includes(Card)) && availablePMT.card->Array.length > 0 {
      availablePM->Array.push(Card)
    }
    if !(availablePM->Array.includes(Wallet)) && availablePMT.wallet->Array.length > 0 {
      availablePM->Array.push(Wallet)
    }

    setAvailablePaymentMethods(_ => availablePM)
    setAvailablePaymentMethodTypes(_ => availablePMT)

    None
  }, [options.enabledPaymentMethods])

  // Update amount
  React.useEffect(() => {
    setAmount(_ => options.amount)
    None
  }, [options.amount])

  // Update currency
  React.useEffect(() => {
    setCurrency(_ => options.currency)
    None
  }, [options.currency])

  // Update flow
  React.useEffect(() => {
    setFlow(_ => options.flow)
    None
  }, [options.flow])

  // Update linkId
  React.useEffect(() => {
    setLinkId(_ => options.linkId)
    None
  }, [options.linkId])

  // Update payoutId
  React.useEffect(() => {
    setPayoutId(_ => options.payoutId)
    None
  }, [options.payoutId])

  // Update merchant's name
  React.useEffect(() => {
    setMerchantName(_ => options.collectorName)
    None
  }, [options.collectorName])

  // Update merchant's logo
  React.useEffect(() => {
    setMerchantLogo(_ => options.logo)
    None
  }, [options.logo])

  // Update merchant's primary theme
  React.useEffect(() => {
    setMerchantTheme(_ => options.theme)
    None
  }, [options.theme])

  let handleSubmit = pmd => {
    setLoader(_ => true)
    let pmdBody = flow->formBody(pmd)

    switch flow {
    | PayoutLinkInitiate => {
        let endpoint = "http://localhost:8080"
        let uri = `${endpoint}/payouts/${payoutId}/confirm`
        // Create payment method
        open Promise
        PaymentHelpers.confirmPayout(
          ~clientSecret=keys.clientSecret->Option.getOr(""),
          ~publishableKey=keys.publishableKey,
          ~logger,
          ~switchToCustomPod=false,
          ~uri,
          ~body=pmdBody,
        )
        ->then(res => {
          Js.Console.log2("DEBUGG RES", res)
          setApiResponse(_ => Some(res))
          resolve()
        })
        ->catch(err => {
          Js.Console.log2("DEBUGG ERR", err)
          setApiError(_ => Some(err))
          resolve()
        })
        ->finally(() => {
          setShowStatus(_ => true)
          setLoader(_ => false)
        })
        ->ignore
      }
    | PayoutMethodCollect =>
      pmdBody->Array.push(("customer_id", options.customerId->Js.Json.string))

      // Create payment method
      open Promise
      PaymentHelpers.createPaymentMethod(
        ~clientSecret=keys.clientSecret->Option.getOr(""),
        ~publishableKey=keys.publishableKey,
        ~logger,
        ~switchToCustomPod=false,
        ~endpoint="http://localhost:8080",
        ~body=pmdBody,
      )
      ->then(res => {
        Js.Console.log2("DEBUGG RES", res)
        setApiResponse(_ => Some(res))
        resolve()
      })
      ->catch(err => {
        Js.Console.log2("DEBUGG ERR", err)
        setApiError(_ => Some(err))
        resolve()
      })
      ->finally(() => {
        setLoader(_ => false)
      })
      ->ignore
    }
  }

  if integrateError {
    <ErrorOccured />
  } else {
    <div className="flex h-screen">
      {switch flow {
      | PayoutLinkInitiate =>
        if showStatus {
          switch (apiResponse, apiError) {
          | (Some(res), _) =>
            <div>
              {React.string("STATUS: ")}
              {switch res->JSON.Decode.object {
              | Some(dict) =>
                switch dict->Dict.get("status") {
                | Some(status) =>
                  switch status->JSON.Decode.string {
                  | Some(status) => React.string(status)
                  | None => React.string("INTERNAL WEBSITE ERROR")
                  }
                | None => React.string("FAILED TO GET STATUS")
                }
              | None => React.string("INTERNAL WEBSITE ERROR")
              }}
            </div>
          | (_, Some(err)) =>
            <div>
              <div> {React.string("FAILED TO SUBMIT PAYOUTS")} </div>
            </div>
          | _ => <div> {React.string("INTERNAL WEBSITE ERROR")} </div>
          }
        } else {
          <React.Fragment>
            // Merchant's info
            <div
              className="flex flex-col w-4/10 px-[50px] py-[80px]"
              style={backgroundColor: merchantTheme}>
              <div
                className="flex flex-col self-end rounded-md shadow-lg min-w-80 w-full max-w-96"
                style={backgroundColor: "#FEFEFE"}>
                <div className="mx-[20px] mt-[20px] flex flex-row justify-between">
                  <div className="font-bold text-[35px]">
                    {React.string(`${currency} ${amount->Int.toString}`)}
                  </div>
                  <img className="h-12 w-auto" src={merchantLogo} alt="O" />
                </div>
                <div className="mx-[20px]">
                  <div className="self-center text-[20px] font-semibold">
                    {React.string("Payout from ")}
                    {React.string(merchantName)}
                  </div>
                  <div className="flex flex-row mt-[5px]">
                    <div className="font-semibold text-[12px]"> {React.string("Ref Id")} </div>
                    <div className="ml-[5px] text-[12px] text-gray-800">
                      {React.string(payoutId)}
                    </div>
                  </div>
                </div>
                <div className="mt-[10px] px-[20px] py-[5px] bg-gray-200 text-[13px] rounded-b-lg">
                  {React.string(`Link expires on: `)}
                </div>
              </div>
            </div>
            // Collect widget
            <div className="flex flex-row w-6/10 h-min">
              <div className="relative mx-[50px] my-[80px]">
                {loader
                  ? <div className="absolute h-full w-full bg-jp-gray-600 bg-opacity-80" />
                  : {React.null}}
                <CollectWidget
                  logger
                  primaryTheme={merchantTheme}
                  handleSubmit
                  availablePaymentMethods
                  availablePaymentMethodTypes
                />
              </div>
            </div>
          </React.Fragment>
        }

      | PayoutMethodCollect =>
        <React.Fragment>
          // Merchant's info
          <div className="flex flex-col w-3/10 p-[50px]" style={backgroundColor: merchantTheme}>
            <div className="flex flex-row">
              <img className="h-12 w-auto" src={merchantLogo} alt="O" />
              <div className="ml-[15px] text-white self-center text-[25px] font-bold">
                {React.string(merchantName)}
              </div>
            </div>
          </div>
          // Collect widget
          <CollectWidget
            logger
            primaryTheme={merchantTheme}
            handleSubmit
            availablePaymentMethods
            availablePaymentMethodTypes
          />
        </React.Fragment>
      }}
    </div>
  }
}

let default = make
