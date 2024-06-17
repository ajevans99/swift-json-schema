import JSONTools
import JSONSchema
import JSONResultBuilders
import Foundation

let a = 17
let b = 25

let (result, code) = #stringify(a + b)

print("The value \(result) was produced by the code \"\(code)\"")

//protocol JSONSchemable {
//  static var schema: String { get }
//}

//@Tool("Get the current weather in a given location")
//func currentWeather(_ query: WeatherQuery) async -> Double {
//
//}

enum Unit: Codable {
  case celcius
  case fahrenheit
}

// @Tool("Get the current weather in a given location")
struct Weather: Codable {
  let temp: Double
  let location: String
  let unit: Unit

  // On expansion of @Tool
  static var toolContext: ToolContext = {
    ToolContext(
      name: "Weather",
      description: "Get the current weather in a given location",
      parameters: schema
    )
  }()

  static let schema: Schema = {
    .object(
      .annotations(
        title: "Weather",
        description: "Get the current weather in a given location"
      ),
      .options(
        properties: [
          "temperature": .number(
            .annotations(description: "The city and state, e.g. San Francisco, CA")
          ),
          "location": .string(
            .annotations(comment: "whisper, whisper")
          ),
          "unit": .string(
            .annotations(description: "The unit of measurement"),
            enumValues: [.string("celcius"), .string("fahrenheit"), .null]
          )
        ],
        additionalProperties: .disabled,
        required: ["temp", "location"]
      )
    )
  }()
}

//// - MARK: Values
//
//protocol JSON {
//  var value: JSONValue { get }
//}
//
//extension String: JSON {
//  var value: JSONValue { .string(self) }
//}
//
//extension Int: JSON {
//  var value: JSONValue { .integer(self) }
//}
//
//struct Object: JSON {
//  var value: JSONValue {
//    return .object(
//      properties.reduce(into: [:]) { partialResult, property in
//        partialResult[property.key] = property.value.value
//      }
//    )
//  }
//
//  var properties: [Property]
//
//  init(@JSONValueBuilder content: () -> Self) {
//    self = content()
//  }
//
//  init(@PropertyBuilder _ content: () -> [Property]) {
//    self.properties = content()
//  }
//}
//
//struct JArray: JSON {
//  var value: JSONValue {
//    .array(elements.map(\.value))
//  }
//
//  var elements: [JSON]
//}
//
//@resultBuilder
//struct PropertyBuilder {
//  static func buildBlock(_ components: Property...) -> [Property] {
//    components
//  }
//}
//
//struct Property {
//  let key: String
//  let value: JSON
//
//  init(key: String, @JSONValueBuilder value: () -> JSON) {
//    self.key = key
//    self.value = value()
//  }
//}
//
//@resultBuilder
//struct JSONValueBuilder {
//  static func buildExpression(_ expression: JSON) -> JSON {
//    expression
//  }
//  
//  static func buildBlock(_ values: JSON...) -> JSON {
//    JArray(elements: values)
//  }
//}
//
//extension JSONValue {
//  init(@JSONValueBuilder content: () -> Self) {
//    self = content()
//  }
//}
//
//let json = Object {
//  Property(key: "Hello") {
//    1
//  }
//  
//  Property(key: "World") {
//    Object {}
//  }
//
//  Property(key: "jarray") {
//    1
//    Object {}
//    "more"
//  }
//}
//
//print("JSON:", json)
//print("JSON Value:", json.value)

//let jsonData = try! JSONEncoder().encode(json)
//print(String(decoding: jsonData, as: UTF8.self))

//// - MARK: Schema
//
//protocol JSONSchema {
//  var schema: Schema { get }
//}
//
//struct JSONString: JSONSchema {
//  var schema: Schema { .string() }
//}
//
//struct JSONNumber: JSONSchema {
//  var schema: Schema { .number() }
//}
//
//// MARK: Object
//
//struct JSONObject: JSONSchema {
//  var schema: Schema { .object() }
//}
//
//protocol JSONObjectSchema {
//  var key: String { get }
//  var value: JSONSchema { get }
//}

//struct Property: JSONObjectSchema {
//  let key: String
//  let value: JSONSchema
//
//  init(_ key: String, @SchemaBuilder value: () -> JSONSchema) {
//    self.key = key
//    self.value = value()
//  }
//
//  var schema: Schema { .object() }
//}

//@resultBuilder
//struct SchemaBuilder {
//  static func buildBlock(_ components: JSONSchema...) -> JSONSchema {
//    JSONObject()
//  }
//
//  static func buildExpression(_ expression: JSONSchema) -> JSONSchema {
//    return expression
//  }
//}

//let test = JSONObject {
//
//}

// NORTH Star
//struct WeatherSchema {
//  var body: JSON {
//    JSONObject {
//      Property("temperature") {
//        JSONNumber()
//          .description("The city and state, e.g. San Francisco, CA")
//
//      }
//      Property("location") {
//        JSONString()
//          .comment("whisper, whisper")
//      }
//
//      Property("unit") {
//        JSONString() // This is a Schema, schema is represented with json
//          .description("The unit of measurement")
//          .enumValues {
//            "celcius" // This is a JSON value, represent with literals
//            "fahrenheit"
//            nil
//          }
//      }
//    }
//    .additionalProperties(.disabled)
//    .title("Weather")
//    .description("Get the current weather in a given location")
//  }
//}

// Result builder syntax
//@JSONBuilder var example: Object {
//  Property("temperature") {
//    Number()
//  }
//}

let data = try! JSONEncoder().encode(Weather.toolContext)
print(String(decoding: data, as: UTF8.self))

//@Tool(
//  "Get the current weather in a given location",
//  argumentDescriptions: [
//    "The city and state, e.g. San Francisco, CA",
//    "The unit of measurement"
//  ]
//)
func currentWeather(location: String, unit: Unit) async -> Double {
  return 0
}

//
struct WeatherQuery {
//  @ToolObject


  //@ToolParameter("The city and state, e.g. San Francisco, CA")
  let location: String
  
//  @ToolParameter
//  let unit: Unit
}

//print(WeatherQuery.schema)

let builder = JSONObjectElement {
  Property(key: "Temperature") {
    nil
  }
  Property(key: "hi") {
    1.0
  }

  Property(key: "nested") {
    [
      "test": JSONIntegerElement(integer: 1),
      "another-test": JSONObjectElement {
        Property(key: "yes?") {
          false
        }
      }
    ]
  }
}

print(builder)
print(builder.value)
