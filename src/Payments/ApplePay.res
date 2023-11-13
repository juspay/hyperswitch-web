type props = {sessionObj: option<Js.Json.t>, list: PaymentMethodsRecord.list}

let default = (props: props) => {
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let (showApplePay, setShowApplePay) = React.useState(() => false)
  let (showApplePayLoader, setShowApplePayLoader) = React.useState(() => false)
  let intent = PaymentHelpers.usePaymentIntent(None, Applepay)
  let sync = PaymentHelpers.usePaymentSync(None, Applepay)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let (applePayClicked, setApplePayClicked) = React.useState(_ => false)
  let isApplePaySDKFlow = props.sessionObj->Belt.Option.isSome

  let applePayPaymentMethodType = React.useMemo1(() => {
    switch PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~list=props.list,
      ~paymentMethod="wallet",
      ~paymentMethodType="apple_pay",
    ) {
    | Some(paymentMethodType) => paymentMethodType
    | None => PaymentMethodsRecord.defaultPaymentMethodType
    }
  }, [props.list])

  let paymentExperience = React.useMemo1(() => {
    applePayPaymentMethodType.payment_experience->Js.Array2.length == 0
      ? PaymentMethodsRecord.RedirectToURL
      : applePayPaymentMethodType.payment_experience[0].payment_experience_type
  }, [applePayPaymentMethodType])

  let isInvokeSDKFlow = React.useMemo1(() => {
    paymentExperience == PaymentMethodsRecord.InvokeSDK && isApplePaySDKFlow
  }, [props.sessionObj])

  let (connectors, _) = isInvokeSDKFlow
    ? props.list->PaymentUtils.getConnectors(Wallets(ApplePay(SDK)))
    : props.list->PaymentUtils.getConnectors(Wallets(ApplePay(Redirect)))

  let processPayment = bodyArr => {
    intent(
      ~bodyArr,
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey: publishableKey,
      },
      ~handleUserError=true,
      (),
    )
  }

  let syncPayment = () => {
    sync(
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
        publishableKey: publishableKey,
      },
      ~handleUserError=true,
      (),
    )
  }

  let buttonColor = switch options.wallets.style.theme {
  | Outline
  | Light => "white"
  | Dark => "black"
  }

  let loaderDivBackgroundColor = switch options.wallets.style.theme {
  | Outline
  | Light => "white"
  | Dark => "black"
  }

  let loaderBorderColor = switch options.wallets.style.theme {
  | Outline
  | Light => "#828282"
  | Dark => "white"
  }

  let loaderBorderTopColor = switch options.wallets.style.theme {
  | Outline
  | Light => "black"
  | Dark => "#828282"
  }

  let css = `@supports (-webkit-appearance: -apple-pay-button) {
    .apple-pay-loader-div {
      background-color: ${loaderDivBackgroundColor};
      height: 3rem;
      display: flex;
      justify-content: center;
      align-items: center;
      border-radius: 2px
    }
    .apple-pay-loader {
      border: 4px solid ${loaderBorderColor};
      border-radius: 50%;
      border-top: 4px solid ${loaderBorderTopColor};
      width: 2.1rem;
      height: 2.1rem;
      -webkit-animation: spin 2s linear infinite; /* Safari */
      animation: spin 2s linear infinite;
    }

    /* Safari */
    @-webkit-keyframes spin {
      0% { -webkit-transform: rotate(0deg); }
      100% { -webkit-transform: rotate(360deg); }
    }

    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .apple-pay-button-with-text {
        display: inline-block;
        -webkit-appearance: -apple-pay-button;
        -apple-pay-button-type: plain;
    }
    .apple-pay-button-with-text > * {
        display: none;
    }
    .apple-pay-button-black-with-text {
        -apple-pay-button-style: ${buttonColor};
        width: 100%;
        height: 3rem;
        display: flex;
        cursor: pointer;
        border-radius: 2px;
    }
    .apple-pay-button-white-with-text {
        -apple-pay-button-style: white;
        display: flex;
        cursor: pointer;
    }
    .apple-pay-button-white-with-line-with-text {
        -apple-pay-button-style: white-outline;
    }
  }

  @supports not (-webkit-appearance: -apple-pay-button) {
      .apple-pay-button-with-text {
          --apple-pay-scale: 2; /* (height / 32) */
          display: inline-flex;
          justify-content: center;
          font-size: 12px;
          border-radius: 5px;
          padding: 0px;
          box-sizing: border-box;
          min-width: 200px;
          min-height: 32px;
          max-height: 64px;
      }
      .apple-pay-button-black-with-text {
          background-color: black;
          color: white;
      }
      .apple-pay-button-white-with-text {
          background-color: white;
          color: black;
      }
      .apple-pay-button-white-with-line-with-text {
          background-color: white;
          color: black;
          border: .5px solid black;
      }
      .apple-pay-button-with-text.apple-pay-button-black-with-text > .logo {
          background-image: -webkit-named-image(apple-pay-logo-white);
          background-color: black;
      }
      .apple-pay-button-with-text.apple-pay-button-white-with-text > .logo {
          background-image: -webkit-named-image(apple-pay-logo-black);
          background-color: white;
      }
      .apple-pay-button-with-text.apple-pay-button-white-with-line-with-text > .logo {
          background-image: -webkit-named-image(apple-pay-logo-black);
          background-color: black;
      }
      .apple-pay-button-with-text > .text {
          font-family: -apple-system;
          font-size: calc(1em * var(--apple-pay-scale));
          font-weight: 300;
          align-self: center;
          margin-right: calc(2px * var(--apple-pay-scale));
      }
      .apple-pay-button-with-text > .logo {
          width: calc(35px * var(--scale));
          height: 100%;
          background-size: 100% 60%;
          background-repeat: no-repeat;
          background-position: 0 50%;
          margin-left: calc(2px * var(--apple-pay-scale));
          border: none;
      }
  }`

  // let obj =
  //   {
  //     "wallet_name": "applepay",
  //     "epoch_timestamp": 1675749987943,
  //     "expires_at": 1675753587943,
  //     "merchant_session_identifier": "SSH0EF3341DA3D743D0808AD28AE5C5E5C2_4CF2C6BCC345A3D997660901FCCEC7A10708B3324E3780EDF6120543128967F9",
  //     "nonce": "6c64197a",
  //     "merchant_identifier": "ADBC9B6AC52DC9870E67616DD209B42D1152EFD051AA1C1383F3DC6E24C3B1DE",
  //     "domain_name": "5v4cy064yk.execute-api.ap-south-1.amazonaws.com",
  //     "display_name": "applepay",
  //     "signature": "308006092a864886f70d010702a0803080020101310d300b0609608648016503040201308006092a864886f70d0107010000a080308203e330820388a00302010202084c304149519d5436300a06082a8648ce3d040302307a312e302c06035504030c254170706c65204170706c69636174696f6e20496e746567726174696f6e204341202d20473331263024060355040b0c1d4170706c652043657274696669636174696f6e20417574686f7269747931133011060355040a0c0a4170706c6520496e632e310b3009060355040613025553301e170d3139303531383031333235375a170d3234303531363031333235375a305f3125302306035504030c1c6563632d736d702d62726f6b65722d7369676e5f5543342d50524f4431143012060355040b0c0b694f532053797374656d7331133011060355040a0c0a4170706c6520496e632e310b30090603550406130255533059301306072a8648ce3d020106082a8648ce3d03010703420004c21577edebd6c7b2218f68dd7090a1218dc7b0bd6f2c283d846095d94af4a5411b83420ed811f3407e83331f1c54c3f7eb3220d6bad5d4eff49289893e7c0f13a38202113082020d300c0603551d130101ff04023000301f0603551d2304183016801423f249c44f93e4ef27e6c4f6286c3fa2bbfd2e4b304506082b0601050507010104393037303506082b060105050730018629687474703a2f2f6f6373702e6170706c652e636f6d2f6f63737030342d6170706c65616963613330323082011d0603551d2004820114308201103082010c06092a864886f7636405013081fe3081c306082b060105050702023081b60c81b352656c69616e6365206f6e207468697320636572746966696361746520627920616e7920706172747920617373756d657320616363657074616e6365206f6620746865207468656e206170706c696361626c65207374616e64617264207465726d7320616e6420636f6e646974696f6e73206f66207573652c20636572746966696361746520706f6c69637920616e642063657274696669636174696f6e2070726163746963652073746174656d656e74732e303606082b06010505070201162a687474703a2f2f7777772e6170706c652e636f6d2f6365727469666963617465617574686f726974792f30340603551d1f042d302b3029a027a0258623687474703a2f2f63726c2e6170706c652e636f6d2f6170706c6561696361332e63726c301d0603551d0e041604149457db6fd57481868989762f7e578507e79b5824300e0603551d0f0101ff040403020780300f06092a864886f76364061d04020500300a06082a8648ce3d0403020349003046022100be09571fe71e1e735b55e5afacb4c72feb445f30185222c7251002b61ebd6f55022100d18b350a5dd6dd6eb1746035b11eb2ce87cfa3e6af6cbd8380890dc82cddaa63308202ee30820275a0030201020208496d2fbf3a98da97300a06082a8648ce3d0403023067311b301906035504030c124170706c6520526f6f74204341202d20473331263024060355040b0c1d4170706c652043657274696669636174696f6e20417574686f7269747931133011060355040a0c0a4170706c6520496e632e310b3009060355040613025553301e170d3134303530363233343633305a170d3239303530363233343633305a307a312e302c06035504030c254170706c65204170706c69636174696f6e20496e746567726174696f6e204341202d20473331263024060355040b0c1d4170706c652043657274696669636174696f6e20417574686f7269747931133011060355040a0c0a4170706c6520496e632e310b30090603550406130255533059301306072a8648ce3d020106082a8648ce3d03010703420004f017118419d76485d51a5e25810776e880a2efde7bae4de08dfc4b93e13356d5665b35ae22d097760d224e7bba08fd7617ce88cb76bb6670bec8e82984ff5445a381f73081f4304606082b06010505070101043a3038303606082b06010505073001862a687474703a2f2f6f6373702e6170706c652e636f6d2f6f63737030342d6170706c65726f6f7463616733301d0603551d0e0416041423f249c44f93e4ef27e6c4f6286c3fa2bbfd2e4b300f0603551d130101ff040530030101ff301f0603551d23041830168014bbb0dea15833889aa48a99debebdebafdacb24ab30370603551d1f0430302e302ca02aa0288626687474703a2f2f63726c2e6170706c652e636f6d2f6170706c65726f6f74636167332e63726c300e0603551d0f0101ff0404030201063010060a2a864886f7636406020e04020500300a06082a8648ce3d040302036700306402303acf7283511699b186fb35c356ca62bff417edd90f754da28ebef19c815e42b789f898f79b599f98d5410d8f9de9c2fe0230322dd54421b0a305776c5df3383b9067fd177c2c216d964fc6726982126f54f87a7d1b99cb9b0989216106990f09921d00003182018630820182020101308186307a312e302c06035504030c254170706c65204170706c69636174696f6e20496e746567726174696f6e204341202d20473331263024060355040b0c1d4170706c652043657274696669636174696f6e20417574686f7269747931133011060355040a0c0a4170706c6520496e632e310b300906035504061302555302084c304149519d5436300b0609608648016503040201a08193301806092a864886f70d010903310b06092a864886f70d010701301c06092a864886f70d010905310f170d3233303230373036303632375a302806092a864886f70d010934311b3019300b0609608648016503040201a10a06082a8648ce3d040302302f06092a864886f70d01090431220420c78dc6da8a2ce5fd1a81f5abc3b518c847d9fb78862df1a210d2ba16a03b8345300a06082a8648ce3d04030204453043022065b3606ce68ae55b09c03ba88193a4dcda52a7bf7d15cfcad97fccd3bae7babe021f653ee9cbe851ebe40f6f69619bd8ca55f52993aff12c9e20010c8bd62a5f35000000000000",
  //     "operational_analytics_identifier": "applepay:ADBC9B6AC52DC9870E67616DD209B42D1152EFD051AA1C1383F3DC6E24C3B1DE",
  //     "retries": 0,
  //     "psp_id": "ADBC9B6AC52DC9870E67616DD209B42D1152EFD051AA1C1383F3DC6E24C3B1DE",
  //   }
  //   ->toJson
  //   ->Utils.transformKeysSnakeToCamel

  let onApplePayButtonClicked = () => {
    loggerState.setLogInfo(
      ~value="Apple Pay Button Clicked",
      ~eventName=APPLE_PAY_FLOW,
      ~paymentMethod="APPLE_PAY",
      (),
    )
    setApplePayClicked(_ => true)

    if isInvokeSDKFlow {
      let isDelayedSessionToken =
        props.sessionObj
        ->Belt.Option.getWithDefault(Js.Json.null)
        ->Js.Json.decodeObject
        ->Belt.Option.getWithDefault(Js.Dict.empty())
        ->Js.Dict.get("delayed_session_token")
        ->Belt.Option.getWithDefault(Js.Json.null)
        ->Js.Json.decodeBoolean
        ->Belt.Option.getWithDefault(false)

      if isDelayedSessionToken {
        setShowApplePayLoader(_ => true)
        let bodyDict = PaymentBody.applePayThirdPartySdkBody(~connectors)
        processPayment(bodyDict)
      } else {
        let message = [("applePayButtonClicked", true->Js.Json.boolean)]
        Utils.handlePostMessage(message)
      }
    } else {
      let bodyDict = PaymentBody.applePayRedirectBody(~connectors)
      processPayment(bodyDict)
    }
    loggerState.setLogInfo(
      ~value="",
      ~eventName=PAYMENT_DATA_FILLED,
      ~paymentMethod="APPLE_PAY",
      (),
    )
  }

  React.useEffect0(() => {
    setIsShowOrPayUsing(.prev => prev || showApplePay)
    None
  })

  React.useEffect1(() => {
    Utils.handlePostMessage([("applePayMounted", true->Js.Json.boolean)])
    let handleApplePayMessages = (ev: Window.event) => {
      let json = try {
        ev.data->Js.Json.parseExn
      } catch {
      | _ => Js.Dict.empty()->Js.Json.object_
      }

      try {
        let dict = json->Utils.getDictFromJson
        if dict->Js.Dict.get("applePayCanMakePayments")->Belt.Option.isSome {
          if isInvokeSDKFlow || paymentExperience == PaymentMethodsRecord.RedirectToURL {
            setShowApplePay(_ => true)
          }
        } else if dict->Js.Dict.get("applePayProcessPayment")->Belt.Option.isSome {
          let token =
            dict
            ->Js.Dict.get("applePayProcessPayment")
            ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
          let bodyDict = PaymentBody.applePayBody(~token, ~connectors)
          processPayment(bodyDict)
        } else if dict->Js.Dict.get("showApplePayButton")->Belt.Option.isSome {
          setApplePayClicked(_ => false)
        } else if dict->Js.Dict.get("applePaySyncPayment")->Belt.Option.isSome {
          syncPayment()
        }
      } catch {
      | _ => Utils.logInfo(Js.log("Error in parsing Apple Pay Data"))
      }
    }
    Window.addEventListener("message", handleApplePayMessages)
    Some(
      () => {
        Utils.handlePostMessage([("applePaySessionAbort", true->Js.Json.boolean)])
        Window.removeEventListener("message", handleApplePayMessages)
      },
    )
  }, [isInvokeSDKFlow])

  <div>
    <style> {React.string(css)} </style>
    {if showApplePay {
      if showApplePayLoader {
        <div className="apple-pay-loader-div"> <div className="apple-pay-loader" /> </div>
      } else {
        <button
          disabled=applePayClicked
          className="apple-pay-button-with-text apple-pay-button-black-with-text"
          onClick={_ => onApplePayButtonClicked()}>
          <span className="text"> {React.string("Pay with")} </span> <span className="logo" />
        </button>
      }
    } else {
      React.null
    }}
  </div>
}
