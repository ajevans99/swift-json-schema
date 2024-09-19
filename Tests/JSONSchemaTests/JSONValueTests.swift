import Foundation
import JSONSchema
import Testing

struct JSONValueTests {
  @Test func decodeNil() throws {
    let jsonString = """
      {
        "const": null
      }
      """
    let jsonValue = try JSONDecoder().decode(JSONValue.self, from: jsonString.data(using: .utf8)!)
    #expect(jsonValue == ["const": .null])
  }
}
