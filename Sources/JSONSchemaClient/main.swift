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
  let yearPublished: Int
  @ExcludeFromSchema let rating: Double

  init(title: String, authors: [String], yearPublished: Int) {
    self.title = title
    self.authors = authors
    self.yearPublished = yearPublished
    self.rating = 1
  }
}

@Schemable struct Library {
  let name: String
  var books: [Book] = []
}

printSchema(Book.self)
printSchema(Library.self)

// MARK: - Enums

@Schemable enum TemperatureType: Codable {
  case fahrenheit
  case celcius
}

let tempType = TemperatureType.schema.validate(.string("fahrenheit"))
print("tempType", tempType)

printSchema(TemperatureType.self)

enum WeatherCondition: Codable { case sunny(hoursOfSunlight: Int)
  case hail(Bool)
  case cloudy(coverage: Double)
  case rainy(chanceOfRain: Double, amount: Double)
  case snowy
  case windy
  case stormy
}

extension WeatherCondition: Schemable {
  static var schema: some JSONSchemaComponent<WeatherCondition> {
    JSONComposition.AnyOf(into: WeatherCondition.self) {
      JSONObject {
        JSONProperty(key: "cloudy") {
          JSONObject { JSONProperty(key: "coverage") { JSONNumber() }.required() }
        }
        .required()
      }
      .map { coverage in Self.cloudy(coverage: coverage) }

      JSONObject {
        JSONProperty(key: "rainy") {
          JSONObject {
            JSONProperty(key: "chanceOfRain") { JSONNumber() }.required()
            JSONProperty(key: "amount") { JSONNumber() }.required()
          }
        }
        .required()
      }
      .map { chanceOfRain, amount in Self.rainy(chanceOfRain: chanceOfRain, amount: amount) }

      JSONString()
        .enumValues {
          "snowy"
          "windy"
          "stormy"
        }
        .compactMap { string in
          switch string {
          case "snowy": return WeatherCondition.snowy
          case "windy": return WeatherCondition.windy
          case "stormy": return WeatherCondition.stormy
          default: return nil
          }
        }
    }
  }
}

let weatherConditionResult1 = WeatherCondition.schema.validate(
  .object(["cloudy": .object(["coverage": .number(100)])])
)
print("weatherConditionResult1", weatherConditionResult1)
let weatherConditionResult2 = WeatherCondition.schema.validate(.string("snowy"))
print("weatherConditionResult2", weatherConditionResult2)

let conditions = WeatherCondition.sunny(hoursOfSunlight: 5)
printInstance(conditions)
printSchema(WeatherCondition.self)

@Schemable enum Category { case fiction, nonFiction, science, history, kids, entertainment }

// MARK: Parsing

enum WeatherType {
  case sunny
  case cloudy
  case rainy

  static var schema: some JSONSchemaComponent<WeatherType> {
    JSONString()
      .enumValues {
        "sunny"
        "cloudy"
        "rainy"
      }
      .compactMap { string in
        switch string {
        case "sunny": return .sunny
        case "cloudy": return .cloudy
        case "rainy": return .rainy
        default: return nil
        }
      }
      .title("Weather").description("The current weather conditions").deprecated(false)
  }
}

let sunny = WeatherType.schema.validate(.string("sunny"))
print(sunny)
let notSupported = WeatherType.schema.validate(.string("other"))
print(notSupported)

enum Airline: String, CaseIterable, Schemable {
  case delta
  case united
  case american
  case alaska

  static var schema: some JSONSchemaComponent<Airline> {
    JSONString()
      .compactMap { string in
        switch string {
        case "delta": return Airline.delta
        case "united": return Airline.united
        case "american": return Airline.american
        case "alaska": return Airline.alaska
        default: return nil
        }
      }
  }
}

struct Flight: Sendable {
  let origin: String
  let destination: String?
  let airline: Airline
  let duration: Double
  let metadata: JSONValue?
}

extension Flight: Schemable {
  static var schema: some JSONSchemaComponent<Flight> {
    JSONSchema(Flight.init) {
      JSONObject {
        JSONProperty(key: "origin") { JSONString() }.required()

        JSONProperty(key: "destination") { JSONString() }

        JSONProperty(key: "airline") { Airline.schema }.required()

        JSONProperty(key: "duration") {
          JSONNumber().description("The duration of the flight in seconds").minimum(0)
        }
        .required()

        JSONProperty(key: "metadata")
      }
      .title("Flight").minProperties(2)
      .patternProperties { JSONProperty(key: "regular-expression") { JSONString() } }
    }
  }
}

printSchema(Flight.self)

let flightDataJSON = """
  {
    "origin": "Detroit",
    "airline": "delta",
    "duration": 10800.1
  }
  """
  .data(using: .utf8)!
let flightData = try! JSONDecoder().decode(JSONValue.self, from: flightDataJSON)
print(flightData)

let flight = Flight.schema.validate(flightData)
print(flight)

switch flight {
case .valid(let a): print("Valid: \(a)")
case .invalid(let array): print("Invalid: \(array.joined(separator: "\n"))")
}

let anyOf = JSONComposition.AnyOf(into: JSONValue.self) {
  JSONString()
  JSONNumber().minimum(0)
}
print("anyOf", anyOf.definition)

print("anyOf", anyOf.validate(.string("Hello")))
print("anyOf", anyOf.validate(.number(1)))
print("anyOf", anyOf.validate(.null))

let array = JSONArray { JSONInteger() }

let arrayResult = array.validate(.array([1, 2, 3, 4, 5]))
print(arrayResult)

