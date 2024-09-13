import JSONSchema

enum Command: Decodable {
  struct Start: Codable {
    let version: Int
  }

  struct Dialect: Decodable {
    let dialect: String
  }

  struct Run: Decodable {
    struct TestCase: Codable {
      let description: String
      let comment: String?
      let schema: SchemaOrBool
      let registry: [String: JSONValue]?
      let tests: [Test]

      struct Test: Codable {
        let description: String
        let comment: String?
        let instance: JSONValue
        let valid: Bool?
      }
    }

    let seq: JSONValue
    let testCase: TestCase

    private enum CodingKeys: String, CodingKey {
      case seq, testCase = "case"
    }
  }

  case start(Start)
  case dialect(Dialect)
  case run(Run)
  case stop

  // Custom decoding to handle polymorphism
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let cmd = try container.decode(String.self, forKey: .cmd)

    switch cmd {
    case "start":
      let startCommand = try Start(from: decoder)
      self = .start(startCommand)
    case "dialect":
      let dialectCommand = try Dialect(from: decoder)
      self = .dialect(dialectCommand)
    case "run":
      let runCommand = try Run(from: decoder)
      self = .run(runCommand)
    case "stop":
      self = .stop
    default:
      throw DecodingError.dataCorruptedError(forKey: .cmd, in: container, debugDescription: "Unsupported command '\(cmd)'")
    }
  }

  private enum CodingKeys: String, CodingKey {
    case cmd
  }
}
