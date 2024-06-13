import OpenAITools
import JSONSchema
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
          "temp": .number(
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
