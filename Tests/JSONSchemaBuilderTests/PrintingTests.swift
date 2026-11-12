import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct PrintingTests {
  @Test func primitives() throws {
    #expect(JSONString().print("hello") == .string("hello"))
    #expect(JSONInteger().print(42) == .integer(42))
    #expect(JSONBoolean().print(true) == .boolean(true))
    #expect(JSONNull().print(()) == .null)
    #expect(try JSONNumber().print(1.25) == .number(1.25))
  }

  @Test func numericBoundariesRoundTrip() throws {
    for value in [Int.min, Int.max] {
      #expect(try JSONInteger().parseAndValidate(JSONInteger().print(value)) == value)
    }
    for value in [Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude, -0.0] {
      let restored = try JSONNumber().parseAndValidate(JSONNumber().print(value))
      #expect(restored == value)
      #expect(restored.sign == value.sign)
    }
  }

  @Test func nestedObjectsAndArraysRoundTrip() throws {
    let schema = JSONObject {
      JSONProperty(key: "children") {
        JSONArray {
          JSONObject { JSONProperty(key: "name") { JSONString() } }
        }
      }
    }
    let value: [String?]? = ["one", nil, "two"]
    #expect(try schema.parseAndValidate(schema.printAndValidate(value)) == value)
  }

  @Test func emptyStringKeyIsPreserved() throws {
    let schema = JSONObject { JSONProperty(key: "") { JSONString() } }
    let value = try schema.printAndValidate("value")
    #expect(value == .object(["": .string("value")]))
    #expect(try schema.parseAndValidate(value) == "value")
  }

  @Test func nonFiniteNumbersFail() {
    for value in [Double.infinity, -.infinity, .nan] {
      #expect(throws: JSONPrintingError.self) { try JSONNumber().print(value) }
    }
  }

  @Test func arraysRoundTrip() throws {
    let schema = JSONArray { JSONInteger() }
    let value = [1, 2, 3]
    #expect(try schema.parseAndValidate(schema.print(value)) == value)
  }

  @Test func constraintsAreExplicit() throws {
    let schema = JSONInteger().minimum(5)
    #expect(schema.print(2) == .integer(2))
    #expect(throws: JSONPrintingError.self) { try schema.printAndValidate(2) }
    #expect(try schema.printAndValidate(5) == .integer(5))
  }

  @Test func structWithoutCodable() throws {
    struct Person: Equatable {
      let name: String
      let age: Int
      let nickname: String?
    }
    let schema = JSONObject {
      JSONProperty(key: "name") { JSONString() }.required().printing { $0 }
      JSONProperty(key: "age") { JSONInteger().minimum(0) }.required().printing { $0 }
      JSONProperty(key: "nickname") { JSONString() }
    }
    .map(Person.init, unapply: { ($0.name, $0.age, $0.nickname) })
    let person = Person(name: "Austin", age: 30, nickname: nil)
    let value = try schema.printAndValidate(person)
    #expect(value == .object(["name": .string("Austin"), "age": .integer(30)]))
    #expect(try schema.parseAndValidate(value) == person)
    let named = Person(name: "A", age: 1, nickname: "B")
    #expect(try schema.parseAndValidate(schema.printAndValidate(named)) == named)
  }

  @Test func throwingInversePropagates() {
    enum Failure: Error { case cannotRepresent }
    let schema = JSONInteger()
      .map(
        String.init,
        unapply: { value in
          guard let integer = Int(value) else { throw Failure.cannotRepresent }
          return integer
        }
      )
    #expect(throws: Failure.self) { try schema.print("not an integer") }
  }

  @Test func currentMetadataIsValidated() throws {
    var schema = JSONInteger().map(String.init, unapply: { Int($0)! })
    schema.schemaValue["minimum"] = .integer(10)
    #expect(throws: JSONPrintingError.self) { try schema.printAndValidate("9") }
    #expect(try schema.printAndValidate("10") == .integer(10))
  }

  @Test func explicitNullVersusAbsent() throws {
    let nullable = JSONString().orNull(style: .type)
      .printing { value in
        value.map(JSONValue.string) ?? .null
      }
    let schema = JSONObject { JSONProperty(key: "value", value: nullable) }
    #expect(try schema.print(nil) == .object([:]))
    #expect(try schema.print(.some(nil)) == .object(["value": .null]))
    #expect(try schema.print(.some(.some("x"))) == .object(["value": .string("x")]))
  }

  @Test func duplicateMembersFailRatherThanSilentlyOverwrite() {
    let schema = JSONObject {
      JSONProperty(key: "same") { JSONString() }
      JSONProperty(key: "same") { JSONString() }
    }
    #expect(throws: JSONPrintingError.self) { try schema.print(("a", "b")) }
  }

  @Test func emptyObject() throws {
    #expect(try JSONObject().printAndValidate(()) == .object([:]))
  }

  @Schemable
  struct GeneratedPerson {
    let name: String
  }

  @Test func explicitProjectionForGeneratedSchema() throws {
    let schema = GeneratedPerson.schema.printing { person in
      .object(["name": .string(person.name)])
    }
    let value = try schema.printAndValidate(GeneratedPerson(name: "Austin"))
    #expect(try schema.parseAndValidate(value).name == "Austin")
  }
}
