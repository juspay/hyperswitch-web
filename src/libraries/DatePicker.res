// * For reference - https://reactdatepicker.com/

type customHeaderProps = {
  date: Date.t,
  selectingDate: Date.t,
  monthDate: Date.t,
  increaseMonth: unit => unit,
  decreaseMonth: unit => unit,
  changeMonth: int => unit,
  increaseYear: unit => unit,
  decreaseYear: unit => unit,
  changeYear: unit => unit,
  prevMonthButtonDisabled: bool,
  nextMonthButtonDisabled: bool,
  prevYearButtonDisabled: bool,
  nextYearButtonDisabled: bool,
}

@module("react-datepicker") @react.component
external make: (
  ~selected: Date.t,
  ~onChange: Date.t => unit,
  ~showIcon: bool=?,
  ~icon: React.element=?,
  ~dateFormat: string=?,
  ~customInput: React.element=?,
  ~popperPlacement: string=?,
  ~renderCustomHeader: customHeaderProps => React.element=?,
  ~showWeekNumbers: bool=?,
  ~placeholderText: string=?,
  ~wrapperClassName: string=?,
) => React.element = "default"
