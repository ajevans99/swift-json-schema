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
  let schemaData = try? encoder.encode(T.schema.schemaValue)
  if let schemaData {
    print("\(T.self) Schema")
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


//
//// Option 2
//
//func getSchema2() -> MyAnyComponent {
//  if 1 + 1 == 2 {
//    return JSONObject().title("bar").eraseToMyAnyComponent()
//  }
//
//  return JSONObject().title("foo").eraseToMyAnyComponent()
//}
//
//let obj2 = JSONObject {
//  JSONProperty(key: "baz") {
//    getSchema2()
//  }
//}
//
//dump(obj2.definition(), name: "obj2")
//
//struct AnyComponent: JSONSchemaComponent {
//  typealias Output = Void
//
//  var schemaValue: [KeywordIdentifier: JSONValue]
//
//  func parse(_ value: JSONValue) -> Parsed<Void, ParseIssue> {
//    fatalError()
//  }
//}
//
//extension JSONSchemaComponent {
//  func eraseToMyAnyComponent() -> MyAnyComponent {
//    .init(schemaValue: self.schemaValue)
//  }
//}
//
//// Option 3
//
//func getSchema3() -> some JSONSchemaComponent {
//  if 1 + 1 == 2 {
//    return JSONObject().title("bar").eraseToAnyValue()
//  }
//
//  return JSONObject {
//    JSONProperty(key: "Hi")
//  }
//  .eraseToAnyValue()
//}
//
//let obj3 = JSONObject {
//  JSONProperty(key: "baz") {
//    getSchema3()
//  }
//}
//
//dump(obj3.definition(), name: "obj3")


import SwiftUI

func myView() -> any View {
  Text("Hello, World!")
}

struct ContentView: View {
  var body: some View {
    VStack {
      AnyView(myView())
    }
    .padding()
  }
}
// Option 1

extension JSONAnyValue {
  public init<Component: JSONSchemaComponent>(_ component: Component) {
    self.init()
    self.schemaValue = component.schemaValue
  }
}


func getSchema() -> any JSONSchemaComponent {
  if 1 + 1 == 2 {
    return JSONObject().title("bar")
  }

  return JSONObject {
    JSONProperty(key: "prop0")
  }
  .title("foo")
}

let obj = JSONObject {
  JSONProperty(key: "baz") {
    JSONAnyValue(getSchema())
  }
}

dump(obj.definition(), name: "obj1")
