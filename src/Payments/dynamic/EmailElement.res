open SuperpositionTypes
module EmailField = {
  @react.component
  let make = (~emailConfigs: array<fieldConfig>) => {
    let inputRef = React.useRef(Nullable.null)
    let (emailValue, setEmailValue) = React.useState(_ => "")
    let createFieldValidator = rule =>
      Validation.createFieldValidator(
        rule,
        ~enabledCardSchemes=[],
        ~localeObject=LocaleDataType.defaultLocale,
      )

    let emailInputs = emailConfigs->Array.map(config => {
      let {input, meta} = ReactFinalForm.useField(
        config.outputPath,
        ~config={
          initialValue: Some(""),
          validate: createFieldValidator(Email),
        },
      )
      (config, input, meta)
    })

    let handleChange = ev => {
      let val: string = ReactEvent.Form.target(ev)["value"]
      setEmailValue(_ => val)

      emailInputs->Array.forEach(((_, input, _)) => {
        input.onChange(val)
      })
    }

    let (firstInput, firstMeta) = switch emailInputs->Array.get(0) {
    | Some((_, input, meta)) => (Some(input), Some(meta))
    | None => (None, None)
    }

    let emailErrorString = switch firstMeta {
    | Some(meta) =>
      switch (meta.touched, meta.error) {
      | (true, Some(err)) => err
      | _ => ""
      }
    | None => ""
    }

    let isValid = switch firstMeta {
    | Some(meta) => Some(!(!meta.valid && meta.touched))
    | None => Some(true)
    }

    let onBlur = switch firstInput {
    | Some(input) => input.onBlur
    | None => _ => ()
    }

    let onFocus = switch firstInput {
    | Some(input) => input.onFocus
    | None => _ => ()
    }

    <PaymentField
      fieldName="Email"
      value={{
        value: emailValue,
        isValid,
        errorString: emailErrorString,
      }}
      onChange=handleChange
      onBlur
      onFocus
      type_="email"
      inputRef
      placeholder="example@email.com"
      name="email"
    />
  }
}

@react.component
let make = (~fields: array<fieldConfig>) => {
  if fields->Array.length > 0 {
    <EmailField emailConfigs=fields />
  } else {
    React.null
  }
}
