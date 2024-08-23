import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct DocumentationExampleTests {
  let personSchema = Schema.object(
    .annotations(title: "Person"),
    .options(
      properties: [
        "firstName": .string(.annotations(description: "The person's first name.")),
        "lastName": .string(.annotations(description: "The person's last name.")),
        "age": .integer(
          .annotations(description: "Age in years which must be equal to or greater than zero."),
          .options(minimum: 0, maximum: 120)
        ),
      ],
      required: ["firstName", "age"]
    )
  )

  @Test func readMeBuilder() {
    @JSONSchemaBuilder var jsonSchema: some JSONSchemaComponent {
      JSONObject {
        JSONProperty(key: "firstName") { JSONString().description("The person's first name.") }
          .required()

        JSONProperty(key: "lastName") { JSONString().description("The person's last name.") }

        JSONProperty(key: "age") {
          JSONInteger().description("Age in years which must be equal to or greater than zero.")
            .minimum(0).maximum(120)
        }
        .required()
      }
      .title("Person")
    }

    let schema: Schema = jsonSchema.definition

    #expect(schema == personSchema)
  }

  @Schemable struct Person {
    let firstName: String
    let lastName: String?
    @NumberOptions(minimum: 0, maximum: 120) let age: Int
  }

  @Test func readMeMacros() {
    #expect(
      Person.schema.definition.options?.asType(ObjectSchemaOptions.self)?.properties?.count == 3
    )
  }

  //  @Schemable
  //  enum Status {
  //    case active
  //    case inactive
  //  }

  @Test func doccExample1() {
    let shouldIncludeAge = true

    @JSONSchemaBuilder var schemaRepresentation: some JSONSchemaComponent<Int?> {
      JSONObject {
        if shouldIncludeAge {
          JSONProperty(key: "age") {
            JSONInteger().description("Age in years which must be equal to or greater than zero.")
              .minimum(0)
          }
          .required()
        }
      }
      .title("Person")
    }

    #expect(schemaRepresentation.validate(.object(["age": .integer(20)])) == .valid(20))
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

  enum TemperatureType {
    case fahrenheit
    case celsius
  }

  @Schemable struct Weather {
    var temperature: Double = 72.0
    // var units: TemperatureType = .fahrenheit
    var location: String = "Detroit"
  }

  @Schemable struct Weather2 {
    let temperature: Double
    // let units: TemperatureType
    let location: String

    @ExcludeFromSchema let secret: String

    init(temperature: Double, location: String) {
      self.temperature = temperature
      self.location = location
      self.secret = "secret"
    }
  }

  @Test func doccExample3() {
    #expect(
      Weather2.schema.definition.options?.asType(ObjectSchemaOptions.self)?.properties?.keys
        .contains("secert") == false
    )
  }
}
