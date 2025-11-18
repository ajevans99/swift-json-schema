import Foundation

private final class JSONSchemaBundleFinder {}

public extension Bundle {
  static var jsonSchemaResources: Bundle {
    #if SWIFT_PACKAGE
      return .module
    #else
      return .init(for: JSONSchemaBundleFinder.self)
    #endif
  }
}
