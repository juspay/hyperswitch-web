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
let make = (~name: string) => {
  open Utils
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let field: ReactFinalForm.Field.fieldProps = ReactFinalForm.useField(
    name,
    ~config={
      validate: val => {
        let date = val->Option.map(Date.fromString)
        switch date {
        | Some(date) =>
          if date->checkIs18OrAbove {
            None
          } else {
            Some(localeString.dateOfBirthInvalidText)
          }
        | None => Some(localeString.dateofBirthRequiredText)
        }
      },
    },
  )

  let dateOfBirth =
    field.input.value
    ->Option.flatMap(val => {
      if val === "" {
        None
      } else {
        let date = Date.fromString(val)
        if Date.getTime(date)->Float.isNaN {
          None
        } else {
          Some(date)
        }
      }
    })
    ->Nullable.fromOption

  let onChange = date => {
    LoggerUtils.logInputChangeInfo("dateOfBirth", loggerState)
    let valStr =
      date
      ->Nullable.toOption
      ->Option.map(d => d->Date.toLocaleDateStringWithLocale("en-CA"))
      ->Option.getOr("")
    field.input.onChange(valStr)
  }

  let isNotEligible = field.meta.touched && field.meta.error->Option.isSome
  let errorString = field.meta.error->Option.getOr("")

  <div className="flex flex-col gap-1">
    <div
      className={`Label`}
      style={
        fontWeight: themeObj.fontWeightNormal,
        fontSize: themeObj.fontSizeLg,
        opacity: "0.6",
      }>
      {React.string(localeString.dateOfBirth)}
    </div>
    <DatePicker
      showIcon=true
      icon={<Icon name="calander" size=13 className="!px-[6px] !py-[10px]" />}
      className="w-full border border-gray-300 rounded p-2"
      selected={dateOfBirth}
      onChange
      dateFormat="dd-MM-yyyy"
      wrapperClassName="datepicker"
      shouldCloseOnSelect=true
      placeholderText={localeString.dateOfBirthPlaceholderText}
      renderCustomHeader={val => {
        <div className="flex gap-4 items-center justify-center m-2">
          <select
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
    <RenderIf condition={isNotEligible}>
      <div
        className="Error pt-1"
        style={
          color: themeObj.colorDangerText,
          fontSize: themeObj.fontSizeSm,
          alignSelf: "start",
          textAlign: "left",
        }>
        {React.string(errorString)}
      </div>
    </RenderIf>
  </div>
}
