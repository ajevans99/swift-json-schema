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

func printSchema<T: Schemable>(_ schema: T.Type) {
  let schemaData = try? encoder.encode(T.schema.definition)
  if let schemaData {
    print("\(T.self) Schema")
    print(String(decoding: schemaData, as: UTF8.self))
  }
}

@Schemable struct Weather {
  @SchemaOptions(
    title: "Temperature",
    description: "The current temperature in fahrenheit, like 70°F",
    default: 75.0,
    examples: [72.0, 75.0, 78.0],
    readOnly: true,
    writeOnly: false,
    deprecated: true,
    comment: "This is a comment about temperature"
  ) @NumberOptions(multipleOf: 5, minimum: 0, maximum: 100) let temperature: Double

  @SchemaOptions(
    title: "Humidity",
    description: "The current humidity percentage",
    default: 50,
    examples: [40, 50, 60],
    readOnly: false,
    writeOnly: true,
    deprecated: false,
    comment: "This is a comment about humidity"
  ) let humidity: Int

  @SchemaOptions(title: "Temperature Readings")
  @ArrayOptions(minContains: 1, maxContains: 5, minItems: 2, maxItems: 10, uniqueItems: true)
  let temperatureReadings: [Double]

  @SchemaOptions(title: "Location")
  @StringOptions(minLength: 5, maxLength: 100, pattern: "^[a-zA-Z]+$", format: nil) let cityName:
    String
}

//@Schemable
//enum TemperatureType {
//  case farhenheit
//  case celcius
//}

let now = Weather(
  temperature: 72,
  humidity: 30,
  temperatureReadings: [32, 70.1, 84],
  cityName: "Detroit"
)

extension Weather: Codable {}

printInstance(now)
printSchema(Weather.self)

@Schemable struct Book {
  let title: String
  let authors: [String]
  let yearPublished: Int  //  let library: Library
}

@Schemable struct Library {
  let name: String
  var books: [Book] = []
}

printSchema(Book.self)
printSchema(Library.self)
