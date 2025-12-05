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
  let (error, setError) = React.useState(_ => false)
  let (isNotEligible, setIsNotEligible) = React.useState(_ => false)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()
  let (dateOfBirth, setDateOfBirth) = Recoil.useRecoilState(RecoilAtoms.dateOfBirth)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if isGiftCardOnlyPayment {
        ()
      } else {
        switch dateOfBirth->Nullable.toOption {
        | Some(_) => setError(_ => false)
        | None => ()
        }
      }
    }
  }, (dateOfBirth, isNotEligible, isGiftCardOnlyPayment))

  useSubmitPaymentData(submitCallback)

  let onChange = date => {
    let isAbove18 = switch date->Nullable.toOption {
    | Some(val) => val->checkIs18OrAbove
    | None => false
    }
    LoggerUtils.logInputChangeInfo("dateOfBirth", loggerState)
    setDateOfBirth(_ => date)
    setIsNotEligible(_ => !isAbove18)
  }

  let errorString = error
    ? localeString.dateofBirthRequiredText
    : localeString.dateOfBirthInvalidText

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
    <RenderIf condition={error || isNotEligible}>
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
