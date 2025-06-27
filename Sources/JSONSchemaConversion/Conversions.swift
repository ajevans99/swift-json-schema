import Foundation
import JSONSchemaBuilder

public enum Conversions {
  public static var uuid = UUIDConversion.self

  public static var dateTime = DateTimeConversion.self
  public static var date = DateConversion.self
  public static var time = TimeConversion.self

  public static var url = URLConversion.self
}
