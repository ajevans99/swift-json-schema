import Foundation

public protocol CustomSchemaConvertible {
  associatedtype Output

  @JSONSchemaBuilder
  var schema: any JSONSchemaComponent<Output> { get }
}
