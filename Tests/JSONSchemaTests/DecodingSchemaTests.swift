@testable import JSONSchema

import Foundation
import Testing

struct DecodingSchemaTests {
  static let typeMapper = { (type: JSONType) in
    """
    {
      "type" : "\(type.rawValue)"
    }
    """
  }
  @Test(arguments: arguments(stringBuilder: typeMapper))
  func type(json: String, type: JSONType) throws {
    let schema = try Schema(json: json)
    #expect(schema.type == type)
  }

  static let titleMapper = { (type: JSONType) in
    """
    {
      "title": "Hello",
      "type" : "\(type.rawValue)"
    }
    """
  }
  @Test(.tags(.annotations), arguments: arguments(stringBuilder: titleMapper))
  func title(json: String, type: JSONType) throws {
    let schema = try Schema(json: json)
    #expect(schema.annotations.title == "Hello")
  }

  static let annotationsMapper = { (type: JSONType) in
    """
    {
      "$comment" : "Comment",
      "default" : "1",
      "deprecated" : false,
      "description" : "This is the description",
      "examples" : [
        "1",
        null,
        false,
        [
          1,
          2,
          3
        ],
        {
          "hello" : "world"
        }
      ],
      "readOnly" : true,
      "title" : "Title",
      "type" : "\(type.rawValue)",
      "writeOnly" : false
    }
    """
  }
  @Test(.tags(.annotations), arguments: arguments(stringBuilder: annotationsMapper))
  func allAnnotations(json: String, type: JSONType) throws {
    let schema = try Schema(json: json)

    #expect(
      schema.annotations == AnnotationOptions(
        title: "Title",
        description: "This is the description",
        default: "1",
        examples: ["1", nil, false, [1, 2, 3], ["hello": "world"]],
        readOnly: true,
        writeOnly: false,
        deprecated: false,
        comment: "Comment"
      )
    )
  }

  @Test(.tags(.typeOptions))
  func stringOptions() throws {
    let json = """
      {
        "format" : "uuid",
        "maxLength" : 36,
        "minLength" : 12,
        "pattern" : "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
        "type" : "string"
      }
      """
    
    let schema = try Schema(json: json)
    let options: StringSchemaOptions = try #require(schema.options?.asType())
    #expect(
      options == StringSchemaOptions(
        minLength: 12,
        maxLength: 36,
        pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
        format: "uuid"
      )
    )
  }

  @Test(.tags(.typeOptions))
  func numberOptions() throws {
    let json1 = """
      {
        "exclusiveMaximum" : 100,
        "minimum" : 1,
        "multipleOf" : 2,
        "type" : "number"
      }
      """
    let schema1 = try Schema(json: json1)
    let options1: NumberSchemaOptions = try #require(schema1.options?.asType())
    #expect(
      options1 == NumberSchemaOptions(
        multipleOf: 2,
        minimum: 1, // expressible by integer literal - inclusive
        maximum: .exclusive(100)
      )
    )

    let json2 = """
      {
        "exclusiveMinimum" : 0.99,
        "maximum" : 5000,
        "multipleOf" : 1,
        "type" : "number"
      }
      """
    let schema2 = try Schema(json: json2)
    let options2: NumberSchemaOptions = try #require(schema2.options?.asType())
    #expect(
      options2 == NumberSchemaOptions(
        multipleOf: 1,
        minimum: .exclusive(0.99),
        maximum: .inclusive(5000)
      )
    )
  }

  @Test(.tags(.typeOptions))
  func arrayOptions() throws {
    let json = """
      {
        "contains" : {
          "type" : "number"
        },
        "items" : {
          "type" : "number"
        },
        "maxContains" : 25,
        "maxItems" : 50,
        "minContains" : 1,
        "minItems" : 1,
        "prefixItems" : [
          {
            "type" : "number"
          },
          {
            "type" : "string"
          },
          {
            "type" : "object"
          },
          {
            "type" : "object"
          }
        ],
        "type" : "array",
        "unevaluatedItems" : false,
        "uniqueItems" : true
      }
      """

    let schema = try Schema(json: json)
    let options: ArraySchemaOptions = try #require(schema.options?.asType())

    #expect(
      options == ArraySchemaOptions(
        items: .schema(.number()),
        prefixItems: [
          .number(),
          .string(),
          .object(),
          .object(),
        ],
        unevaluatedItems: .disabled,
        contains: .number(),
        minContains: 1,
        maxContains: 25,
        minItems: 1,
        maxItems: 50,
        uniqueItems: true
      )
    )
  }

  @Test(.tags(.typeOptions))
  func objectOptions() throws {
    let json = """
      {
        "additionalProperties" : {
          "type" : "array"
        },
        "maxProperties" : 10,
        "minProperties" : 1,
        "patternProperties" : {
          "^property[0-1]$" : {
            "type" : "string"
          }
        },
        "properties" : {
          "property0" : {
            "type" : "string"
          },
          "property1" : {
            "type" : "string"
          },
          "property2" : {
            "type" : "boolean"
          },
          "property3" : {
            "type" : "number"
          }
        },
        "propertyNames" : {
          "pattern" : "^property[0-9]$"
        },
        "required" : [
          "property1",
          "property3"
        ],
        "type" : "object",
        "unevaluatedProperties" : false
      }
      """

    let schema = try Schema(json: json)
    let options: ObjectSchemaOptions = try #require(schema.options?.asType())

    #expect(
      options == ObjectSchemaOptions(
        properties: [
          "property0": .string(),
          "property1": .string(),
          "property2": .boolean(),
          "property3": .number(),
        ],
        patternProperties: [
          #"^property[0-1]$"#: .string()
        ],
        additionalProperties: .schema(.array()),
        unevaluatedProperties: .disabled,
        required: ["property1", "property3"],
        propertyNames: .options(pattern: #"^property[0-9]$"#),
        minProperties: 1,
        maxProperties: 10
      )
    )
  }

  static let enumMapper = { (type: JSONType) in
    """
    {
      "enum" : [
        "Hello",
        "World",
        1.2
      ],
      "type" : "\(type.rawValue)"
    }
    """
  }
  @Test(arguments: arguments(stringBuilder: enumMapper))
  func enumValue(json: String, type: JSONType) throws {
    let schema = try Schema(json: json)
    #expect(schema.enumValues == ["Hello", "World", 1.2])
  }

  @Test
  func empty() throws {
    let json = """
      {}
      """
    let schema = try Schema(json: json)
    #expect(schema.type == nil)
    #expect(schema.enumValues == nil)
    #expect(schema.options == nil)
  }

  @Test
  func noType() throws {
    let json = """
      {
        "enum" : [
          "Hello",
          1,
          null,
          4.5
        ]
      }
      """
    let schema = try Schema(json: json)
    #expect(schema.type == nil)
    #expect(schema.enumValues == ["Hello", 1, nil, 4.5])
  }

  @Test
  func invalidValue() {
    let json = """
    {
      "default" : 1.0.1
    }
    """
    #expect {
      try Schema(json: json)
    } throws: { error in
      guard let decodingError = error as? DecodingError else {
        return false
      }

      switch decodingError {
      case .dataCorrupted(let context):
        #expect(context.debugDescription == "Unrecognized JSON value")
        return true
      default:
        return false
      }
    }
  }
}

extension DecodingSchemaTests {
  static let jsonTypes = [JSONType.string, .integer, .number, .object, .array, .boolean, .null]

  static func arguments(stringBuilder: (JSONType) -> String) -> [(String, JSONType)] {
    jsonTypes.map { (stringBuilder($0), $0) }
  }
}

extension Schema {
  init(json: String) throws {
    let decoder = JSONDecoder()
    let data = json.data(using: .utf8)!
    self = try decoder.decode(Schema.self, from: data)
  }
}
