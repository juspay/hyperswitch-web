open SuperpositionTypes

%%raw(`import ("react-datepicker/dist/react-datepicker.css")`)

@react.component
let make = (
  ~field: fieldConfig,
  ~input: ReactFinalForm.inputProps<JsxEventU.Focus.t>,
  ~meta: ReactFinalForm.fieldState,
) => {
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

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

  let label = field.displayName
  let placeholder = field.displayName

  let dateValue = switch input.value->Option.getOr("") {
  | "" => Nullable.null
  | dateStr => {
      let date = Date.fromString(dateStr)
      if Date.getTime(date)->Float.isNaN {
        Nullable.null
      } else {
        Nullable.make(date)
      }
    }
  }

  let handleDateChange = date => {
    let dateStr = switch date->Nullable.toOption {
    | Some(d) => d->Date.toISOString->String.split("T")->Array.get(0)->Option.getOr("")
    | None => ""
    }
    input.onChange(dateStr)
  }

  let checkIs18OrAbove = date => {
    let today = Date.make()
    let birthDate = date
    let age = Date.getFullYear(today) - Date.getFullYear(birthDate)
    let monthDiff = Date.getMonth(today) - Date.getMonth(birthDate)
    let dayDiff = Date.getDate(today) - Date.getDate(birthDate)

    if monthDiff < 0 || (monthDiff === 0 && dayDiff < 0) {
      age - 1 >= 18
    } else {
      age >= 18
    }
  }

  let isNotEligible = switch dateValue->Nullable.toOption {
  | Some(date) => !checkIs18OrAbove(date)
  | None => false
  }

  let errorString = switch (meta.touched, meta.error) {
  | (true, Some(err)) => err
  | _ => ""
  }

  let finalErrorString = if isNotEligible {
    localeString.dateOfBirthInvalidText
  } else {
    errorString
  }

  <div className="flex flex-col gap-1">
    <div
      className={`Label`}
      style={
        fontWeight: themeObj.fontWeightNormal,
        fontSize: themeObj.fontSizeLg,
        opacity: "0.6",
      }>
      {React.string(label)}
    </div>
    <DatePicker
      showIcon=true
      icon={<Icon name="calander" size=13 className="!px-[6px] !py-[10px]" />}
      className="w-full border border-gray-300 rounded p-2"
      selected={dateValue}
      onChange=handleDateChange
      dateFormat="dd-MM-yyyy"
      wrapperClassName="datepicker"
      shouldCloseOnSelect=true
      placeholderText={placeholder}
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
    <RenderIf condition={finalErrorString !== ""}>
      <div
        className="Error pt-1"
        style={
          color: themeObj.colorDangerText,
          fontSize: themeObj.fontSizeSm,
          alignSelf: "start",
          textAlign: "left",
        }>
        {React.string(finalErrorString)}
      </div>
    </RenderIf>
  </div>
}
