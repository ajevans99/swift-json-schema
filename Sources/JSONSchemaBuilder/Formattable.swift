import Foundation

public protocol Formattable {
  associatedtype Output

  @JSONSchemaBuilder
  var schema: any JSONSchemaComponent<Output> { get }
}
