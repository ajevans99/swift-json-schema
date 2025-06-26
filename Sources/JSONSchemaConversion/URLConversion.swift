import Foundation
import JSONSchemaBuilder

/// A conversion for JSON Schema `uri` format to `Foundation.URL`.
///
/// Accepts strings that are valid URIs (e.g. "https://example.com").
/// Returns a `URL` if parsing succeeds, otherwise fails validation.
public struct URLConversion: CustomSchemaConvertible {
  public typealias Output = URL
  public var schema: any JSONSchemaComponent<URL> {
    JSONString()
      .format("uri")
      .compactMap { URL(string: $0) }
  }
}
