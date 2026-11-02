open Utils
open ErrorUtils

type elementStyle = {
  color: option<string>,
  fontSize: option<float>,
  fontWeight: option<string>,
  fontStyle: option<string>,
  textDecoration: option<string>,
}

let defaultElementStyle = {
  color: None,
  fontSize: None,
  fontWeight: None,
  fontStyle: None,
  textDecoration: None,
}

type element = {
  label: string,
  style: elementStyle,
}

type elementStyles = {link: elementStyle}

let defaultElementStyles = {link: defaultElementStyle}

type segment =
  | Text(string)
  | Link({key: string, label: string, style: elementStyle})

let placeholderRegex = /\{\{([A-Za-z0-9_]+)\}\}/

let splitOnPlaceholders = (value: string) =>
  value->String.splitByRegExp(placeholderRegex)->Array.map(part => part->Option.getOr(""))

let getStyleString = (dict, key) =>
  dict
  ->Dict.get(key)
  ->Option.flatMap(json =>
    switch json->JSON.Classify.classify {
    | String(str) => Some(str)
    | Number(num) => Some(num->Float.toString)
    | _ => None
    }
  )

let parseStyle = (json: JSON.t): elementStyle => {
  let dict = json->getDictFromJson
  {
    color: dict->getStyleString("color"),
    fontSize: dict->Dict.get("fontSize")->Option.flatMap(JSON.Decode.float),
    fontWeight: dict->getStyleString("fontWeight"),
    fontStyle: dict->getStyleString("fontStyle"),
    textDecoration: dict->getStyleString("textDecoration"),
  }
}

let mergeStyles = (base: elementStyle, override: elementStyle): elementStyle => {
  color: override.color->Option.orElse(base.color),
  fontSize: override.fontSize->Option.orElse(base.fontSize),
  fontWeight: override.fontWeight->Option.orElse(base.fontWeight),
  fontStyle: override.fontStyle->Option.orElse(base.fontStyle),
  textDecoration: override.textDecoration->Option.orElse(base.textDecoration),
}

let parseElementStyles = (dict): elementStyles => {
  link: dict
  ->getOptionalDict("elementStyles")
  ->Option.flatMap(styles => styles->Dict.get("link"))
  ->Option.map(parseStyle)
  ->Option.getOr(defaultElementStyle),
}

let parseElements = (dict, ~context, ~logger: HyperLoggerTypes.loggerMake): Dict.t<element> =>
  dict
  ->getOptionalDict("elements")
  ->Option.map(elementsDict =>
    elementsDict
    ->Dict.toArray
    ->Array.filterMap(((key, json)) => {
      let context = `${context}.elements.${key}`
      let elementDict = json->getDictFromJson
      let label =
        elementDict
        ->getOptionalDict("config")
        ->Option.flatMap(config => config->getOptionString("label"))
        ->Option.map(String.trim)
        ->Option.getOr("")
      if elementDict->getString("type", "") == "link" && label->String.length > 0 {
        Some((
          key,
          {
            label,
            style: elementDict
            ->Dict.get("style")
            ->Option.map(parseStyle)
            ->Option.getOr(defaultElementStyle),
          },
        ))
      } else {
        manageErrorWarning(
          SDK_CONNECTOR_WARNING,
          ~dynamicStr=`Invalid element '${key}' in ${context}, expected {type: "link", config: {label: "..."}}. The placeholder is shown as literal text.`,
          ~logger,
        )
        None
      }
    })
    ->Dict.fromArray
  )
  ->Option.getOr(Dict.make())

let messageToSegments = (
  ~value: string,
  ~elements: Dict.t<element>,
  ~elementStyles: elementStyles,
): array<segment> =>
  value
  ->splitOnPlaceholders
  ->Array.mapWithIndex((part, index) =>
    if mod(index, 2) == 0 {
      part === "" ? None : Some(Text(part))
    } else {
      switch elements->Dict.get(part) {
      | Some({label, style}) =>
        Some(Link({key: part, label, style: mergeStyles(elementStyles.link, style)}))
      | None => Some(Text(`{{${part}}}`))
      }
    }
  )
  ->Array.filterMap(segment => segment)

let segmentsToPlainText = segments =>
  segments
  ->Array.map(segment =>
    switch segment {
    | Text(text) => text
    | Link({label}) => label
    }
  )
  ->Array.join("")

let styleToJsxStyle = (style: elementStyle): JsxDOMStyle.t => {
  color: ?style.color,
  fontSize: ?(style.fontSize->Option.map(size => `${size->Float.toString}px`)),
  fontWeight: ?style.fontWeight,
  fontStyle: ?style.fontStyle,
  textDecoration: ?style.textDecoration,
}
