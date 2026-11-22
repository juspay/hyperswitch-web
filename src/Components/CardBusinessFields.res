@react.component
let make = (
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~isBancontact,
  ~isSaveDetailsWithClickToPay,
  ~showSaveCardCheckbox,
  ~isSaveCardsChecked,
  ~setIsSaveCardsChecked,
  ~showNickname,
  ~setSelectedInstallmentPlan,
  ~showInstallments,
  ~setShowInstallments,
  ~installmentsError,
  ~setInstallmentsError,
  ~eligibilityOfferDetails,
  ~isEligibilityPending=false,
) => {
  <>
    <DynamicFields
      paymentMethod paymentMethodType setRequiredFieldsBody isBancontact isSaveDetailsWithClickToPay
    />
    <RenderIf condition=showSaveCardCheckbox>
      <div className="flex items-center justify-start">
        <SaveDetailsCheckbox isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked />
      </div>
    </RenderIf>
    <RenderIf condition=showNickname>
      <NicknamePaymentInput />
    </RenderIf>
    <EligibilityOfferNotice eligibilityOfferDetails isEligibilityPending />
    <InstallmentOptions
      setSelectedInstallmentPlan
      showInstallments
      setShowInstallments
      paymentMethod
      errorString=installmentsError
      setErrorString=setInstallmentsError
    />
  </>
}
