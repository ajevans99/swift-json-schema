import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONPropertyBuilderTests {
  @Test func single() throws {
    @JSONPropertyBuilder var sample: [JSONPropertyValue] { JSONPropertyValue(key: "prop0") { 0 } }

    let firstProp = try #require(sample.first)
    #expect(firstProp.key == "prop0")
    #expect(firstProp.value.value == .integer(0))
  }

  @Test func multiple() throws {
    @JSONPropertyBuilder var sample: [JSONPropertyValue] {
      JSONPropertyValue(key: "prop0") { 0 }
      JSONPropertyValue(key: "prop1") { 1 }
      JSONPropertyValue(key: "prop2") { 2 }
      JSONPropertyValue(key: "prop3") { 3 }
    }

    try #require(sample.count == 4)
    for (index, sample) in sample.enumerated() {
      #expect(sample.key == "prop\(index)")
      #expect(sample.value.value == .integer(index))
    }
  }

  @Test(arguments: [true, false]) func optional(_ bool: Bool) {
    @JSONPropertyBuilder var sample: [JSONPropertyValue] {
      if bool {
        JSONPropertyValue(key: "prop0", value: JSONStringValue(string: "string"))
        JSONPropertyValue(key: "prop1", value: JSONStringValue(string: "string"))
      }
    }

    #expect(sample.count == (bool ? 2 : 0))
  }

  @Test(arguments: [true, false]) func either(_ bool: Bool) throws {
    @JSONPropertyBuilder var sample: [JSONPropertyValue] {
      if bool {
        JSONPropertyValue(key: "prop0", value: JSONStringValue(string: "string"))
      } else {
        JSONPropertyValue(key: "prop1", value: JSONStringValue(string: "string"))
      }
    }

    let firstProperty = try #require(sample.first)
    #expect(firstProperty.key == (bool ? "prop0" : "prop1"))
  }

  @Test func array() throws {
    @JSONPropertyBuilder var sample: [JSONPropertyValue] {
      for num in 0 ..< 4 {
        JSONPropertyValue(key: "prop\(num)", value: JSONIntegerValue(integer: num))
      }
    }

    try #require(sample.count == 4)
    for (index, sample) in sample.enumerated() {
      #expect(sample.key == "prop\(index)")
      #expect(sample.value.value == .integer(index))
    }
  }
}

struct JSONPropertySchemaTests {
  @Test func single() throws {
    @JSONPropertySchemaBuilder var sample: [JSONProperty] {
      JSONProperty(key: "prop0", value: JSONString())
    }

    let firstProp = try #require(sample.first)
    #expect(firstProp.key == "prop0")
    #expect(firstProp.value.definition == .string())
  }

  @Test func multiple() throws {
    @JSONPropertySchemaBuilder var sample: [JSONProperty] {
      JSONProperty(key: "prop0", value: JSONString())
      JSONProperty(key: "prop1", value: JSONString())
      JSONProperty(key: "prop2", value: JSONString())
      JSONProperty(key: "prop3", value: JSONString())
    }

    try #require(sample.count == 4)
    for (index, sample) in sample.enumerated() {
      #expect(sample.key == "prop\(index)")
      #expect(sample.value.definition == .string())
    }
  }

  @Test(arguments: [true, false]) func optional(_ bool: Bool) {
    @JSONPropertySchemaBuilder var sample: [JSONProperty] {
      if bool {
        JSONProperty(key: "prop0", value: JSONString())
        JSONProperty(key: "prop1", value: JSONString())
      }
    }

    #expect(sample.count == (bool ? 2 : 0))
  }

  @Test(arguments: [true, false]) func either(_ bool: Bool) throws {
    @JSONPropertySchemaBuilder var sample: [JSONProperty] {
      if bool {
        JSONProperty(key: "prop0", value: JSONString())
      } else {
        JSONProperty(key: "prop1", value: JSONString())
      }
    }

    let firstProperty = try #require(sample.first)
    #expect(firstProperty.key == (bool ? "prop0" : "prop1"))
  }

  @Test func array() throws {
    @JSONPropertySchemaBuilder var sample: [JSONProperty] {
      for num in 0 ..< 4 { JSONProperty(key: "prop\(num)", value: JSONInteger()) }
    }

    try #require(sample.count == 4)
    for (index, sample) in sample.enumerated() {
      #expect(sample.key == "prop\(index)")
      #expect(sample.value.definition == .integer())
    }
  }
}
