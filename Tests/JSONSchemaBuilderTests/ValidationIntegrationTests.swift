import JSONSchema
import JSONSchemaBuilder
import Testing

struct ValidationIntegrationTests {
  @Test func number() {
    let numberSchema = JSONNumber()

    #expect(numberSchema.validate(100.0) == .valid(100.0))
    #expect(numberSchema.validate("Some string") == .invalid([.typeMismatch(expected: .number, actual: "Some string")]))
  }

  @Test func object() {
    let objectSchema = JSONObject {
      JSONProperty(key: "id") {
        JSONInteger()
          .minimum(1)
          .description("A unique identifier for the object")
      }
      .required()

      JSONProperty(key: "name") {
        JSONString()
          .minLength(1)
          .maxLength(100)
          .pattern("^[a-zA-Z0-9_ ]+$")
          .description("The name of the object.")
      }

      JSONProperty(key: "price") {
        JSONNumber()
          .minimum(0)
          .description("The price of the object, must be a positive number.")
      }
      .required()

      JSONProperty(key: "attributes") {
        JSONObject {
          JSONProperty(key: "color") {
            JSONString()
          }
          .required()

          JSONProperty(key: "size") {
            JSONString()
          }
          .required()
        }
        .additionalProperties(.disabled)
      }
      .required()

      JSONProperty(key: "isAvailable") {
        JSONBoolean()
      }
    }

    let instance: JSONValue = .object([
      "name": "mississippi**",
      "attributes": [:]
    ])

    #expect(objectSchema.validate(instance).invalid == [])
  }
}
