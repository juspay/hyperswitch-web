// Parsed external data stays unknown until its consuming test describes the
// observed shape. Runtime assertions remain responsible for validating contents.
export function parseJson(text: string): unknown {
  return JSON.parse(text);
}
