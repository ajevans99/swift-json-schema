import Foundation
import JSONSchema
import JSONSchemaBuilder

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted

func printInstance<T: Codable>(_ instance: T) {
  let instanceData = try? encoder.encode(instance)
  if let instanceData {
    print("\(T.self) Instance")
    print(String(decoding: instanceData, as: UTF8.self))
  }
}

func printSchema<C: JSONSchemaComponent>(_ schema: C) {
  let schemaData = try? encoder.encode(schema.schemaValue)
  if let schemaData {
    print("\(C.self) Schema")
    print(String(decoding: schemaData, as: UTF8.self))
  }
}

// MARK: Parsing

@Schemable
enum WeatherType {
  case sunny
  case cloudy
  case rainy
}

@Schemable
enum Airline: String, CaseIterable {
  case delta
  case united
  case american
  case alaska
}

@Schemable
struct Flight: Sendable {
  let origin: String
  let destination: String?
  let airline: Airline
  @NumberOptions(multipleOf: 0.5)
  let duration: Double
}

let data: JSONValue = [
  "origin": "DTW",
  "destination": "SFO",
  "airline": "delta",
  "duration": 4.3,
]
let flight = Flight.schema.parse(data)
dump(flight, name: "Flight")
let flightSchema = Flight.schema.definition()
let validationResult = flightSchema.validate(data)
dump(validationResult, name: "Flight Validation Result")

let nameBuilder = JSONObject {
  JSONProperty(key: "name") {
    JSONString()
      .minLength(1)
  }
}
let schema = nameBuilder.definition()

let instance1: JSONValue = ["name": "Alice"]
let instance2: JSONValue = ["name": ""]

let result1 = schema.validate(instance1)
dump(result1, name: "Instance 1 Validation Result")
let result2 = schema.validate(instance2)
dump(result2, name: "Instance 2 Validation Result")

@Schemable
public struct Weather {
  let temperature: Double
}

//{
//  "properties" : {
//    "field1" : {
//      "patternProperties" : {
//        "^(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}$" : {
//          "items" : {
//            "pattern" : "^[^\\\/]+$",
//            "type" : "string"
//          },
//          "type" : "array"
//        }
//      },
//      "type" : "object",
//      "unevaluatedProperties" : false
//    }
//  }
//}

let abc = JSONArray {
  JSONString().pattern(#"^[^\\\/]+$"#)
}

let patternSchema = JSONObject {
  JSONProperty(key: "field1") {
    JSONObject()
      .patternProperties {
        JSONProperty(key: "^(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}$") {
          abc
        }
      }
  }
  .required()
}
.eraseToAnyComponent()

let patternSchemaExampleInput = """
  {
    "field1": {
      "example.com": [
        "homepage",
        "about-us",
        "about/us"
      ],
      "foo.bar-baz.co.uk": [
        "index",
        "contact123"
      ]
    }
  }
  """

printSchema(patternSchema)
let patternSchemaExampleInstance = try! patternSchema.parse(instance: patternSchemaExampleInput)
dump(patternSchemaExampleInstance.value)

let patternSchemaExampleInstance1 = try? patternSchema.parseAndValidate(instance: patternSchemaExampleInput)
dump(patternSchemaExampleInstance1)
let zc = """
  [
        "homepage",
        "about-us",
        "about/us"
      ]
  """
print(abc.definition().validate(["about/us"]))
