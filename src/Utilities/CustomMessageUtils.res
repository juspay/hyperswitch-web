// Parsing, validation and segmentation for interactive elements inside
// `paymentMethodsConfig[].message` (e.g. tappable "Terms & Conditions" links).
//
// message: {
//   value: "By clicking you agree to {{terms}}",
//   elementStyles: { link: { color: "#0570DE" } },
//   elements: { terms: { type: "link", config: { label: "Terms" }, style: {...} } },
// }
//
// This module is intentionally free of React/Jotai so it stays pure and easy
// to test. Text is never interpreted as HTML: callers must render segments
// with `React.string` only.

type elementStyle = {
  color: option<string>,
  fontSize: option<float>,
  fontWeight: option<string>,
  fontStyle: option<string>,
  textDecoration: option<string>,
}

let emptyStyle = {
  color: None,
  fontSize: None,
  fontWeight: None,
  fontStyle: None,
  textDecoration: None,
}

type elementType = Link | Unsupported(string)

type element = {
  elementType: elementType,
  label: option<string>,
  style: elementStyle,
}

type elementStyles = {link: elementStyle}

let defaultElementStyles = {link: emptyStyle}

type segment =
  | Text(string)
  | Element({key: string, elementType: elementType, label: string, style: elementStyle})

let elementTypeToString = elementType =>
  switch elementType {
  | Link => "link"
  | Unsupported(str) => str
  }

let supportedElementTypes = ["link"]
let supportedStyleProperties = ["color", "fontSize", "fontWeight", "fontStyle", "textDecoration"]
let supportedFontWeights = ["400", "500", "600", "700"]
let supportedFontStyles = ["normal", "italic"]
let supportedTextDecorations = ["none", "underline"]

let warn = msg => Console.warn(msg)

let quoteList = arr => arr->Array.map(item => `'${item}'`)->Array.join(", ")

let warnUnknownKeys = (validKeys, dict, context) =>
  dict
  ->Dict.keysToArray
  ->Array.forEach(key =>
    if !(validKeys->Array.includes(key)) {
      warn(`Unknown Key: '${key}' key in ${context}`)
    }
  )

// `{{key}}` where key is letters, digits and underscores. Splitting with a
// capturing group yields [text, key, text, key, ..., text]: even indices are
// literal text, odd indices are placeholder keys. `split` ignores `lastIndex`,
// so the shared regex carries no state between calls.
let placeholderRegex = /\{\{([A-Za-z0-9_]+)\}\}/

let splitOnPlaceholders = (value: string) =>
  value->String.splitByRegExp(placeholderRegex)->Array.map(part => part->Option.getOr(""))

let getPlaceholderKeys = (value: string) =>
  value
  ->splitOnPlaceholders
  ->Array.filterWithIndex((_, index) => mod(index, 2) == 1)

let isValidHexColor = str =>
  /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/->RegExp.test(str)

let invalidValueWarning = (~context, ~value, ~expected) =>
  warn(
    `Invalid Value: '${value->JSON.stringify}' in ${context}, Expected ${expected}. The property is ignored.`,
  )

let parseEnumString = (dict, key, ~allowed, ~context) =>
  dict
  ->Dict.get(key)
  ->Option.flatMap(json =>
    switch json->JSON.Decode.string {
    | Some(str) if allowed->Array.includes(str) => Some(str)
    | _ =>
      invalidValueWarning(~context=`${context}.${key}`, ~value=json, ~expected=quoteList(allowed))
      None
    }
  )

