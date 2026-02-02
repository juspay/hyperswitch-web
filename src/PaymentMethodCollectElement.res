open PaymentMethodCollectTypes
open PaymentMethodCollectUtils
open RecoilAtoms

@react.component
let make = (~integrateError, ~logger) => {
  open Promise
  let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
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
  let (loader, setLoader) = React.useState(_ => false)
  let (secondsUntilRedirect, setSecondsUntilRedirect) = React.useState(_ => None)
  let (showStatus, setShowStatus) = React.useState(_ => false)
  let (statusInfo, setStatusInfo) = React.useState(_ => defaultStatusInfo)

  // Form a list of available payment methods
  React.useEffect(() => {
    let availablePM: array<paymentMethod> = []
    let availablePMT: array<paymentMethodType> = []
    options.enabledPaymentMethods->Array.forEach(pm => {
      switch pm {
      | Card(_) =>
        if !(availablePM->Array.includes(Card)) {
          availablePM->Array.push(Card)
          availablePMT->Array.push(Card(Debit))
        }
      | BankRedirect(_) =>
        if !(availablePM->Array.includes(BankRedirect)) {
          availablePM->Array.push(BankRedirect)
        }
        if !(availablePMT->Array.includes(pm)) {
          availablePMT->Array.push(pm)
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
      }
    })

    setAvailablePaymentMethods(_ => availablePM)
    setAvailablePaymentMethodTypes(_ => availablePMT)

    None
  }, [options.enabledPaymentMethods])

  // Start a timer for redirecting to return_url
  React.useEffect(() => {
    switch (options.returnUrl, showStatus) {
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
          let url = URLModule.makeUrl(returnUrl)
          url.searchParams.set("payout_id", options.payoutId)
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
    let flow = options.flow
    let pmdBody = flow->formBody(pmd)

    let createPaymentMethodPromiseWrapped = () => {
      PaymentHelpers.createPaymentMethod(
        ~clientSecret=keys.clientSecret->Option.getOr(""),
        ~publishableKey=keys.publishableKey,
        ~logger,
        ~customPodUri="",
        ~endpoint=ApiEndpoint.getApiEndPoint(),
        ~body=pmdBody,
      )
      ->then(res => {
        Console.warn2("DEBUGG RES", res)
        resolve()
      })
      ->catch(err => {
        Console.error2("DEBUGG ERR", err)
        resolve()
      })
      ->finally(() => {
        setLoader(_ => false)
      })
    }

    let confirmPayoutPromiseWrapper = () => {
      let endpoint = ApiEndpoint.getApiEndPoint()
      PaymentHelpers.confirmPayout(
        ~clientSecret=keys.clientSecret->Option.getOr(""),
        ~publishableKey=keys.publishableKey,
        ~logger,
        ~customPodUri="",
        ~endpoint,
        ~body=pmdBody,
        ~payoutId=options.payoutId,
      )
      ->then(res => {
        let data = res->decodePayoutConfirmResponse
        switch data {
        | Some(SuccessResponse(res)) => {
            let updatedStatusInfo = {
              payoutId: res.payoutId,
              status: res.status,
              message: res.status->getPayoutStatusMessage(localeString),
              code: res.errorCode,
              errorMessage: res.errorMessage,
              reason: None,
            }
            setStatusInfo(_ => updatedStatusInfo)
          }
        | Some(ErrorResponse(err)) => {
            let updatedStatusInfo = {
              payoutId: options.payoutId,
              status: Failed,
              message: localeString.payoutStatusFailedMessage,
              code: Some(err.code),
              errorMessage: Some(err.message),
              reason: err.reason,
            }
            setStatusInfo(_ => updatedStatusInfo)
          }
        | None => {
            let updatedStatusInfo = {
              payoutId: options.payoutId,
              status: Failed,
              message: localeString.payoutStatusFailedMessage,
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
          payoutId: options.payoutId,
          status: Failed,
          message: localeString.payoutStatusFailedMessage,
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
    }

    switch flow {
    | PayoutLinkInitiate =>
      confirmPayoutPromiseWrapper()->then(_ => resolve())->catch(_ => resolve())->ignore
    | PayoutMethodCollect =>
      pmdBody->Array.push(("customer_id", options.customerId->JSON.Encode.string))
      createPaymentMethodPromiseWrapped()->then(_ => resolve())->catch(_ => resolve())->ignore
    }
  }

  let renderCollectWidget = () =>
    <div className="flex flex-row overflow-scroll lg:w-6/10">
      <div className="relative w-full h-min lg:w-auto lg:mx-12 lg:mt-20 lg-mb-10">
        {loader
          ? <div className="absolute h-full w-full bg-jp-gray-600 bg-opacity-80" />
          : {React.null}}
        <CollectWidget
          primaryTheme={options.theme}
          handleSubmit
          availablePaymentMethods
          availablePaymentMethodTypes
          formLayout={options.formLayout}
        />
      </div>
    </div>

  let renderPayoutStatus = () => {
    let status = statusInfo.status
    let imageSource = getPayoutImageSource(status)
    let readableStatus = status->getPayoutReadableStatus(localeString)
    let statusInfoFields: array<statusInfoField> = [
      {key: localeString.infoCardRefId, value: options.payoutId},
    ]

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
          <div className="text-2xl font-semibold"> {React.string(options.collectorName)} </div>
          <img className="h-12 w-auto max-w-21" src={options.logo} alt="o" />
        </div>
        <img className="h-40 w-40 mt-7" src={imageSource} alt="o" />
        <div className="text-xl font-semibold mt-2.5"> {React.string(readableStatus)} </div>
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
        <div className="mt-10"> {React.string(seconds->localeString.linkRedirectionText)} </div>
      | None => React.null
      }}
    </div>
  }

  if integrateError {
    <ErrorOccurred />
  } else {
    <div
      className="flex flex-col h-screen min-w-[320px] overflow-hidden
        lg:flex-row">
      {
        let merchantLogo = options.logo
        let merchantName = options.collectorName
        let merchantTheme = options.theme
        switch options.flow {
        | PayoutLinkInitiate =>
          if showStatus {
            renderPayoutStatus()
          } else {
            <>
              // Merchant's info
              <div
                className="flex flex-col w-full h-max items-center p-6
                lg:w-4/10 lg:px-12 lg:py-20 lg:h-screen lg:items-end"
                style={backgroundColor: merchantTheme}>
                <div
                  className="flex flex-col text-white w-full min-w-[300px] max-w-[520px]
                  lg:rounded-md lg:shadow-lg lg:min-w-80 lg:max-w-96 lg:bg-white lg:text-black">
                  <div
                    className="flex flex-col-reverse justify-end
                    lg:mx-5 lg:mt-5 lg:flex-row lg:justify-between">
                    <div
                      className="font-bold text-5xl mt-5 lg:mt-0 lg:text-3xl flex justify-start items-center">
                      <p> {React.string(`${options.currency} ${options.amount}`)} </p>
                    </div>
                    <div className="flex self-start h-12 w-auto bg-white rounded-sm">
                      <img className="max-h-12 w-auto max-w-21 h-auto" src={merchantLogo} alt="O" />
                    </div>
                  </div>
                  <div className="lg:mx-5">
                    <div className="self-center text-xl font-semibold">
                      {React.string(merchantName->localeString.payoutFromText)}
                    </div>
                    <div className="flex flex-row lg:mt-1">
                      <div className="font-semibold text-xs">
                        {React.string(localeString.infoCardRefId)}
                      </div>
                      <div className="ml-1 text-xs"> {React.string(options.payoutId)} </div>
                    </div>
                  </div>
                  <div
                    className="mt-4 px-4 py-1.5 bg-gray-200 text-[13px] rounded-full w-max text-black
                    lg:w-full lg:rounded-none lg:rounded-b-lg">
                    {React.string(options.sessionExpiry->localeString.linkExpiryInfo)}
                  </div>
                </div>
              </div>
              // Collect widget
              {renderCollectWidget()}
            </>
          }

        | PayoutMethodCollect =>
          <>
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
          </>
        }
      }
    </div>
  }
}

let default = make
