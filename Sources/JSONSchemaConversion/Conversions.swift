import Foundation
import JSONSchemaBuilder

public enum Conversions {
  public static let uuid = UUIDConversion.self

  public static let dateTime = DateTimeConversion.self
  public static let date = DateConversion.self
  public static let time = TimeConversion.self

  public static let url = URLConversion.self
}