let parseStyle = (json: JSON.t, ~context): elementStyle =>
  switch json->JSON.Decode.object {
  | None =>
    invalidValueWarning(~context, ~value=json, ~expected="an object")
    emptyStyle
  | Some(dict) =>
    dict
    ->Dict.keysToArray
    ->Array.forEach(key =>
      if !(supportedStyleProperties->Array.includes(key)) {
        warn(
          `Unsupported style property: '${key}' in ${context}, Supported properties are ${quoteList(
              supportedStyleProperties,
            )}. The property is ignored.`,
        )
      }
    )

    let color =
      dict
      ->Dict.get("color")
      ->Option.flatMap(json =>
        switch json->JSON.Decode.string {
        | Some(str) if isValidHexColor(str) => Some(str)
        | _ =>
          invalidValueWarning(
            ~context=`${context}.color`,
            ~value=json,
            ~expected="a hex colour such as '#0570DE'",
          )
          None
        }
      )

    let fontSize =
      dict
      ->Dict.get("fontSize")
      ->Option.flatMap(json =>
        switch json->JSON.Decode.float {
        | Some(size) if Float.isFinite(size) && size > 0.0 => Some(size)
        | _ =>
          invalidValueWarning(
            ~context=`${context}.fontSize`,
            ~value=json,
            ~expected="a positive number of pixels",
          )
          None
        }
      )

    let fontWeight =
      dict
      ->Dict.get("fontWeight")
      ->Option.flatMap(json => {
        let asString = switch json->JSON.Classify.classify {
        | String(str) => Some(str)
        | Number(num) => Some(num->Float.toString)
        | _ => None
        }
        switch asString {
        | Some(str) if supportedFontWeights->Array.includes(str) => Some(str)
        | _ =>
          invalidValueWarning(
            ~context=`${context}.fontWeight`,
            ~value=json,
            ~expected=quoteList(supportedFontWeights),
          )
          None
        }
      })

    {
      color,
      fontSize,
      fontWeight,
      fontStyle: dict->parseEnumString("fontStyle", ~allowed=supportedFontStyles, ~context),
      textDecoration: dict->parseEnumString(
        "textDecoration",
        ~allowed=supportedTextDecorations,
        ~context,
      ),
    }
  }

// Per-property merge: `override` wins only for the properties it sets.
let mergeStyles = (base: elementStyle, override: elementStyle): elementStyle => {
  color: override.color->Option.orElse(base.color),
  fontSize: override.fontSize->Option.orElse(base.fontSize),
  fontWeight: override.fontWeight->Option.orElse(base.fontWeight),
  fontStyle: override.fontStyle->Option.orElse(base.fontStyle),
  textDecoration: override.textDecoration->Option.orElse(base.textDecoration),
}

let parseElementStyles = (dict, ~context): elementStyles =>
  switch dict->Dict.get("elementStyles") {
  | None => defaultElementStyles
  | Some(json) =>
    switch json->JSON.Decode.object {
    | None =>
      invalidValueWarning(~context=`${context}.elementStyles`, ~value=json, ~expected="an object")
      defaultElementStyles
    | Some(stylesDict) =>
      warnUnknownKeys(supportedElementTypes, stylesDict, `${context}.elementStyles`)
      {
        link: stylesDict
        ->Dict.get("link")
        ->Option.map(parseStyle(_, ~context=`${context}.elementStyles.link`))
        ->Option.getOr(emptyStyle),
      }
    }
  }

let parseElement = (json: JSON.t, ~context): option<element> =>
  switch json->JSON.Decode.object {
  | None =>
    invalidValueWarning(~context, ~value=json, ~expected="an object")
    None
  | Some(dict) =>
    warnUnknownKeys(["type", "config", "style"], dict, context)

    let elementType = switch dict->Dict.get("type")->Option.flatMap(JSON.Decode.string) {
    | Some("link") => Link
    | Some(other) =>
      warn(
        `Unsupported element type: '${other}' in ${context}.type, Expected ${quoteList(
            supportedElementTypes,
          )}. The label is shown as plain text.`,
      )
      Unsupported(other)
    | None =>
      warn(
        `INTEGRATION ERROR: ${context}.type is required, Expected ${quoteList(
            supportedElementTypes,
          )}. The label is shown as plain text.`,
      )
      Unsupported("")
    }

    let configDict =
      dict->Dict.get("config")->Option.flatMap(JSON.Decode.object)->Option.getOr(Dict.make())
    warnUnknownKeys(["label"], configDict, `${context}.config`)

    let label =
      configDict
      ->Dict.get("label")
      ->Option.flatMap(JSON.Decode.string)
      ->Option.filter(label => label->String.trim->String.length > 0)
    if label->Option.isNone {
      warn(
        `INTEGRATION ERROR: ${context}.config.label is required and must be a non-empty string. The placeholder is shown as literal text.`,
      )
    }

    let style =
      dict
      ->Dict.get("style")
      ->Option.map(parseStyle(_, ~context=`${context}.style`))
      ->Option.getOr(emptyStyle)

    Some({elementType, label, style})
  }

