// Global ARIA live-region announcer. Renders two visually-hidden regions that
// persist in the DOM for the page lifetime so screen readers pick up dynamic
// status/error messages. Messages auto-clear after 5s so stale text is not
// re-read on subsequent focus.
@react.component
let make = () => {
  let (announcement, setAnnouncement) = Recoil.useRecoilState(
    AccessibilityAnnouncer.announcementAtom,
  )
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      try {
        let dict = ev.data->Utils.safeParse->Utils.getDictFromJson
        switch dict->Dict.get("submitSuccessful")->Option.flatMap(JSON.Decode.bool) {
        | Some(false) =>
          let message =
            dict
            ->Utils.getDictFromDict("error")
            ->Utils.getString("message", localeString.enterValidDetailsText)
          setAnnouncement(_ => {
            message,
            assertive: true,
          })
        | _ => ()
        }
      } catch {
      | _ => ()
      }
    }
    Window.addEventListener("message", handle)
    Some(() => Window.removeEventListener("message", handle))
  }, [localeString.enterValidDetailsText])

  React.useEffect(() => {
    if announcement.message !== "" {
      let timeoutId = setTimeout(() => {
        setAnnouncement(_ => AccessibilityAnnouncer.defaultAnnouncement)
      }, 5000)
      Some(() => clearTimeout(timeoutId))
    } else {
      None
    }
  }, [announcement.message])

  <div className={AccessibilityUtils.visuallyHiddenClass}>
    <div id="hyperswitch-sdk-live-status" role="status" ariaLive={#polite} ariaAtomic=true>
      {(announcement.assertive ? "" : announcement.message)->React.string}
    </div>
    <div id="hyperswitch-sdk-live-alert" role="alert" ariaLive={#assertive} ariaAtomic=true>
      {(announcement.assertive ? announcement.message : "")->React.string}
    </div>
  </div>
}
