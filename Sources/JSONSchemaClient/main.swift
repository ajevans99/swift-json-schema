import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion

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
  @NumberOptions(.multipleOf(0.5))
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

let schemaData = try! encoder.encode(nameBuilder.definition())
let string = String(data: schemaData, encoding: .utf8)!
print(string)

let instance1: JSONValue = ["name": "Alice"]
let instance2: JSONValue = ["name": ""]

let result1 = schema.validate(instance1)
dump(result1, name: "Instance 1 Validation Result")
let result2 = schema.validate(instance2)
dump(result2, name: "Instance 2 Validation Result")

@Schemable
@ObjectOptions(.additionalProperties { false })
public struct Weather {
  let temperature: Double
}

@Schemable
@ObjectOptions(
  .additionalProperties {
    JSONString()
      .pattern("^[a-zA-Z]+$")
  }
)
public struct Weather20 {
  let temperature: Double
}

struct IPAddress: Schemable {
  static var schema: some JSONSchemaComponent<String> {
    JSONString()
      .format("ipv4")
  }
}

@Schemable
struct User {
  @SchemaOptions(.customSchema(Conversions.uuid))
  let id: UUID

  @SchemaOptions(.customSchema(Conversions.dateTime))
  let createdAt: Date

  @SchemaOptions(.customSchema(Conversions.url))
  let website: URL

  @SchemaOptions(.customSchema(IPAddress.self))
  let ipAddress: String
}

let json = """
  {"id":"123e4567-e89b-12d3-a456-426614174000","createdAt":"2025-06-27T12:34:56.789Z","website":"https://example.com","ipAddress":".168.0.1"}
  """
do {
  let result = try User.schema.parseAndValidate(
    instance: json,
    validationContext: .init(dialect: .draft2020_12, formatValidators: DefaultFormatValidators.all)
  )
  dump(result)
} catch {
  dump(error)
}
