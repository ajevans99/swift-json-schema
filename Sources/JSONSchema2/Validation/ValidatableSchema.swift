import Foundation

public protocol ValidatableSchema: Equatable, Sendable {
  func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult
}

extension ValidatableSchema {
  public func validate(_ instance: JSONValue) -> ValidationResult {
    self.validate(instance, at: .init())
  }

  /// Convenience for validating instances from `String` form. The decoder will first convert to ``JSONValue`` and then pass to standard ``validate(_:at:)``.
  public func validate(
    instance: String,
    using decoder: JSONDecoder = .init(),
    at location: JSONPointer = .init()
  ) throws -> ValidationResult {
    let data = try decoder.decode(JSONValue.self, from: Data(instance.utf8))
    return validate(data, at: location)
  }
}
