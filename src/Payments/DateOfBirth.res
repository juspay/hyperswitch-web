%%raw(`import ("react-datepicker/dist/react-datepicker.css")`)

let months = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
]

let startYear = 1900
let currentYear = Date.getFullYear(Date.make())
let years = Array.fromInitializer(~length=currentYear - startYear, i => currentYear - i)

@react.component
let make = (~fieldConfig: SuperpositionTypes.fieldConfig) => {
  let path = fieldConfig.confirmRequestWritePath
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
    ~field=fieldConfig,
    ~localeObject=localeString,
  )
  let dateFormat = fieldConfig.inputFormatPattern->Option.getOr("dd-MM-yyyy")
  let (selectedDate, setSelectedDate) = React.useState(() => Nullable.null)

  let validate = DynamicFieldsUtils.resolveValidator(~field=fieldConfig, ~localeObject=localeString)

  let field = ReactFinalForm.useField(path, ~config={validate: validate})
  let invalid = field.meta.invalid
  let showError = field.meta.touched || field.meta.submitFailed
  let inputId = React.useId()
  let labelId = inputId ++ "-label"
  let hasError = showError && invalid
  let (
    accessibleLabel,
    errorId,
    describedById,
    ariaInvalid,
  ) = AccessibilityUtils.getFieldAccessibility(
    ~controlId=inputId,
    ~fieldName=label,
    ~placeholder,
    ~ariaLabel=None,
    ~hasError,
    ~isValid=None,
  )

  <div className="flex flex-col gap-1">
    <div
      id={labelId}
      className={`Label`}
      style={
        fontWeight: themeObj.fontWeightNormal,
        fontSize: themeObj.fontSizeLg,
        opacity: "0.6",
      }>
      {accessibleLabel->React.string}
    </div>
    <DatePicker
      showIcon=true
      icon={<Icon name="calander" size=13 className="!px-[6px] !py-[10px]" />}
      className="w-full border border-gray-300 rounded p-2"
      selected={selectedDate}
      onBlur={_ => field.input.onBlur()}
      onChange={date => {
        setSelectedDate(_ => date)
        let strVal =
          date
          ->Nullable.toOption
          ->Option.map(d => d->Date.toLocaleDateStringWithLocale("en-CA"))
          ->Option.getOr("")
        field.input.onChange(strVal)
      }}
      dateFormat
      wrapperClassName="datepicker"
      shouldCloseOnSelect=true
      placeholderText={placeholder}
      id={inputId}
      ariaLabelledBy={labelId}
      ariaRequired={fieldConfig.isRequired ? "true" : "false"}
      ariaInvalid
      ariaDescribedBy=?describedById
      renderCustomHeader={val => {
        <div className="flex gap-4 items-center justify-center m-2">
          <select
            id="dob-year"
            ariaLabel={localeString.yearLabel}
            className="p-1"
            value={val.date->Date.getFullYear->Int.toString}
            onChange={ev => {
              let value = {ev->ReactEvent.Form.target}["value"]
              val.changeYear(value)
            }}>
            {years
            ->Array.map(option =>
              <option key={option->Int.toString} value={option->Int.toString}>
                {option->React.int}
              </option>
            )
            ->React.array}
          </select>
          <select
            id="dob-month"
            ariaLabel={localeString.monthLabel}
            className="p-1"
            value={months[val.date->Date.getMonth]->Option.getOr("January")}
            onChange={ev => {
              let value = {ev->ReactEvent.Form.target}["value"]
              val.changeMonth(months->Array.indexOf(value))
            }}>
            {months
            ->Array.map(option =>
              <option key={option} value={option}> {option->React.string} </option>
            )
            ->React.array}
          </select>
        </div>
      }}
    />
    <RenderIf condition={hasError}>
      <LiveError
        text={field.meta.error->Option.getOr("")}
        id={errorId}
        className="Error pt-1"
        style={{
          color: themeObj.colorDangerText,
          fontSize: themeObj.fontSizeSm,
          alignSelf: "start",
          textAlign: "left",
        }}
      />
    </RenderIf>
  </div>
}
