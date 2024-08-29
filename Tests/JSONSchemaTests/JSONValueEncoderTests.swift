import JSONSchema
import Testing

struct JSONValueEncoderTests {
  struct Primitives {
    let encoder = JSONValueEncoder()

    @Test
    func encodeInt() {
      let value = 42
      let result = try? encoder.encode(value)
      #expect(result == .integer(42))
    }

    @Test
    func encodeDouble() {
      let value = 3.14
      let result = try? encoder.encode(value)
      #expect(result == .number(3.14))
    }

    @Test
    func encodeString() {
      let value = "Hello, World!"
      let result = try? encoder.encode(value)
      #expect(result == .string("Hello, World!"))
    }

    @Test
    func encodeBool() {
      let value = true
      let result = try? encoder.encode(value)
      #expect(result == .boolean(true))
    }

    @Test
    func encodeNil() {
      let result = try? encoder.encode(Optional<Int>.none)
      #expect(result == .null)
    }

    @Test
    func encodeJSONValue() {
      let result = try? encoder.encode(JSONValue.number(40))
      #expect(result == 40)
    }
  }

  struct Arrays {
    let encoder = JSONValueEncoder()

    @Test
    func encodeArrayOfInts() {
      let value = [1, 2, 3]
      let result = try? encoder.encode(value)
      #expect(result == .array([.integer(1), .integer(2), .integer(3)]))
    }

    @Test
    func encodeEmptyArray() {
      let value: [Int] = []
      let result = try? encoder.encode(value)
      #expect(result == .array([]))
    }

    @Test
    func encodeMixedArray() {
      let value: [JSONValue] = [1, "two", true]
      let result = try? encoder.encode(value)
      #expect(result == .array([.integer(1), .string("two"), .boolean(true)]))
    }
  }

  struct Dictionaries {
    let encoder = JSONValueEncoder()

    @Test
    func encodeStringIntDictionary() {
      let value = ["age": 30]
      let result = try? encoder.encode(value)
      #expect(result == .object(["age": .integer(30)]))
    }

    @Test
    func encodeEmptyDictionary() {
      let value: [String: Int] = [:]
      let result = try? encoder.encode(value)
      #expect(result == .object([:]))
    }

    @Test
    func encodeNestedDictionary() {
      let value = ["person": ["name": "Alice", "age": 30]] as [String: JSONValue]
      let result = try? encoder.encode(value)
      #expect(result == .object(["person": .object(["name": .string("Alice"), "age": .integer(30)])]))
    }
  }

  struct Optionals {
    let encoder = JSONValueEncoder()

    @Test
    func encodeNonNilOptional() {
      let value: Int? = 42
      let result = try? encoder.encode(value)
      #expect(result == .integer(42))
    }

    @Test
    func encodeNilOptional() {
      let value: Int? = nil
      let result = try? encoder.encode(value)
      #expect(result == .null)
    }

    @Test
    func encodeOptionalArrayWithNil() {
      let value: [Int?] = [1, nil, 3]
      let result = try? encoder.encode(value)
      #expect(result == .array([.integer(1), .null, .integer(3)]))
    }
  }

  struct NestedStructures {
    let encoder = JSONValueEncoder()

    @Test
    func encodeNestedArray() {
      let value = [[1, 2], [3, 4]]
      let result = try? encoder.encode(value)
      #expect(result == .array([.array([.integer(1), .integer(2)]), .array([.integer(3), .integer(4)])]))
    }

    @Test
    func encodeStructWithNestedArray() {
      struct DataWrapper: Codable {
        let data: [Int]
      }

      let value = DataWrapper(data: [1, 2, 3])
      let result = try? encoder.encode(value)
      #expect(result == .object(["data": .array([.integer(1), .integer(2), .integer(3)])]))
    }
  }

  struct CustomTypes {
    let encoder = JSONValueEncoder()

    struct Person: Codable {
      let name: String
      let age: Int
    }

    @Test
    func encodeCustomType() {
      let person = Person(name: "Alice", age: 30)
      let result = try? encoder.encode(person)
      #expect(result == .object(["name": .string("Alice"), "age": .integer(30)]))
    }
  }

  struct OptionalValues {
    let encoder = JSONValueEncoder()

    @Test
    func testEncodeOptionalValue() {
      let value: Int? = 42
      let result = try? encoder.encode(value)
      #expect(result == .integer(42))
    }

    @Test
    func testEncodeNilOptionalValue() {
      let value: Int? = nil
      let result = try? encoder.encode(value)
      #expect(result == .null)
      #expect(result != .integer(0))
    }
  }

  struct ErrorHandling {
    let encoder = JSONValueEncoder()

    @Test
    func testEncodeUnsupportedType() {
      struct UnsupportedType: Encodable {
        let unsupportedValue: Never?
      }

      let result = try? encoder.encode(UnsupportedType(unsupportedValue: nil))
      #expect(result == .object([:]))
    }
  }

  struct EdgeCases {
    let encoder = JSONValueEncoder()

    @Test
    func encodeEmptyStruct() {
      struct EmptyStruct: Codable {}

      let result = try? encoder.encode(EmptyStruct())
      #expect(result == .object([:]))
    }

    @Test
    func encodeStructWithNilOptional() {
      struct OptionalWrapper: Codable {
        let value: JSONValue
      }

      let result = try? encoder.encode(OptionalWrapper(value: .null))
      #expect(result == .object(["value": .null]))
    }

    @Test
    func encodeDeeplyNestedStructures() {
      let value = [[["deep": ["nested": ["structure": 1]]]]]
      let result = try? encoder.encode(value)
      #expect(result == .array([.array([.object(["deep": .object(["nested": .object(["structure": .integer(1)])])])])]))
    }
  }
}
