import JSONSchema

public struct ToolContext: Codable {
  public let name: String
  public let description: String
  public let parameters: Schema

  public init(name: String, description: String, parameters: Schema) {
    self.name = name
    self.description = description
    self.parameters = parameters
  }
}
