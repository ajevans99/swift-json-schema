import Foundation
import JSONSchema
import JSONSchemaBuilder

@Schemable
struct Weather {
  let temperature: Double
  let location: String

  // Exprimental
  let temperatures: [Double]
  let temperatureByLocation: [String: Double]
}

let now = Weather(
  temperature: 72,
  location: "Detroit",
  temperatures: [32, 70.1, 84],
  temperatureByLocation: [
    "Seattle": 64.5,
    "New York": 75
  ]
)

let test = JSONObject {
  JSONProperty(key: "temperature") {
    JSONNumber()
  }

  JSONProperty(key: "location") {
    JSONString()
  }

  JSONProperty(key: "temperatures") {
    JSONArray()
      .items {
        JSONNumber()
      }
  }

  JSONProperty(key: "temperatureByLocation") {
    JSONObject()
      .additionalProperties {
        JSONNumber()
      }
  }
}

extension Weather: Codable {}

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
  let schemaData = try? encoder.encode(T.schema.schema)
  if let schemaData {
    print("\(T.self) Schema")
    print(String(decoding: schemaData, as: UTF8.self))
  }
}

printInstance(now)
printSchema(Weather.self)

@Schemable
struct Book {
  let title: String
  let author: String
  let yearPublished: Int
  let library: Library
}

@Schemable
struct Library {
  let name: String
  var books: [Book] = []
}

printSchema(Book.self)
printSchema(Library.self)

//import SwiftData
//
//@available(macOS 14, *)
//@Model
//final class Animal {
//  var name: String
//  var diet: Diet
//  var category: AnimalCategory?
//
//  init(name: String, diet: Diet) {
//    self.name = name
//    self.diet = diet
//  }
//}
//
//@available(macOS 14, *)
//extension Animal {
//  enum Diet: String, CaseIterable, Codable {
//    case herbivorous = "Herbivore"
//    case carnivorous = "Carnivore"
//    case omnivorous = "Omnivore"
//  }
//}
//
//@available(macOS 14, *)
//@Model
//final class AnimalCategory {
//  @Attribute(.unique) var name: String
//  // `.cascade` tells SwiftData to delete all animals contained in the
//  // category when deleting it.
//  @Relationship(deleteRule: .cascade, inverse: \Animal.category)
//  var animals = [Animal]()
//
//  init(name: String) {
//    self.name = name
//  }
//}
