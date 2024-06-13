import OpenAITools
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

enum Unit {
  case celcius
  case fahrenheit
}

// @Tool("Get the current weather in a given location")
struct Weather: Codable {
  let temp: Double
  let location: String

  // On expansion of @Tool
  static var toolContext: ToolContext = {
    ToolContext(
      name: "Weather",
      description: "Get the current weather in a given location",
      parameters: OldJSONSchema(
        type: .object,
        properties: [
          "temp": .init(
            type: .number
          ),
          "location": .init(
            type: .string
          )
        ]
      )
    )
  }()

  static let version2 = {
    Schema<Weather>.object()
  }
}

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
