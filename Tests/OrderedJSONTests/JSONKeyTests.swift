import Foundation
import OrderedCollections
import OrderedJSON
import Testing

struct JSONKeyTests {
  @Test func scalarIdentityAndCodable() throws {
    let composed = JSONKey("\u{e9}")
    let decomposed = JSONKey("e\u{301}")
    #expect(composed != decomposed)
    #expect(Set([composed, decomposed, JSONKey(rawValue: "\u{e9}")]).count == 2)
    #expect([decomposed, composed].sorted() == [decomposed, composed])
    let decoded = try JSONDecoder().decode(JSONKey.self, from: JSONEncoder().encode(decomposed))
    #expect(decoded == decomposed)
    #expect(Array(decoded.rawValue.unicodeScalars) == Array("e\u{301}".unicodeScalars))
  }

  @Test func strictExportsAndExactDuplicatePosition() throws {
    let map = OrderedDictionary<JSONKey, Int>(
      stringKeyedPairs: [("\u{e9}", 1), ("e\u{301}", 2), ("x", 3), ("\u{e9}", 4)]
    )
    #expect(map.count == 3)
    #expect(Array(map.keys) == [JSONKey("e\u{301}"), "x", JSONKey("\u{e9}")])
    #expect(map["\u{e9}"] == 4)
    #expect(map["e\u{301}"] == 2)
    let error = JSONKeyConversionError.canonicalCollision(
      first: JSONKey("e\u{301}"),
      second: JSONKey("\u{e9}")
    )
    #expect(throws: error) { try map.stringKeyed() }
    #expect(throws: error) { try map.stringKeyedDictionary() }
    let ordinary: OrderedDictionary<String, Int> = ["b": 2, "a": 1]
    let imported = OrderedDictionary<JSONKey, Int>(stringKeyed: ordinary)
    #expect(try imported.stringKeyed() == ordinary)
    #expect(try imported.stringKeyedDictionary() == ["a": 1, "b": 2])
    #expect(OrderedDictionary<JSONKey, Int>(stringKeyed: ["a": 1])["a"] == 1)
  }
}
