@react.component
let make = (
  ~isSaveDetailsWithClickToPay,
  ~setIsSaveDetailsWithClickToPay,
  ~clickToPayCardBrand,
  ~isClickToPayRememberMe,
  ~setIsClickToPayRememberMe,
) => {
  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isUnrecognizedUser = clickToPayConfig.clickToPayCards->Option.getOr([])->Array.length == 0

  let css = SaveDetailsCheckbox.saveDetailsCssStyle(themeObj)

  let getPrivacyNoticeUrl = () => {
    switch String.toLowerCase(clickToPayCardBrand) {
    | "mastercard" => "https://www.mastercard.com/global/click-to-pay/en-us/privacy-notice.html"
    | "visa" => "https://www.visa.com.hk/en_HK/legal/global-privacy-notice.html"
    | _ => "https://www.mastercard.com/global/click-to-pay/en-us/privacy-notice.html"
    }
  }

  let getTermsUrl = () => {
    switch String.toLowerCase(clickToPayCardBrand) {
    | "mastercard" => "https://www.mastercard.com/global/click-to-pay/en-us/terms-of-use.html"
    | "visa" => "https://www.visa.com.hk/en_HK/legal/visa-checkout/terms-of-service.html"
    | _ => "https://www.mastercard.com/global/click-to-pay/en-us/terms-of-use.html"
    }
  }

  let handleOpenUrl = (event: ReactEvent.Mouse.t, url: string) => {
    ReactEvent.Mouse.preventDefault(event)
    let _ = Window.windowOpen(url, "_blank", "")
  }

  let capitalizeCardBrand = (brand: string) => {
    String.toUpperCase(String.substring(brand, ~start=0, ~end=1)) ++
    String.substring(brand, ~start=1, ~end=String.length(brand))
  }

  let formattedCardBrand = capitalizeCardBrand(clickToPayCardBrand)

  let getIsChecked = ev => {
    let target = ev->ReactEvent.Form.target
    target["checked"]
  }

  let (
    isSaveDetailsCheckboxState,
    isSaveDetailsCheckedState,
    isSaveDetailsCheckBoxLabelState,
  ) = isSaveDetailsWithClickToPay
    ? ("Checkbox--checked", "CheckboxInput--checked", "CheckboxLabel--checked")
    : ("", "", "")

  let (
    isRememberMeCheckboxState,
    isRememberMeCheckedState,
    isRememberMeCheckBoxLabelState,
  ) = isClickToPayRememberMe
    ? ("Checkbox--checked", "CheckboxInput--checked", "CheckboxLabel--checked")
    : ("", "", "")

  let handleLearnMore = _ => {
    let cardBrands =
      clickToPayConfig.availableCardBrands->Array.map(brand => brand->JSON.Encode.string)
    Utils.messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", `clickToPayLearnMore`->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      ("metadata", [("cardBrands", cardBrands->JSON.Encode.array)]->Utils.getJsonFromArrayOfJson),
    ])
  }

  <>
    <style> {React.string(css)} </style>
    {!isUnrecognizedUser
      ? <div className="text-xs font-normal">
          {React.string(
            `By continuing, ${clickToPayConfig.dpaName} will share your card details, billing address,
        and email with ${formattedCardBrand} to allow you to securely enroll in Click to
        Pay for faster checkouts.`,
          )}
          {React.string(" ")}
          <span
            className="underline decoration-1 underline-offset-2 cursor-pointer"
            onClick={handleLearnMore}>
            {React.string("Learn more")}
          </span>
        </div>
      : <>
          <style> {React.string(css)} </style>
          <div className={`Checkbox ${isSaveDetailsCheckboxState} flex`}>
            <label
              className={`container CheckboxInput ${isSaveDetailsCheckedState}`}
              style={width: "fit-content"}>
              <input
                type_={`checkbox`} onChange={e => setIsSaveDetailsWithClickToPay(e->getIsChecked)}
              />
              <div className={`checkmark CheckboxInput ${isSaveDetailsCheckedState}`} />
            </label>
            <div
              className={`CheckboxLabel ${isSaveDetailsCheckBoxLabelState} ml-2 w-11/12 text-xs space-y-2`}
              style={color: "#a9a9a9"}>
              <div>
                {React.string(`Save my information with ${formattedCardBrand} `)}
                <span
                  className="underline decoration-1 underline-offset-2 cursor-pointer"
                  onClick={handleLearnMore}>
                  {React.string("Click to Pay")}
                </span>
                {React.string(" ")}
                {React.string("for a faster and secure checkout")}
              </div>
              <div>
                {React.string("Your email or mobile number will be used to verify you.")}
                {React.string("Message/data rates may apply.")}
              </div>
            </div>
          </div>
          <div className={`Checkbox ${isRememberMeCheckboxState} flex`}>
            <label
              className={`container CheckboxInput ${isRememberMeCheckedState}`}
              style={width: "fit-content"}>
              <input
                type_={`checkbox`} onChange={e => setIsClickToPayRememberMe(e->getIsChecked)}
              />
              <div className={`checkmark CheckboxInput ${isRememberMeCheckedState}`} />
            </label>
            <div
              className={`CheckboxLabel ${isRememberMeCheckBoxLabelState} ml-2 w-11/12 text-xs space-y-2`}
              style={color: "#a9a9a9"}>
              <div className="flex items-center">
                {React.string("Remember me on this browser")}
                <div className="relative inline-block ml-2">
                  <div className="group cursor-help">
                    <div
                      className="w-4 h-4 rounded-full bg-[#4a4a4a] flex items-center justify-center cursor-help">
                      <span className="text-white text-xs cursor-help" style={fontSize: "10px"}>
                        {React.string("i")}
                      </span>
                    </div>
                    <div
                      className="invisible group-hover:visible absolute z-10 w-64 bg-white text-xs rounded-md p-2 left-1/2 transform -translate-x-1/2 bottom-[150%] shadow-md border border-gray-200 before:content-[''] before:absolute before:top-[100%] before:left-1/2 before:ml-[-5px] before:border-[5px] before:border-solid before:border-gray-200 before:border-b-transparent before:border-l-transparent before:border-r-transparent after:content-[''] after:absolute after:top-[100%] after:left-1/2 after:ml-[-4px] after:border-[4px] after:border-solid after:border-white after:border-b-transparent after:border-l-transparent after:border-r-transparent">
                      //   {/* Content */}
                      <div className="flex flex-col space-y-2">
                        <span>
                          {React.string("When remembered, you'll skip verification and securely")}
                          {React.string("access your saved cards when paying with Click to Pay.")}
                        </span>
                        <span>
                          {React.string("Not recommended for public or shared devices because")}
                          {React.string("this uses cookies.")}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div>
                {React.string(`By continuing, you agree to ${formattedCardBrand}'s `)}
                <span
                  className="underline decoration-1 underline-offset-2 cursor-pointer"
                  onClick={ev => handleOpenUrl(ev, getTermsUrl())}>
                  {React.string("Terms")}
                </span>
                {React.string(" ")}
                {React.string("and understand your data will be processed according to the ")}
                <span
                  className="underline decoration-1 underline-offset-2 cursor-pointer"
                  onClick={ev => handleOpenUrl(ev, getPrivacyNoticeUrl())}>
                  {React.string("Privacy Notice")}
                </span>
                {React.string(".")}
              </div>
            </div>
          </div>
        </>}
  </>
}
