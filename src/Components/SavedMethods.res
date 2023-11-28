open CardUtils
@react.component
let make = (
  ~paymentToken,
  ~setPaymentToken,
  ~savedMethods: array<PaymentType.customerMethods>,
  ~loadSavedCards: PaymentType.savedCardsLoadState,
  ~cvcProps,
  ~paymentType,
  ~list,
  ~setRequiredFieldsBody,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (showFeilds, setShowFeilds) = Recoil.useRecoilState(RecoilAtoms.showCardFeildsAtom)
  let (token, _) = paymentToken
  let savedCardlength = savedMethods->Js.Array2.length
  let bottomElement = {
    savedMethods
    ->Js.Array2.mapi((obj, i) => {
      let brandIcon = getCardBrandIcon(
        switch obj.card.scheme {
        | Some(ele) => ele
        | None => ""
        }->cardType,
        ""->CardTheme.getPaymentMode,
      )
      let isActive = token == obj.paymentToken
      <SavedCardItem
        key={i->Belt.Int.toString}
        setPaymentToken
        isActive
        paymentItem=obj
        brandIcon
        index=i
        savedCardlength
        cvcProps
        paymentType
        list
      />
    })
    ->React.array
  }

  <>
    <div
      className="flex flex-col overflow-auto h-auto no-scrollbar animate-slowShow"
      style={ReactDOMStyle.make(~padding="5px", ())}>
      {if (
        savedCardlength === 0 && (loadSavedCards === PaymentType.LoadingSavedCards || !showFeilds)
      ) {
        <div
          className="Label flex flex-row gap-3 items-end cursor-pointer"
          style={ReactDOMStyle.make(
            ~fontSize="14px",
            ~color=themeObj.colorPrimary,
            ~fontWeight="400",
            ~marginTop="25px",
            (),
          )}>
          <PaymentElementShimmer.Shimmer>
            <div className="animate-pulse w-full h-12 rounded bg-slate-200 ">
              <div className="flex flex-row  my-auto">
                <div className=" w-10 h-5 rounded-full m-3 bg-white bg-opacity-70 " />
                <div className=" my-auto w-24 h-2 rounded m-3 bg-white bg-opacity-70 " />
              </div>
            </div>
          </PaymentElementShimmer.Shimmer>
        </div>
      } else {
        <RenderIf condition={!showFeilds}>
          <Block bottomElement padding="px-4 py-1" className="max-h-[309px] overflow-auto" />
        </RenderIf>
      }}
      <RenderIf condition={list.payment_methods->Js.Array.length !== 0}>
        <DynamicFields
          paymentType list paymentMethod="card" paymentMethodType="debit" setRequiredFieldsBody isSavedCardFlow=true savedCards=savedMethods
        />
      </RenderIf>
      <RenderIf condition={!showFeilds}>
        <div
          className="Label flex flex-row gap-3 items-end cursor-pointer"
          style={ReactDOMStyle.make(
            ~fontSize="14px",
            ~float="left",
            ~marginTop="14px",
            ~fontWeight="500",
            ~width="fit-content",
            ~color=themeObj.colorPrimary,
            (),
          )}
          onClick={_ => {
            setShowFeilds(._ => true)
          }}>
          <Icon name="circle-plus" size=22 /> {React.string(localeString.addNewCard)}
        </div>
      </RenderIf>
    </div>
  </>
}
