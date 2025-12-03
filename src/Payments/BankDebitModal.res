open CardUtils
open ACHTypes

type focus = Routing | Account | NONE

module Button = {
  @react.component
  let make = (~active=true, ~onclick) => {
    <div
      onClick={ev => active ? onclick(ev) : ()}
      className={`p-2 mt-10 rounded-md w-full flex justify-center items-center text-white text-sm bg-[#006DF9] ${active
          ? "cursor-pointer"
          : "opacity-50 cursor-not-allowed"}`}>
      {React.string("Done")}
    </div>
  }
}

module CardItem = {
  @react.component
  let make = (~keyItem, ~value) => {
    <div className="flex flex-col gap-2 text-xs">
      <div className="font-fira-code text-[#151A1F]/60"> {React.string(keyItem)} </div>
      <div> {React.string(value)} </div>
    </div>
  }
}

module MicroDepositScreen = {
  @react.component
  let make = (~showMicroDepScreen, ~accountNum, ~onclick) => {
    let last4digits = accountNum->String.sliceToEnd(~start=-4)
    <div
      className={`flex flex-col animate-slideLeft ${showMicroDepScreen
          ? "visible"
          : "hidden"} justify-center items-center`}>
      <Icon name="wallet-savings" size=55 className="mb-8" />
      <div className=" font-semibold text-lg text-[#151A1F] mb-4">
        {React.string("Micro-deposits initiated")}
      </div>
      <div className="text-center text-sm text-[#151A1F]/30 mb-8">
        {React.string(
          `Expect a $0.01 deposit to the account ending in **** ${last4digits} in 1-2 business days and an email with additional instructions to verify your account.`,
        )}
      </div>
      <div className="flex flex-col bg-[#F6F5F5] w-full border border-[#DFDFE0] rounded-md mb-10">
        <div
          className="flex flex-row gap-6 px-6 py-4 items-center border-dotted border-b-2 border-[#DFDFE0]">
          <Icon name="bank" size=20 className="text-[#151A1F]/60" />
          <div className="text-[#151A1F]/80 text-sm">
            {React.string(`**** ${last4digits}  BANK STATEMENT`)}
          </div>
        </div>
        <div className="flex flex-row gap-4 px-6 py-4 items-center">
          <CardItem keyItem="Transaction" value="SMXXXX" />
          <CardItem keyItem="Amount" value="$0.01" />
          <CardItem keyItem="Type" value="ACH Direct Debit" />
        </div>
      </div>
      <Button onclick={ev => onclick(ev)} />
      <PoweredBy className="mt-5" />
    </div>
  }
}

module AccountNumberCard = {
  @react.component
  let make = (~inputFocus) => {
    <div className="relative w-full">
      <div className="border border-[#DFDFE0] bg-[#F6F5F5] h-28 rounded w-full">
        <div className="flex flex-row gap-4 text-[#6c6c6c5e] m-6 justify-center items-center">
          <Icon size=22 name="bank" />
          <div className="flex flex-col gap-1 w-full">
            <div className="w-[30%] h-1 bg-[#DFDFE0] rounded-full" />
            <div className="w-[50%] h-1 bg-[#DFDFE0] rounded-full" />
          </div>
        </div>
        <div className="flex flex-row gap-3  text-[#6c6c6c5e] mx-6 mt-8 justify-start items-center">
          <div
            className={`flex flex-row items-end border-b-2 ${inputFocus == Routing
                ? "border-yellow-500 text-[#151A1F]"
                : "border-transparent"}`}>
            <Icon size=12 name="cheque" />
            <div className="text-xs"> {React.string("123456789")} </div>
          </div>
          <div
            className={`flex flex-row items-end border-b-2 ${inputFocus == Account
                ? "border-yellow-500 text-[#151A1F]"
                : "border-transparent"}`}>
            <Icon size=12 name="cheque" />
            <div className="text-xs"> {React.string("000123456789")} </div>
          </div>
          <div className="flex flex-row items-end border-b-2 border-transparent">
            <Icon size=12 name="cheque" />
            <div className="text-xs"> {React.string("1234")} </div>
          </div>
        </div>
      </div>
      <div
        className=" bg-[#DFDFE0] h-28 rounded-r absolute right-0 top-0 w-[20%]"
        style={clipPath: "polygon(50% 0, 100% 0, 100% 100%, 0% 100%)"}
      />
    </div>
  }
}

