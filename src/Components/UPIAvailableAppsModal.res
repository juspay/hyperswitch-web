@react.component
let make = (~availableApps, ~selectedApp: option<UPITypes.appInfo>, ~setSelectedApp) => {
  open RecoilAtoms

  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let logger = Recoil.useRecoilValueFromAtom(loggerAtom)

  let handleAppSelection = (app: UPITypes.appInfo) => {
    setSelectedApp(_ => Some(app))
    logger.setLogInfo(~value=`UPI app selected: ${app.name}`, ~eventName=PAYMENT_METHOD_CHANGED)
  }

  let renderAppButton = (obj: UPITypes.appInfo, i, ~appArrayLen) => {
    let isSelected = switch selectedApp {
    | Some(selected) => selected.packageName === obj.packageName
    | None => false
    }

    <button
      key={obj.packageName}
      type_="button"
      onClick={_ => handleAppSelection(obj)}
      className={`flex items-center w-full p-3 transition-all `}
      style={
        borderBottom: i == appArrayLen - 1 ? "" : `1px solid ${themeObj.borderColor}`,
      }>
      <div className="flex items-center gap-3 w-full">
        <input
          type_="radio"
          name="upi_app"
          value={obj.packageName}
          checked=isSelected
          onChange={_ => handleAppSelection(obj)}
          className="w-4 h-4"
        />
        <Icon name=obj.name size=40 />
        <span className="text-base font-medium" style={color: themeObj.colorText}>
          {React.string(obj.name)}
        </span>
      </div>
    </button>
  }

  <div>
    <div className="text-center mb-6">
      <h2 className="text-xl font-semibold mb-2" style={color: themeObj.colorText}>
        {React.string("Select the UPI App")}
      </h2>
    </div>
    <div className="flex flex-col max-h-64 p-2 overflow-y-auto border rounded-lg">
      <RenderIf condition={availableApps->Array.length !== 0}>
        {availableApps
        ->Array.mapWithIndex((obj, i) =>
          renderAppButton(obj, i, ~appArrayLen=availableApps->Array.length)
        )
        ->React.array}
      </RenderIf>
      <RenderIf condition={availableApps->Array.length === 0}>
        <div className="text-center text-gray-500 py-6">
          {React.string("No UPI apps are available at the moment.")}
        </div>
      </RenderIf>
    </div>
  </div>
}
