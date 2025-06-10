import Foundation
import JSONSchemaBuilder
import Testing

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
} 