let clearSpaces = str => str->String.replaceRegExp(%re("/\D+/g"), "")
@react.component
let make = (~setModalData) => {
  let selectedOption = Recoil.useRecoilValueFromAtom(RecoilAtoms.selectedOptionAtom)
  let (routingNumber, setRoutingNumber) = React.useState(_ => "")
  let (iban, setIban) = React.useState(_ => "")
  let (sortCode, setSortCode) = React.useState(_ => "")
  let (isRoutingValid, setIsRoutingValid) = React.useState(_ => None)
  let (routingError, setRoutingError) = React.useState(_ => "")
  let {themeObj, config, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (accountType, setAccountType) = React.useState(() => "Savings")

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (areRequiredFieldsValid, setAreRequiredFieldsValid) = React.useState(_ => true)
  let (areRequiredFieldsEmpty, setAreRequiredFieldsEmpty) = React.useState(_ => false)

  let (openModal, setOpenModal) = React.useState(_ => false)

  let (accountNum, setAccountNum) = React.useState(_ => "")
  let (accountHolderName, setAccountHolderName) = React.useState(_ => "")

  let (_, setInputFocus) = React.useState(_ => NONE)

  let routeref = React.useRef(Nullable.null)
  let accountRef = React.useRef(Nullable.null)
  let nameRef = React.useRef(Nullable.null)
  let ibanRef = React.useRef(Nullable.null)
  let sortCodeRef = React.useRef(Nullable.null)

  let resetReoutingError = () => {
    setIsRoutingValid(_ => None)
    setRoutingError(_ => "")
  }
  let changeSortCode = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    setSortCode(_ => val->Utils.formatBSB)
  }

  let routingBlur = ev => {
    let routingNumber = ReactEvent.Focus.target(ev)["value"]
    let number = routingNumber->clearSpaces
    setInputFocus(_ => NONE)
    if number->String.length == 0 {
      resetReoutingError()
    }
  }

  let handleRoutingChange = ev => {
    let routingNumber = ReactEvent.Form.target(ev)["value"]
    if (
      Utils.validateRountingNumber(routingNumber->clearSpaces) &&
      routingNumber->clearSpaces->String.length == 9
    ) {
      setIsRoutingValid(_ => Some(true))
      setRoutingError(_ => "")
      accountRef.current->Nullable.toOption->Option.forEach(input => input->focus)->ignore
    } else {
      resetReoutingError()
    }
    setRoutingNumber(_ => routingNumber->clearSpaces)
  }

  let handleAccountNumChange = ev => {
    let accNumber = ReactEvent.Form.target(ev)["value"]
    setAccountNum(_ => accNumber->clearSpaces)
  }
  let changeIBAN = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    setIban(_ => val->Utils.formatIBAN)
  }
  let isSepaDebit = selectedOption->String.includes("sepa_debit")
  let isAchDebit = selectedOption->String.includes("ach_debit")
  let isBecsDebit = selectedOption->String.includes("becs_debit")

  let handleAccountHolderNameChange = ev => {
    let accName = ReactEvent.Form.target(ev)["value"]
    setAccountHolderName(_ => accName)
  }
  let submitActive =
    (accountNum->String.length > 0 && routingNumber->String.length > 0) ||
    iban !== "" ||
    (accountNum->String.length > 0 && sortCode->String.length > 0)

  let onClickHandler = () => {
    setModalData(_ => Some({
      routingNumber,
      accountNumber: accountNum,
      accountHolderName,
      accountType: accountType->String.toLowerCase,
      iban,
      sortCode,
      requiredFieldsBody,
    }))
    Modal.close(setOpenModal)
  }

  let dynamicFieldsModalBody =
    <div className="flex flex-col item-center gap-5">
      <DynamicFields
        paymentMethod="bank_debit"
        paymentMethodType="sepa"
        setRequiredFieldsBody
        setAreRequiredFieldsValid
        setAreRequiredFieldsEmpty
      />
      <PayNowButton onClickHandler label="Done" />
    </div>

  let nonDynamicFieldsModalBody =
    <>
      <div
        style={color: themeObj.colorPrimary, marginBottom: "5px"}
        className="self-start font-semibold text-lg text-[#151A1F]">
        {React.string(localeString.billingDetailsText)}
      </div>
      <div className="my-4">
        <AddressPaymentInput
          paymentType=Payment
          className="focus:outline-none border border-gray-300 focus:border-[#006DF9] rounded-md text-sm"
        />
      </div>
      <div
        style={color: themeObj.colorPrimary, marginBottom: "5px"}
        className="self-start font-semibold text-lg text-[#151A1F]">
        {React.string("Bank Details")}
      </div>
      <div
        className={`Label mb-1 mt-5`}
        style={
          fontWeight: themeObj.fontWeightNormal,
          fontSize: themeObj.fontSizeLg,
          color: themeObj.colorText,
          marginBottom: "5px",
        }>
        {React.string("Account Holder Name")}
      </div>
      <Input
        value=accountHolderName
        inputRef=nameRef
        onChange=handleAccountHolderNameChange
        type_="tel"
        className={`p-2 text-base px-4`}
        maxLength=17
        placeholder="eg: John Doe"
        onBlur={_ => setInputFocus(_ => NONE)}
      />
      <RenderIf condition={isSepaDebit}>
        <div
          className={`Label mb-1 mt-5`}
          style={
            fontWeight: themeObj.fontWeightNormal,
            fontSize: themeObj.fontSizeLg,
            color: themeObj.colorText,
            marginBottom: "5px",
          }>
          {React.string("IBAN")}
        </div>
        <Input
          value=iban
          onChange=changeIBAN
          type_="text"
          maxLength=42
          inputRef=ibanRef
          placeholder="eg: DE00 0000 0000 0000 0000 00"
        />
      </RenderIf>
      <div className="flex flex-row items-center w-full justify-between">
        <RenderIf condition={isAchDebit}>
          <div className="w-full" style={marginRight: "1rem"}>
            <div
              className={`Label mb-1 mt-5`}
              style={
                fontWeight: themeObj.fontWeightNormal,
                fontSize: themeObj.fontSizeLg,
                color: themeObj.colorText,
                marginBottom: "5px",
              }>
              {React.string("Routing number")}
            </div>
            <Input
              value=routingNumber
              inputRef=routeref
              isValid=isRoutingValid
              setIsValid=setIsRoutingValid
              onChange=handleRoutingChange
              type_="tel"
              className={` p-2 text-base px-4`}
              maxLength=9
              placeholder="123456789"
              errorString=routingError
              onBlur=routingBlur
              onFocus={_ => setInputFocus(_ => Routing)}
            />
          </div>
        </RenderIf>
        <RenderIf condition={isAchDebit || isBecsDebit}>
          <div className="w-full ">
            <div
              className={`Label mb-1 mt-5`}
              style={
                fontWeight: themeObj.fontWeightNormal,
                fontSize: themeObj.fontSizeLg,
                color: themeObj.colorText,
                marginBottom: "5px",
              }>
              {React.string("Account number")}
            </div>
            <Input
              value=accountNum
              inputRef=accountRef
              onChange=handleAccountNumChange
              type_="tel"
              className={`p-2 text-base px-4`}
              maxLength={isBecsDebit ? 9 : 17}
              placeholder="000123456789"
              onFocus={_ => setInputFocus(_ => Account)}
              onBlur={_ => setInputFocus(_ => NONE)}
            />
          </div>
        </RenderIf>
      </div>
      <RenderIf condition={isAchDebit}>
        <div
          className="w-full mb-1 mt-5"
          style={
            fontWeight: themeObj.fontWeightNormal,
            fontSize: themeObj.fontSizeLg,
            color: themeObj.colorText,
            marginBottom: "5px",
          }>
          <DropdownField
            appearance=config.appearance
            fieldName="Account type"
            value=accountType
            setValue=setAccountType
            disabled=false
            options=[
              {
                value: "Savings",
              },
              {
                value: "Checking",
              },
            ]
            className=" focus:outline-none border border-gray-300 focus:border-[#006DF9] rounded-md text-sm"
          />
        </div>
      </RenderIf>
      <RenderIf condition={isBecsDebit}>
        <div
          className={`Label mb-1 mt-5`}
          style={
            fontWeight: themeObj.fontWeightNormal,
            fontSize: themeObj.fontSizeLg,
            color: themeObj.colorText,
            marginBottom: "5px",
          }>
          {React.string("BSB")}
        </div>
        <Input
          value=sortCode
          inputRef=sortCodeRef
          onChange=changeSortCode
          type_="tel"
          className={`p-2 text-base px-4`}
          maxLength=7
          placeholder="eg: 000-000"
        />
      </RenderIf>
      <Button
        active=submitActive
        onclick={_ => {
          setModalData(_ => Some({
            routingNumber,
            accountNumber: accountNum,
            accountHolderName,
            accountType: accountType->String.toLowerCase,
            iban,
            sortCode,
          }))
          Modal.close(setOpenModal)
        }}
      />
    </>

  <Modal loader=false testMode=true openModal setOpenModal>
    <div className="flex flex-col w-full h-auto overflow-scroll">
      <div className={`flex flex-col`}>
        {isSepaDebit ? dynamicFieldsModalBody : nonDynamicFieldsModalBody}
        <PoweredBy className="mt-5" />
      </div>
    </div>
  </Modal>
}