let parseElements = (dict, ~context): Dict.t<element> =>
  switch dict->Dict.get("elements") {
  | None => Dict.make()
  | Some(json) =>
    switch json->JSON.Decode.object {
    | None =>
      invalidValueWarning(~context=`${context}.elements`, ~value=json, ~expected="an object")
      Dict.make()
    | Some(elementsDict) =>
      elementsDict
      ->Dict.toArray
      ->Array.filterMap(((key, elementJson)) =>
        elementJson
        ->parseElement(~context=`${context}.elements.${key}`)
        ->Option.map(element => (key, element))
      )
      ->Dict.fromArray
    }
  }

// Cross-checks placeholders in `value` against the `elements` table.
let validatePlaceholders = (~value, ~elements: Dict.t<element>, ~context) => {
  let keys = value->getPlaceholderKeys
  keys->Array.forEach(key =>
    if elements->Dict.get(key)->Option.isNone {
      warn(
        `INTEGRATION ERROR: Placeholder '{{${key}}}' in ${context}.value has no matching element in ${context}.elements. It is shown as literal text.`,
      )
    }
  )
  elements
  ->Dict.keysToArray
  ->Array.forEach(key =>
    if !(keys->Array.includes(key)) {
      warn(
        `Unused element: '${key}' in ${context}.elements is not used in ${context}.value and is ignored.`,
      )
    }
  )
}

// Splits `value` into renderable segments.
//   - placeholder with a valid link element  -> Element (only if interactive)
//   - placeholder with any element + label   -> Text(label)
//   - placeholder without element / label    -> Text("{{key}}")
let toSegments = (
  ~value: string,
  ~elements: Dict.t<element>,
  ~elementStyles: elementStyles,
  ~isInteractive: bool,
): array<segment> =>
  value
  ->splitOnPlaceholders
  ->Array.mapWithIndex((part, index) =>
    if mod(index, 2) == 0 {
      part === "" ? None : Some(Text(part))
    } else {
      switch elements->Dict.get(part) {
      | Some({elementType: Link, label: Some(label), style}) if isInteractive =>
        Some(
          Element({
            key: part,
            elementType: Link,
            label,
            style: mergeStyles(elementStyles.link, style),
          }),
        )
      | Some({label: Some(label)}) => Some(Text(label))
      | _ => Some(Text(`{{${part}}}`))
      }
    }
  )
  ->Array.filterMap(segment => segment)

let segmentsToPlainText = segments =>
  segments
  ->Array.map(segment =>
    switch segment {
    | Text(text) => text
    | Element({label}) => label
    }
  )
  ->Array.join("")

let hasInteractiveElements = (~value, ~elements: Dict.t<element>) =>
  value
  ->getPlaceholderKeys
  ->Array.some(key =>
    switch elements->Dict.get(key) {
    | Some({elementType: Link, label: Some(_)}) => true
    | _ => false
    }
  )

let styleToJsxStyle = (style: elementStyle): JsxDOMStyle.t => {
  color: ?style.color,
  fontSize: ?(style.fontSize->Option.map(size => `${size->Float.toString}px`)),
  fontWeight: ?style.fontWeight,
  fontStyle: ?style.fontStyle,
  textDecoration: ?style.textDecoration,
}
