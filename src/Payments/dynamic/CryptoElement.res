open SuperpositionTypes

module CryptoField = {
  @react.component
  let make = (~currencyConfig, ~networkConfig) => {
    let {config} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let isSpacedInnerLayout = config.appearance.innerLayout === Spaced
    let (selectedCurrency, setSelectedCurrency) = React.useState(_ => None)

    let getNetworkArray = currency => {
      switch currency->Option.getOr("") {
      | "LTC" => ["litecoin", "bnb_smart_chain"]
      | "ETH" => ["ethereum", "bnb_smart_chain"]
      | "XRP" => ["ripple", "bnb_smart_chain"]
      | "XLM" => ["stellar", "bnb_smart_chain"]
      | "BCH" => ["bitcoin_cash", "bnb_smart_chain"]
      | "ADA" => ["cardano", "bnb_smart_chain"]
      | "SOL" => ["solana", "bnb_smart_chain"]
      | "SHIB" => ["ethereum", "bnb_smart_chain"]
      | "TRX" => ["tron", "bnb_smart_chain"]
      | "DOGE" => ["dogecoin", "bnb_smart_chain"]
      | "BNB" => ["bnb_smart_chain"]
      | "USDT" => ["ethereum", "tron", "bnb_smart_chain"]
      | "USDC" => ["ethereum", "tron", "bnb_smart_chain"]
      | "DAI" => ["ethereum", "bnb_smart_chain"]
      | "BTC" | _ => ["bitcoin", "bnb_smart_chain"]
      }
    }

    let currencyOptions = DropdownField.updateArrayOfStringToOptionsTypeArray(
      currencyConfig.options->Array.length > 0 ? currencyConfig.options : ["BTC", "ETH", "USDT"],
    )

    // Get initial values
    let initialCurrency = switch currencyOptions->Array.get(0) {
    | Some(firstOption) => firstOption.value
    | None => ""
    }

    let initialNetworks = getNetworkArray(Some(initialCurrency))
    let initialNetwork = switch initialNetworks->Array.get(0) {
    | Some(firstNetwork) => firstNetwork
    | None => ""
    }

    let {input: currencyInput, meta: currencyMeta} = ReactFinalForm.useField(
      currencyConfig.name,
      ~config={
        initialValue: Some(initialCurrency),
      },
    )

    let {input: networkInput, meta: networkMeta} = ReactFinalForm.useField(
      networkConfig.name,
      ~config={
        initialValue: Some(initialNetwork),
      },
    )

    // Set initial selectedCurrency state
    React.useEffect(() => {
      if selectedCurrency->Option.isNone {
        setSelectedCurrency(_ => Some(initialCurrency))
      }
      None
    }, [])

    let networkOptions = React.useMemo(() => {
      let currentCurrency = currencyInput.value->Option.getOr(initialCurrency)
      let networks = getNetworkArray(Some(currentCurrency))
      networks->Array.map(network => {
        let label = network->String.replaceRegExp(%re("/_/g"), " ")->String.toUpperCase
        {
          DropdownField.value: network,
          label,
          displayValue: label,
        }
      })
    }, [currencyInput.value])

    let handleCurrencyChange = (fn: unit => string) => {
      let newValue = fn()
      setSelectedCurrency(_ => Some(newValue))
      currencyInput.onChange(newValue)
      // When currency changes, automatically select first network option
      let networks = getNetworkArray(Some(newValue))
      switch networks->Array.get(0) {
      | Some(firstNetwork) => networkInput.onChange(firstNetwork)
      | None => networkInput.onChange("")
      }
    }

    let handleNetworkChange = (fn: unit => string) => {
      let newValue = fn()
      networkInput.onChange(newValue)
    }

    <div className="flex flex-col gap-4">
      <DropdownField
        appearance=config.appearance
        fieldName={currencyConfig.displayName}
        value={currencyInput.value->Option.getOr("")}
        setValue={fn => handleCurrencyChange(fn)}
        disabled=false
        options=currencyOptions
        className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
      />
      <DropdownField
        appearance=config.appearance
        fieldName={networkConfig.displayName}
        value={networkInput.value->Option.getOr("")}
        setValue={fn => handleNetworkChange(fn)}
        disabled=false
        options=networkOptions
        className={isSpacedInnerLayout ? "" : "!border-t-0 !border-r-0"}
      />
    </div>
  }
}

@react.component
let make = (~fields: array<fieldConfig>) => {
  if fields->Array.length == 2 {
    switch fields {
    | [currencyConfig, networkConfig] => <CryptoField currencyConfig networkConfig />
    | _ => React.null
    }
  } else {
    fields
    ->Array.map(field => {
      <DynamicInputFields key={field.outputPath} field />
    })
    ->React.array
  }
}
