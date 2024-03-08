open CardUtils
open Utils
@react.component
let make = (
  ~paymentToken,
  ~setPaymentToken,
  ~savedMethods: array<PaymentType.customerMethods>,
  ~loadSavedCards: PaymentType.savedCardsLoadState,
  ~cvcProps,
  ~paymentType,
  ~list,
) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (showFields, setShowFields) = Recoil.useRecoilState(RecoilAtoms.showCardFieldsAtom)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Js.Dict.empty())
  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
  }
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
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

  let (isCVCValid, _, cvcNumber, _, _, _, _, _, _, setCvcError) = cvcProps
  let complete = switch isCVCValid {
  | Some(val) => token !== "" && val
  | _ => false
  }
  let empty = cvcNumber == ""

  let submitCallback = React.useCallback4((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let (token, customerId) = paymentToken
    let savedCardBody = PaymentBody.savedCardBody(~paymentToken=token, ~customerId, ~cvcNumber)
    if confirm.doSubmit {
      if areRequiredFieldsValid && complete && !empty {
        intent(
          ~bodyArr=savedCardBody
          ->Js.Dict.fromArray
          ->Js.Json.object_
          ->OrcaUtils.flattenObject(true)
          ->OrcaUtils.mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->OrcaUtils.getArrayOfTupleFromDict,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          (),
        )
      } else {
        if cvcNumber === "" {
          setCvcError(_ => localeString.cvcNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if !(isCVCValid->Belt.Option.getWithDefault(false)) {
          setUserError(localeString.enterValidDetailsText)
        }
      }
    }
  }, (areRequiredFieldsValid, requiredFieldsBody, empty, complete))
  submitPaymentData(submitCallback)

  <>
    <div
      className="flex flex-col overflow-auto h-auto no-scrollbar animate-slowShow"
      style={ReactDOMStyle.make(~padding="5px", ())}>
      {if (
        savedCardlength === 0 && (loadSavedCards === PaymentType.LoadingSavedCards || !showFields)
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
        <RenderIf condition={!showFields}>
          <Block bottomElement padding="px-4 py-1" className="max-h-[309px] overflow-auto" />
        </RenderIf>
      }}
      <DynamicFields
        paymentType
        list
        paymentMethod="card"
        paymentMethodType="debit"
        setRequiredFieldsBody
        isSavedCardFlow=true
        savedCards=savedMethods
      />
      <RenderIf condition={!showFields}>
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
            setShowFields(._ => true)
          }}>
          <Icon name="circle-plus" size=22 />
          {React.string(localeString.addNewCard)}
        </div>
      </RenderIf>
    </div>
  </>
}
