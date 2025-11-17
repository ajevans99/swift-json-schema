import Foundation

struct SchemaDocument: Sendable {
  let url: URL
  let rawSchema: JSONValue

  init(url: URL, rawSchema: JSONValue) {
    self.url = url
    self.rawSchema = rawSchema
  }

  func value(at pointer: JSONPointer) -> JSONValue? {
    rawSchema.value(at: pointer)
  }
}
