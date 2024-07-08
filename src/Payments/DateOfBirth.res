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
let make = () => {
  open Utils
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (selectedDate, setSelectedDate) = Recoil.useRecoilState(RecoilAtoms.dateOfBirth)
  let (error, setError) = React.useState(_ => false)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      switch selectedDate->Nullable.toOption {
      | Some(_) => setError(_ => false)
      | None => setError(_ => true)
      }
    }
  }, [selectedDate])

  useSubmitPaymentData(submitCallback)

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
      selected={selectedDate}
      onChange={date => setSelectedDate(_ => date)}
      dateFormat="dd-MM-yyyy"
      wrapperClassName="datepicker"
      placeholderText="Enter Date of Birth"
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
    <RenderIf condition={error}>
      <div
        className="Error pt-1"
        style={
          color: themeObj.colorDangerText,
          fontSize: themeObj.fontSizeSm,
          alignSelf: "start",
          textAlign: "left",
        }>
        {React.string("Date of birth is required")}
      </div>
    </RenderIf>
  </div>
}
