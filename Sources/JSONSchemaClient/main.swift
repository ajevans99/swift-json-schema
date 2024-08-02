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

//@Schemable struct Weather {
//  @SchemaOptions(
//    title: "Temperature",
//    description: "The current temperature in fahrenheit, like 70°F",
//    default: 75.0,
//    examples: [72.0, 75.0, 78.0],
//    readOnly: true,
//    writeOnly: false,
//    deprecated: true,
//    comment: "This is a comment about temperature"
//  ) @NumberOptions(multipleOf: 5, minimum: 0, maximum: 100) let temperature: Double
//
//  @SchemaOptions(
//    title: "Humidity",
//    description: "The current humidity percentage",
//    default: 50,
//    examples: [40, 50, 60],
//    readOnly: false,
//    writeOnly: true,
//    deprecated: false,
//    comment: "This is a comment about humidity"
//  ) let humidity: Int
//
//  @SchemaOptions(title: "Temperature Readings")
//  @ArrayOptions(minContains: 1, maxContains: 5, minItems: 2, maxItems: 10, uniqueItems: true)
//  let temperatureReadings: [Double]
//
//  @SchemaOptions(title: "Location")
//  @StringOptions(minLength: 5, maxLength: 100, pattern: "^[a-zA-Z]+$", format: nil) let cityName:
//    String
//}

//let now = Weather(
//  temperature: 72,
//  humidity: 30,
//  temperatureReadings: [32, 70.1, 84],
//  cityName: "Detroit"
//)
//
//extension Weather: Codable {}
//
//printInstance(now)
//printSchema(Weather.self)

//@Schemable struct Book {
//  let title: String
//  let authors: [String]
//  let yearPublished: Int
//  @ExcludeFromSchema let rating: Double
//}
//
//@Schemable struct Library {
//  let name: String
//  var books: [Book] = []
//}

//printSchema(Book.self)
//printSchema(Library.self)

// MARK: - Enums

//@Schemable enum TemperatureType: Codable {
//  case fahrenheit
//  case celcius
//}
//
//printSchema(TemperatureType.self)
//
//@Schemable enum WeatherCondition: Codable { case sunny(hoursOfSunlight: Int)
//  case hail(Bool)
//  case cloudy(coverage: Double)
//  case rainy(chanceOfRain: Double, amount: Double)
//  case snowy
//  case windy
//  case stormy
//}
//
//let conditions = WeatherCondition.sunny(hoursOfSunlight: 5)
//printInstance(conditions)
//printSchema(WeatherCondition.self)
//
//@Schemable enum Category { case fiction, nonFiction, science, history, kids, entertainment }

// MARK: Parsing

enum Airline: String, CaseIterable, Schemable {
  case delta
  case united
  case american
  case alasks

  static var schema: some JSONSchemaComponent<Airline> {
    JSONEnum(cases: Airline.allCases.map { .string($0.rawValue) })
      .compactMap { value in
        if case .string(let value) = value {
          return Airline(rawValue: value)
        }
        return nil
      }
  }
}


struct Flight: Sendable {
  let origin: String
  let destination: String?
  let airline: Airline
  let duration: Double
}

let test = JSONProperty(key: "test") {
  JSONString()
}

let ab = test.validate(["test": nil])
print("ab", ab)
print(type(of: ab))

extension Flight: Schemable {
  static var schema: some JSONSchemaComponent<Flight> {
    JSONSchema(Flight.init) {
      JSONObject {
        JSONProperty(key: "origin") {
          JSONString()
        }
        .required()

        JSONProperty(key: "destination") {
          JSONString()
        }

        JSONProperty(key: "airline") {
          Airline.schema
        }
        .required()

        JSONProperty(key: "duration") {
          JSONNumber()
            .description("The duration of the flight in seconds")
            .minimum(0)
        }
        .required()
      }
      .title("Flight")
      .minProperties(2)
      .patternProperties {
        JSONProperty(key: "regular-expression") {
          JSONString()
        }
      }
    }
  }
}

let obj = JSONObject {
  JSONProperty(key: "origin") {
    JSONString()
  }
  JSONProperty(key: "destination") {
    JSONString()
  }
  JSONProperty(key: "duration") {
    JSONNumber()
      .description("The duration of the flight in seconds")
  }
}
//.patternProperties {
//  JSONProperty(key: "Test") {
//    JSONString()
//  }
//}

let obj_test = obj.validate(.string("hi"))

//let flightSchema = Flight.schema.definition
printSchema(Flight.self)
//let flightData: JSONValue = .object(["origin": "Detroit", "destination": "Cancun", "duration": .number(10_800)])

//let example = [true, false].map { value in
//  return value
//}

let flightDataJSON = """
{
  "origin": "Detroit",
  "airline": "delta",
  "duration": 10800.1
}
""".data(using: .utf8)!
let flightData = try! JSONDecoder().decode(JSONValue.self, from: flightDataJSON)
print(flightData)

let flight = Flight.schema.validate(flightData)
print(flight)

switch flight {
case .valid(let a):
  print("Valid: \(a)")
case .invalid(let array):
  print("Invalid: \(array.joined(separator: "\n"))")
}