// Validation article

let identifierSchema = JSONString()
  .pattern("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
  .description("Unique identifier for the product")

let nameSchema = JSONString().minLength(1).description("Name of the product")

let priceSchema = JSONNumber().multipleOf(0.01).description("Price of the product in USD")

let inStockSchema = JSONBoolean().description("Availablility status of the product")

let id = identifierSchema.validate(.string("E621E1F8-C36C-495A-93FC-0C247A3E6E5F"))
let name = nameSchema.validate(.string("iPad"))
let price = priceSchema.validate(.number(199.99))
let inStock = inStockSchema.validate(.boolean(true))

// Compose them together into an object

let itemSchema = JSONObject {
  JSONProperty(key: "id", value: identifierSchema)
  JSONProperty(key: "name", value: nameSchema)
  JSONProperty(key: "price", value: priceSchema)
  JSONProperty(key: "inStock", value: inStockSchema)
}

let itemString = """
  {
    "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
    "name": "iPad",
    "price": 199.99,
    "inStock": true
  }
  """
let itemInstance = try! JSONDecoder().decode(JSONValue.self, from: Data(itemString.utf8))
print(itemInstance)

// Validated<(String?, String?, Double?, Bool?), String>
let itemValidationResult = itemSchema.validate(itemInstance)

switch itemValidationResult {
case .valid(let value):
  if let id = value.0 { print("ID: \(id)") }

  if let name = value.1 { print("Name: \(name)") }

// ..

case .invalid(let array): print("Errors: \(array.joined(separator: ", "))")
}

struct Item {
  let id: String
  let name: String
  let price: Double
  let inStock: Bool
}

let newSchema = JSONObject {
  JSONProperty(key: "id") {
    JSONString()
      .pattern("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
      .description("Unique identifier for the product")
  }
  .required()

  JSONProperty(key: "name") { JSONString().minLength(1).description("Name of the product") }
    .required()

  JSONProperty(key: "price") {
    JSONNumber().multipleOf(0.01).description("Price of the product in USD")
  }
  .required()

  JSONProperty(key: "inStock") { JSONBoolean().description("Availablility status of the product") }
    .required()
}
.map(Item.init)

let item = newSchema.validate(itemInstance)

@Schemable enum TemperatureKind {
  case cloudy(Double)
  case rainy(chanceOfRain: Double, amount: Double?)
  case snowy
  case windy
  case stormy
}

@Schemable enum UserProfileSetting { case username(String)
  case age(Int)
  case preferredLanguages([String])
  case contactInfo([String: String])
}

let contactInfoData: JSONValue = .object([
  "contactInfo": .object(["_0": .object(["austin": "555-555-5555", "dallas": "214-555-5555"])])
])
print("user-profile-settings", UserProfileSetting.schema.validate(contactInfoData))

struct Weathery {
  let metadata: [String: String]

  static var schema: some JSONSchemaComponent<Weathery> {
    JSONSchema(Weathery.init) {
      JSONObject {
        JSONProperty(key: "metadata") {
          JSONObject().propertyNames(.options(pattern: "^[A-Za-z_][A-Za-z0-9_]*$")).minProperties(2)
            .maxProperties(5).additionalProperties { JSONString() }.map { $1 }
        }
        .required()
      }
    }
  }
}

struct WeatherFoo {
  let cityName: String

  static var schema: some JSONSchemaComponent<WeatherFoo> {
    JSONSchema(WeatherFoo.init) {
      JSONObject { JSONProperty(key: "cityName") { JSONString() }.required() }.minProperties(2)
        .maxProperties(5)
    }
  }
}

enum FlightInfo { case flightNumber(_ value: Int = 0)
  case departureDetails(city: String = "Unknown", isInternational: Bool = false)
  case arrivalDetails(city: String = "Unknown")
  case passengerInfo(name: String = "Unknown", seatNumber: String? = nil)

  static var schema: some JSONSchemaComponent<FlightInfo> {
    JSONComposition.AnyOf(into: FlightInfo.self) {
      JSONObject {
        JSONProperty(key: "flightNumber") {
          JSONObject { JSONProperty(key: "_") { JSONInteger().default(0) }.required() }
        }
        .required()
      }
      .map { Self.flightNumber($0) }
      JSONObject {
        JSONProperty(key: "departureDetails") {
          JSONObject {
            JSONProperty(key: "city") { JSONString().default("Unknown") }.required()
            JSONProperty(key: "isInternational") { JSONBoolean().default(false) }.required()
          }
        }
        .required()
      }
      .map { Self.departureDetails(city: $0, isInternational: $1) }
      JSONObject {
        JSONProperty(key: "arrivalDetails") {
          JSONObject { JSONProperty(key: "city") { JSONString().default("Unknown") }.required() }
        }
        .required()
      }
      .map { Self.arrivalDetails(city: $0) }
      JSONObject {
        JSONProperty(key: "passengerInfo") {
          JSONObject {
            JSONProperty(key: "name") { JSONString().default("Unknown") }.required()
            JSONProperty(key: "seatNumber") { JSONString().default(nil) }
          }
        }
        .required()
      }
      .map { Self.passengerInfo(name: $0, seatNumber: $1) }
    }
  }
}

@Schemable struct ItemDetails { let thing: String }

// Oddly, this macro is crashing compiler for Swift 5.10
//@Schemable
enum LibraryItem { case book(details: ItemDetails, category: Category)
  case movie(details: ItemDetails, category: Category, duration: Int)
  case music(details: ItemDetails, category: Category)
}
