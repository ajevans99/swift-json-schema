import Foundation
import Testing

@testable import JSONSchema

struct CompositionCodableSchemaTests {
  @Test func allOf() throws {
    let schema = Schema.noType(
      composition: .allOf(
        [
          .string(),
          .noType(.annotations(), StringSchemaOptions.options(maxLength: 5)),
        ]
      )
    )
    let jsonString = """
      {
        "allOf" : [
          {
            "type" : "string"
          },
          {
            "maxLength" : 5
          }
        ]
      }
      """
    let json = try schema.json()
    #expect(json == jsonString) // Encoding
    #expect(try Schema(json: jsonString) == schema) // Decoding
  }

  @Test func anyOf() throws {
    let schema = Schema.noType(
      composition: .anyOf(
        [
          .string(.annotations(), .options(maxLength: 5)),
          .number(.annotations(), .options(minimum: 0)),
        ]
      )
    )
    let jsonString = """
      {
        "anyOf" : [
          {
            "maxLength" : 5,
            "type" : "string"
          },
          {
            "minimum" : 0,
            "type" : "number"
          }
        ]
      }
      """
    let json = try schema.json()
    #expect(json == jsonString) // Encoding
    #expect(try Schema(json: jsonString) == schema) // Decoding
  }

  @Test func oneOf() throws {
    let schema = Schema.noType(
      composition: .oneOf(
        [
          .number(.annotations(), .options(multipleOf: 5)),
          .number(.annotations(), .options(multipleOf: 3)),
        ]
      )
    )
    let jsonString = """
      {
        "oneOf" : [
          {
            "multipleOf" : 5,
            "type" : "number"
          },
          {
            "multipleOf" : 3,
            "type" : "number"
          }
        ]
      }
      """
    let json = try schema.json()
    #expect(json == jsonString) // Encoding
    #expect(try Schema(json: jsonString) == schema) // Decoding
  }

  @Test func factored() throws {
    let schema = Schema.number(
      composition: .oneOf(
        [
          .noType(.annotations(), NumberSchemaOptions.options(multipleOf: 5)),
          .noType(.annotations(), NumberSchemaOptions.options(multipleOf: 3)),
        ]
      )
    )
    let jsonString = """
      {
        "oneOf" : [
          {
            "multipleOf" : 5
          },
          {
            "multipleOf" : 3
          }
        ],
        "type" : "number"
      }
      """
    let json = try schema.json()
    #expect(json == jsonString) // Encoding
    #expect(try Schema(json: jsonString) == schema) // Decoding
  }

  @Test func not() throws {
    let schema = Schema.noType(
      composition: .not(
        .string()
      )
    )
    let jsonString = """
      {
        "not" : {
          "type" : "string"
        }
      }
      """
    let json = try schema.json()
    #expect(json == jsonString) // Encoding
    #expect(try Schema(json: jsonString) == schema) // Decoding
  }
}
