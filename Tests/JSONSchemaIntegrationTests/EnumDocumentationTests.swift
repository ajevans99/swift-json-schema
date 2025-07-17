import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

@Suite struct EnumDocumentationTests {

  @Schemable
  enum Configuration {
    case database(
      /// The database connection URL
      url: String,
      /// Maximum number of connections in the pool
      maxConnections: Int
    )
    case redis(
      /// Redis server host address
      host: String,
      /// Redis server port number
      port: Int
    )
  }

  @Test
  func enumAssociatedValueDescriptions() throws {
    let schema = Configuration.schema.definition()

    // Get the JSON representation
    let jsonData = try JSONEncoder().encode(schema)
    let jsonValue = try #require(try JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

    // Verify the overall structure is a oneOf
    guard let oneOf = jsonValue["oneOf"] as? [[String: Any]] else {
      #expect(Bool(false), "Schema should have oneOf structure")
      return
    }

    #expect(oneOf.count == 2)

    // Check database case
    guard let databaseCase = oneOf.first,
      let databaseProperties = databaseCase["properties"] as? [String: Any],
      let databaseProperty = databaseProperties["database"] as? [String: Any],
      let databaseInnerProperties = databaseProperty["properties"] as? [String: Any]
    else {
      #expect(Bool(false), "Database case structure should be correct")
      return
    }

    // Check URL parameter has description
    guard let urlProperty = databaseInnerProperties["url"] as? [String: Any],
      let urlDescription = urlProperty["description"] as? String
    else {
      #expect(Bool(false), "URL parameter should have description")
      return
    }
    #expect(urlDescription == "The database connection URL")

    // Check maxConnections parameter has description
    guard let maxConnectionsProperty = databaseInnerProperties["maxConnections"] as? [String: Any],
      let maxConnectionsDescription = maxConnectionsProperty["description"] as? String
    else {
      #expect(Bool(false), "maxConnections parameter should have description")
      return
    }
    #expect(maxConnectionsDescription == "Maximum number of connections in the pool")

    // Check redis case
    guard let redisCase = oneOf.last,
      let redisProperties = redisCase["properties"] as? [String: Any],
      let redisProperty = redisProperties["redis"] as? [String: Any],
      let redisInnerProperties = redisProperty["properties"] as? [String: Any]
    else {
      #expect(Bool(false), "Redis case structure should be correct")
      return
    }

    // Check host parameter has description
    guard let hostProperty = redisInnerProperties["host"] as? [String: Any],
      let hostDescription = hostProperty["description"] as? String
    else {
      #expect(Bool(false), "host parameter should have description")
      return
    }
    #expect(hostDescription == "Redis server host address")

    // Check port parameter has description
    guard let portProperty = redisInnerProperties["port"] as? [String: Any],
      let portDescription = portProperty["description"] as? String
    else {
      #expect(Bool(false), "port parameter should have description")
      return
    }
    #expect(portDescription == "Redis server port number")
  }
}
