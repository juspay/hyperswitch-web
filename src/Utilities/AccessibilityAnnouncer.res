// A single announcement consumed by the global <Announcer /> live regions.
// `assertive=true` routes the message to the `role="alert"` region (errors);
// `assertive=false` routes it to the `role="status"` region (status updates).
type announcement = {
  message: string,
  assertive: bool,
}

let defaultAnnouncement = {
  message: "",
  assertive: false,
}

let announcementAtom = Recoil.atom("accessibilityAnnouncement", defaultAnnouncement)

// Returns a function components can call to announce a message to screen readers.
let useAnnounce = () => {
  let setAnnouncement = Recoil.useSetRecoilState(announcementAtom)
  (~assertive=false, message) => setAnnouncement(_ => {message, assertive})
}
