import Foundation

struct SchemaDocument: Sendable {
  let url: URL
  let rawSchema: JSONValue

  func value(at pointer: JSONPointer) -> JSONValue? {
    rawSchema.value(at: pointer)
  }
}
