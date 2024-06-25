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
  let (amount, setAmount) = React.useState(_ => options.amount)
  let (currency, setCurrency) = React.useState(_ => options.currency)
  let (flow, setFlow) = React.useState(_ => options.flow)
  let (loader, setLoader) = React.useState(_ => false)
  let (returnUrl, setReturnUrl) = React.useState(_ => options.returnUrl)
  let (secondsUntilRedirect, setSecondsUntilRedirect) = React.useState(_ => None)
  let (sessionExpiry, setSessionExpiry) = React.useState(_ => options.sessionExpiry)
  let (showStatus, setShowStatus) = React.useState(_ => false)
  let (statusInfo, setStatusInfo) = React.useState(_ => defaultStatusInfo)
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

  // Update returnUrl
  React.useEffect(() => {
    setReturnUrl(_ => options.returnUrl)
    None
  }, [options.returnUrl])

  // Update sessionExpiry
  React.useEffect(() => {
    setSessionExpiry(_ => options.sessionExpiry)
    None
  }, [options.sessionExpiry])

  // Start a timer for redirecting to return_url
  React.useEffect(() => {
    switch (returnUrl, showStatus) {
    | (Some(returnUrl), true) => {
        setSecondsUntilRedirect(_ => Some(5))
        // Start a interval to update redirect text every second
        let interval = setInterval(() =>
          setSecondsUntilRedirect(
            prev =>
              switch prev {
              | Some(val) => val > 0 ? Some(val - 1) : Some(val)
              | None => Some(5)
              },
          )
        , 1000)
        // Clear after 5s and redirect
        setTimeout(() => {
          clearInterval(interval)
          // Append query params and redirect
          let url = PaymentHelpers.urlSearch(returnUrl)
          url.searchParams.set("payout_id", payoutId)
          url.searchParams.set("status", statusInfo.status->getPayoutStatusString)
          Utils.openUrl(url.href)
        }, 5010)->ignore
      }
    | _ => ()
    }
    None
  }, [showStatus])

  let handleSubmit = pmd => {
    setLoader(_ => true)
    let pmdBody = flow->formBody(pmd)

    switch flow {
    | PayoutLinkInitiate => {
        let endpoint = ApiEndpoint.getApiEndPoint()
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
          let data = res->decodePayoutConfirmResponse
          switch data {
          | Some(SuccessResponse(res)) => {
              let updatedStatusInfo = {
                payoutId: res.payoutId,
                status: res.status,
                message: getPayoutStatusMessage(res.status),
                code: res.errorCode,
                errorMessage: res.errorMessage,
                reason: None,
              }
              setStatusInfo(_ => updatedStatusInfo)
            }
          | Some(ErrorResponse(err)) => {
              let updatedStatusInfo = {
                payoutId,
                status: Failed,
                message: "Failed to process your payout. Please check with your provider for more details.",
                code: Some(err.code),
                errorMessage: Some(err.message),
                reason: err.reason,
              }
              setStatusInfo(_ => updatedStatusInfo)
            }
          | None => {
              let updatedStatusInfo = {
                payoutId,
                status: Failed,
                message: "Failed to process your payout. Please check with your provider for more details.",
                code: None,
                errorMessage: None,
                reason: None,
              }
              setStatusInfo(_ => updatedStatusInfo)
            }
          }
          resolve()
        })
        ->catch(err => {
          Console.error2("CRITICAL - Payouts confirm failed with unknown error", err)
          let updatedStatusInfo = {
            payoutId,
            status: Failed,
            message: "Failed to process your payout. Please check with your provider for more details.",
            code: None,
            errorMessage: None,
            reason: None,
          }
          setStatusInfo(_ => updatedStatusInfo)
          resolve()
        })
        ->finally(() => {
          setShowStatus(_ => true)
          setLoader(_ => false)
        })
        ->ignore
      }
    | PayoutMethodCollect =>
      pmdBody->Array.push(("customer_id", options.customerId->JSON.Encode.string))

      // Create payment method
      open Promise
      PaymentHelpers.createPaymentMethod(
        ~clientSecret=keys.clientSecret->Option.getOr(""),
        ~publishableKey=keys.publishableKey,
        ~logger,
        ~switchToCustomPod=false,
        ~endpoint=ApiEndpoint.getApiEndPoint(),
        ~body=pmdBody,
      )
      ->then(res => {
        Console.log2("DEBUGG RES", res)
        resolve()
      })
      ->catch(err => {
        Console.log2("DEBUGG ERR", err)
        resolve()
      })
      ->finally(() => {
        setLoader(_ => false)
      })
      ->ignore
    }
  }

  let renderCollectWidget = () =>
    <div className="flex flex-row w-6/10 h-min">
      <div className="relative mx-[50px] my-[80px]">
        {loader
          ? <div className="absolute h-full w-full bg-jp-gray-600 bg-opacity-80" />
          : {React.null}}
        <CollectWidget
          primaryTheme={merchantTheme}
          handleSubmit
          availablePaymentMethods
          availablePaymentMethodTypes
        />
      </div>
    </div>

  let renderPayoutStatus = () => {
    let status = statusInfo.status
    let imageSource = getPayoutImageSource(status)
    let readableStatus = getPayoutReadableStatus(status)
    let statusInfoFields: array<statusInfoField> = [{key: "Ref Id", value: payoutId}]

    statusInfo.code
    ->Option.flatMap(code => {
      statusInfoFields->Array.push({key: "Error Code", value: code})
      None
    })
    ->ignore
    statusInfo.errorMessage
    ->Option.flatMap(errorMessage => {
      statusInfoFields->Array.push({key: "Error Message", value: errorMessage})
      None
    })
    ->ignore
    statusInfo.reason
    ->Option.flatMap(reason => {
      statusInfoFields->Array.push({key: "Reason", value: reason})
      None
    })
    ->ignore

    <div className="flex flex-col items-center justify-center">
      <div
        className="flex flex-col self-center items-center justify-center rounded-lg shadow-lg max-w-[500px]">
        <div
          className="flex flex-row justify-between items-center w-full px-[40px] py-[20px] border-b border-jp-gray-300">
          <div className="text-[25px] font-semibold"> {React.string(merchantName)} </div>
          <img className="h-[30px] w-auto" src={merchantLogo} alt="o" />
        </div>
        <img className="h-[160px] w-[160px] mt-[30px]" src={imageSource} alt="o" />
        <div className="text-[20px] font-semibold mt-[10px]"> {React.string(readableStatus)} </div>
        <div className="text-jp-gray-800 m text-center mx-[40px] mb-[40px]">
          {React.string(statusInfo.message)}
        </div>
        <div className="flex border-t border-bg-jp-gray-300 py-[20px] w-full justify-center">
          <div className="flex flex-col max-w-[500px] bg-white w-full mx-[40px]">
            {statusInfoFields
            ->Array.mapWithIndex((info, i) => {
              <div key={i->Int.toString} className={`flex flex-row items-center`}>
                <div className="text-[15px] text-jp-gray-900 min-w-[10ch] text-right">
                  {React.string(info.key)}
                </div>
                <div className="text-[13px] ml-[10px] pl-[10px] border-l border-jp-gray-300">
                  {React.string(info.value)}
                </div>
              </div>
            })
            ->React.array}
          </div>
        </div>
      </div>
      <div className="mt-[40px]">
        {switch secondsUntilRedirect {
        | Some(seconds) =>
          React.string("Redirecting in " ++ seconds->Int.toString ++ " seconds ...")
        | None => React.null
        }}
      </div>
    </div>
  }

  if integrateError {
    <ErrorOccured />
  } else {
    <div className="flex h-screen justify-center">
      {switch flow {
      | PayoutLinkInitiate =>
        if showStatus {
          renderPayoutStatus()
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
                    {React.string(`${currency} ${amount}`)}
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
                  {React.string(`Link expires on: ${sessionExpiry}`)}
                </div>
              </div>
            </div>
            // Collect widget
            {renderCollectWidget()}
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
          {renderCollectWidget()}
        </React.Fragment>
      }}
    </div>
  }
}

let default = make
