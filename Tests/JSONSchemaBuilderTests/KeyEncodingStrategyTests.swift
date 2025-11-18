import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
struct SnakeCaseOverride {
  let displayName: String
  let postalCode: Int
}

extension SnakeCaseOverride {
  static var keyEncodingStrategy: KeyEncodingStrategies { .snakeCase }
}

struct KeyEncodingStrategyTests {
  @Test func identityStrategy() {
    let strategy = KeyEncodingStrategies.identity
    #expect(strategy.encode("helloWorld") == "helloWorld")
    #expect(strategy.encode("JSONSchema") == "JSONSchema")
    #expect(strategy.encode("userID") == "userID")
  }

  @Test func snakeCaseStrategy() {
    let strategy = KeyEncodingStrategies.snakeCase
    #expect(strategy.encode("helloWorld") == "hello_world")
    #expect(strategy.encode("userID") == "user_id")
    #expect(strategy.encode("JSONSchema") == "json_schema")
    #expect(strategy.encode("UrlRequest") == "url_request")
  }

  @Test func kebabCaseStrategy() {
    let strategy = KeyEncodingStrategies.kebabCase
    #expect(strategy.encode("helloWorld") == "hello-world")
    #expect(strategy.encode("JSONSchema") == "json-schema")
    #expect(strategy.encode("userID") == "user-id")
    #expect(strategy.encode("URLRequest") == "url-request")
  }

  @Test func customStrategy() {
    struct UppercaseStrategy: KeyEncodingStrategy {
      static func encode(_ key: String) -> String {
        key.uppercased()
      }
    }

    let strategy = KeyEncodingStrategies.custom(UppercaseStrategy.self)
    #expect(strategy.encode("helloWorld") == "HELLOWORLD")
    #expect(strategy.encode("JSONSchema") == "JSONSCHEMA")
    #expect(strategy.encode("userID") == "USERID")
  }

  @Test func schemableRespectsCustomKeyEncodingStrategy() throws {
    guard #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) else { return }

    let strategy = SnakeCaseOverride.keyEncodingStrategy
    #expect(strategy.encode("displayName") == "display_name")
    #expect(strategy.encode("postalCode") == "postal_code")
  }
}
