import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct DocumentationExampleTests {
  @Test func readMeBuilder() {
    @JSONSchemaBuilder var jsonSchema: some JSONSchemaComponent {
      JSONObject {
        JSONProperty(key: "firstName") {
          JSONString()
            .description("The person's first name.")
        }
        .required()

        JSONProperty(key: "lastName") {
          JSONString()
            .description("The person's last name.")
        }

        JSONProperty(key: "age") {
          JSONInteger()
            .description("Age in years which must be equal to or greater than zero.")
            .minimum(0)
            .maximum(120)
        }
        .required()
      }
      .title("Person")
    }

    let expected: [String: JSONValue] = [
      "title": "Person",
      "type": "object",
      "required": ["firstName", "age"],
      "properties": [
        "firstName": ["type": "string", "description": "The person's first name."],
        "lastName": ["type": "string", "description": "The person's last name."],
        "age": [
          "type": "integer",
          "description": "Age in years which must be equal to or greater than zero.",
          "minimum": 0.0, "maximum": 120.0,
        ],
      ],
    ]

    #expect(jsonSchema.schemaValue == .object(expected))
  }

  @Schemable
  @ObjectOptions(.additionalProperties { false })
  struct Person {
    let firstName: String

    let lastName: String?

    @NumberOptions(.minimum(0), .maximum(120))
    let age: Int

    /// A short bio or summary about the person, shown on their public profile.
    @StringOptions(.maxLength(500))
    let bio: String?
  }

  @Test func readMeMacros() {
    #expect(
      Person.schema.schemaValue["properties"]?.object?["age"]?.object?.keys.count == 3
    )
  }

  @Test func doccExample1() {
    let shouldIncludeAge = true

    @JSONSchemaBuilder var schemaRepresentation: some JSONSchemaComponent<Int?> {
      JSONObject {
        if shouldIncludeAge {
          JSONProperty(key: "age") {
            JSONInteger()
              .description("Age in years which must be equal to or greater than zero.")
              .minimum(0)
          }
          .required()
        }
      }
      .title("Person")
    }

    #expect(schemaRepresentation.parse(.object(["age": .integer(20)])) == .valid(20))
  }

  @Schemable struct Book {
    let title: String
    let authors: [String]
    let yearPublished: Int
    let rating: Double
  }

  @Schemable struct Library {
    let name: String
    var books: [Book] = []
  }

  @Test func doccExample2() {
    #expect(Book.schema != nil)
    #expect(Library.schema != nil)
  }

  @Schemable enum TemperatureType {
    case fahrenheit
    case celsius
  }

  @Schemable struct Weather {
    var temperature: Double = 72.0
    var units: TemperatureType = .fahrenheit
    var location: String = "Detroit"
  }

  @Schemable struct Weather2 {
    let temperature: Double
    let units: TemperatureType
    let location: String

    @ExcludeFromSchema let secret: String

    init(temperature: Double, units: TemperatureType, location: String) {
      self.temperature = temperature
      self.units = units
      self.location = location
      self.secret = "secret"
    }
  }

  @Test func doccExample3() {
    #expect(
      Weather2.schema.schemaValue["properties"]?.object?["secret"] == nil
    )
  }

  @Schemable enum Status {
    case active
    case inactive
  }

  @Test func readMeEnumMacro() {
    let expected: [String: JSONValue] = ["type": "string", "enum": ["active", "inactive"]]
    #expect(Status.schema.schemaValue == .object(expected))
  }

  @Schemable
  struct Child: Equatable {
    let one: String
    let two: String
  }

  @Schemable
  struct Parent: Equatable {
    let children: [String: Child]
  }

  @Test func dictionaryWithCustomTypeCompilation() {
    // This test verifies that the generated code compiles and works correctly
    let child1 = Child(one: "value1", two: "value2")
    let child2 = Child(one: "value3", two: "value4")
    let parent = Parent(children: ["child1": child1, "child2": child2])

    // Verify schema generation
    let schema = Parent.schema
    #expect(schema.schemaValue["type"]?.string == "object")
    #expect(schema.schemaValue["properties"]?.object?["children"] != nil)

    // Verify the schema has the correct structure for dictionary with additionalProperties
    let childrenProperty = schema.schemaValue["properties"]?.object?["children"]?.object
    #expect(childrenProperty?["type"]?.string == "object")
    #expect(childrenProperty?["additionalProperties"] != nil)

    // Test parsing
    let jsonInput: JSONValue = [
      "children": [
        "child1": [
          "one": "value1",
          "two": "value2",
        ],
        "child2": [
          "one": "value3",
          "two": "value4",
        ],
      ]
    ]

    let parseResult = schema.parse(jsonInput)
    switch parseResult {
    case .valid(let parsedParent):
      #expect(parsedParent.children.count == 2)
      #expect(parsedParent.children["child1"]?.one == "value1")
      #expect(parsedParent.children["child1"]?.two == "value2")
      #expect(parsedParent.children["child2"]?.one == "value3")
      #expect(parsedParent.children["child2"]?.two == "value4")

      #expect(parsedParent == parent)
    case .invalid(let errors):
      Issue.record("Parsing failed with errors: \(errors)")
    }
  }
}
