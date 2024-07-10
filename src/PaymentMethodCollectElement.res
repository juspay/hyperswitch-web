open PaymentMethodCollectTypes
open PaymentMethodCollectUtils
open RecoilAtoms

@react.component
let make = (~integrateError, ~logger) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
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
  let (formLayout, setFormLayout) = React.useState(_ => options.formLayout)
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
    let availablePM: array<paymentMethod> = []
    let availablePMT: array<paymentMethodType> = []
    let _ = options.enabledPaymentMethods->Array.map(pm => {
      switch pm {
      | Card(_) =>
        if !(availablePM->Array.includes(Card)) {
          availablePMT->Array.push(Card(Debit))
          availablePM->Array.push(Card)
        }
      | BankTransfer(_) =>
        if !(availablePM->Array.includes(BankTransfer)) {
          availablePM->Array.push(BankTransfer)
        }
        if !(availablePMT->Array.includes(pm)) {
          availablePMT->Array.push(pm)
        }
      | Wallet(_) =>
        if !(availablePM->Array.includes(Wallet)) {
          availablePM->Array.push(Wallet)
        }
        if !(availablePMT->Array.includes(pm)) {
          availablePMT->Array.push(pm)
        }
        if !(availablePMT->Array.includes(pm)) {
          availablePMT->Array.push(pm)
        }
      }
    })

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

  // Update formLayout
  React.useEffect(() => {
    setFormLayout(_ => options.formLayout)
    None
  }, [options.formLayout])

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
    <div className="flex flex-row h-min lg:w-6/10">
      <div className="relative w-full lg:w-auto lg:mx-12 lg:my-20">
        {loader
          ? <div className="absolute h-full w-full bg-jp-gray-600 bg-opacity-80" />
          : {React.null}}
        <CollectWidget
          primaryTheme={merchantTheme}
          handleSubmit
          availablePaymentMethods
          availablePaymentMethodTypes
          formLayout
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

    <div
      style={
        color: themeObj.colorText,
        fontFamily: themeObj.fontFamily,
        fontSize: themeObj.fontSizeBase,
      }
      className="flex flex-col items-center justify-center self-center leading-none
        xs:mt-auto xs:mb-auto
        lg:ml-auto lg:mr-auto">
      <div
        className="flex flex-col items-center rounded-lg max-w-[500px]
          xs:shadow-lg">
        <div
          className="flex flex-row justify-between items-center w-full px-10 py-5 border-b border-jp-gray-300">
          <div className="text-2xl font-semibold"> {React.string(merchantName)} </div>
          <img className="h-7 w-auto" src={merchantLogo} alt="o" />
        </div>
        <img className="h-40 w-40 mt-7" src={imageSource} alt="o" />
        <div className="text-5 font-semibold mt-2.5"> {React.string(readableStatus)} </div>
        <div className="text-jp-gray-800 m text-center mx-10 mb-10">
          {React.string(statusInfo.message)}
        </div>
        <div className="flex border-t border-bg-jp-gray-300 py-5 w-full justify-center">
          <div
            className="flex flex-col max-w-[500px] bg-white w-full mx-2.5
            xs:mx-10">
            {statusInfoFields
            ->Array.mapWithIndex((info, i) => {
              <div key={i->Int.toString} className={`flex flex-row items-center mb-0.5`}>
                <div className="text-sm text-jp-gray-900 text-right min-w-20">
                  {React.string(info.key)}
                </div>
                <div
                  className="text-[11px] ml-2.5 pl-2.5 border-l border-jp-gray-300
                    xs:text-xs">
                  {React.string(info.value)}
                </div>
              </div>
            })
            ->React.array}
          </div>
        </div>
      </div>
      {switch secondsUntilRedirect {
      | Some(seconds) =>
        <div className="mt-10">
          {React.string("Redirecting in " ++ seconds->Int.toString ++ " seconds ...")}
        </div>
      | None => React.null
      }}
    </div>
  }

  if integrateError {
    <ErrorOccured />
  } else {
    <div
      className="flex flex-col h-screen min-w-[320px]
        lg:flex-row">
      {switch flow {
      | PayoutLinkInitiate =>
        if showStatus {
          renderPayoutStatus()
        } else {
          <React.Fragment>
            // Merchant's info
            <div
              className="flex flex-col w-full h-max items-center p-6
                lg:w-4/10 lg:px-12 lg:py-20 lg:h-screen lg:items-end"
              style={backgroundColor: merchantTheme}>
              <div
                className="flex flex-col text-white w-full min-w-[300px] max-w-[520px]
                  lg:rounded-md lg:shadow-lg lg:min-w-80 lg:max-w-96 lg:bg-white lg:text-black">
                <div
                  className="flex flex-col-reverse
                    lg:mx-5 lg:mt-5 lg:flex-row lg:justify-between">
                  <div className="font-bold text-5xl mt-5 lg:mt-0 lg:text-3xl">
                    {React.string(`${currency} ${amount}`)}
                  </div>
                  <div className="flex items-center justify-center h-16 w-16 bg-white rounded-sm">
                    <img className="max-h-12 max-w-16 h-auto w-auto" src={merchantLogo} alt="O" />
                  </div>
                </div>
                <div className="lg:mx-5">
                  <div className="self-center text-xl font-semibold">
                    {React.string("Payout from ")}
                    {React.string(merchantName)}
                  </div>
                  <div className="flex flex-row lg:mt-1">
                    <div className="font-semibold text-xs"> {React.string("Ref Id")} </div>
                    <div className="ml-1 text-xs"> {React.string(payoutId)} </div>
                  </div>
                </div>
                <div
                  className="mt-4 px-4 py-1.5 bg-gray-200 text-[13px] rounded-full w-max text-black
                    lg:w-full lg:rounded-none lg:rounded-b-lg">
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
          <div className="flex flex-col w-3/10 p-12" style={backgroundColor: merchantTheme}>
            <div className="flex flex-row">
              <img className="h-12 w-auto" src={merchantLogo} alt="O" />
              <div className="ml-4 text-white self-center text-2xl font-bold">
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
