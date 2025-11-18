import Foundation

private final class JSONSchemaBundleFinder {}

extension Bundle {
  public static var jsonSchemaResources: Bundle {
    #if SWIFT_PACKAGE
      return .module
    #else
      return .init(for: JSONSchemaBundleFinder.self)
    #endif
  }
}
