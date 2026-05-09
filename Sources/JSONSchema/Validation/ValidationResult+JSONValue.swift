import Foundation
import OrderedCollections
import OrderedJSON

extension ValidationResult {
  /// An ``OrderedJSON/JSONValue`` representation of this validation
  /// result, with field order matching the existing ``encode(to:)``
  /// contract: `valid`, `keywordLocation`, `absoluteKeywordLocation`,
  /// `instanceLocation`, `errors`, `annotations`.
  ///
  /// Lets callers serialize a result deterministically (via
  /// ``OrderedJSON/JSONValue/serialized(options:)``) without routing
  /// through `JSONEncoder` first. See issue #161.
  public var jsonValue: JSONValue {
    var dict = OrderedDictionary<String, JSONValue>()
    dict["valid"] = .boolean(isValid)
    dict["keywordLocation"] = .string(keywordLocation.jsonPointerString)
    if let absoluteKeywordLocation {
      dict["absoluteKeywordLocation"] = .string(absoluteKeywordLocation.absoluteString)
    }
    dict["instanceLocation"] = .string(instanceLocation.jsonPointerString)
    if let errors {
      dict["errors"] = .array(errors.map { $0.jsonValue })
    }
    if let annotations {
      dict["annotations"] = .array(annotations.map { $0.annotationJSONValue })
    }
    return .object(dict)
  }
}

extension ValidationError {
  /// JSON representation matching the existing ``encode(to:)`` contract.
  public var jsonValue: JSONValue {
    var dict = OrderedDictionary<String, JSONValue>()
    dict["keyword"] = .string(keyword)
    dict["message"] = .string(message)
    dict["keywordLocation"] = .string(keywordLocation.jsonPointerString)
    if let absoluteKeywordLocation {
      dict["absoluteKeywordLocation"] = .string(absoluteKeywordLocation.absoluteString)
    }
    dict["instanceLocation"] = .string(instanceLocation.jsonPointerString)
    if let errors {
      dict["errors"] = .array(errors.map { $0.jsonValue })
    }
    return .object(dict)
  }
}

extension AnyAnnotation {
  /// JSON representation matching the existing
  /// ``AnyAnnotationWrapper/encode(to:)`` contract.
  fileprivate var annotationJSONValue: JSONValue {
    var dict = OrderedDictionary<String, JSONValue>()
    dict["keywordLocation"] = .string(schemaLocation.jsonPointerString)
    if let absoluteSchemaLocation {
      dict["absoluteKeywordLocation"] = .string(absoluteSchemaLocation.absoluteString)
    }
    dict["instanceLocation"] = .string(instanceLocation.jsonPointerString)
    dict["annotation"] = jsonValue
    return .object(dict)
  }
}
