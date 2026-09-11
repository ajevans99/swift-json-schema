import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

struct ConversionTests {
  @Test
  func uuid() throws {
    let result = try Conversions.uuid.schema.parseAndValidate(
      "123e4567-e89b-12d3-a456-426614174000"
    )
    let expected = try #require(UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000"))
    #expect(result == expected)
  }

  struct DocumentationExampleTests {
    @Schemable
    struct Bookmark {
      @SchemaOptions(.customSchema(Conversions.uuid))
      let id: UUID

      @SchemaOptions(.customSchema(Conversions.dateTime))
      let createdAt: Date

      @SchemaOptions(.customSchema(Conversions.url))
      let url: URL
    }

    @Test func parsingFoundationModel() throws {
      let json = """
        {
          "id": "123e4567-e89b-12d3-a456-426614174000",
          "createdAt": "2023-05-01T12:34:56.789Z",
          "url": "https://example.com"
        }
        """
      let bookmark = try Bookmark.schema.parseAndValidate(instance: json)
      let context = Context(
        dialect: .draft2020_12,
        formatValidators: DefaultFormatValidators.all
      )
      let validatedBookmark = try Bookmark.schema.parseAndValidate(
        instance: json,
        validationContext: context
      )

      for value in [bookmark, validatedBookmark] {
        #expect(value.id == UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000"))
        #expect(value.createdAt == Date(timeIntervalSince1970: 1682944496.789))
        #expect(value.url.absoluteString == "https://example.com")
      }
    }

    @Test func conversionParsingIsSeparateFromFormatValidation() {
      let value: JSONValue = .string("not-a-uuid")
      #expect(Conversions.uuid.schema.definition().validate(value).isValid)
      #expect(throws: ParseAndValidateIssue.self) {
        try Conversions.uuid.schema.parseAndValidate(value)
      }
    }
  }

  @Test
  func dateTime() throws {
    let result = try Conversions.dateTime.schema.parseAndValidate(
      "2023-05-01T12:34:56.789Z"
    )
    #expect(result == Date(timeIntervalSince1970: 1682944496.789))
  }

  @Test
  func date() throws {
    let result = try Conversions.date.schema.parseAndValidate(
      "2023-05-01"
    )
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    let expected = try #require(formatter.date(from: "2023-05-01"))
    #expect(result == expected)
  }

  @Test
  func time() throws {
    let result = try Conversions.time.schema.parseAndValidate(
      "12:34:56.789Z"
    )
    #expect(result.day == nil)
    #expect(result.hour == 12)
    #expect(result.minute == 34)
    #expect(result.second == 56)
    #expect(result.nanosecond != nil)
    #expect(result.timeZone?.secondsFromGMT() == 0)
  }

  @Test
  func url() throws {
    let result = try Conversions.url.schema.parseAndValidate(
      "https://example.com"
    )
    #expect(result == URL(string: "https://example.com"))
  }
}
