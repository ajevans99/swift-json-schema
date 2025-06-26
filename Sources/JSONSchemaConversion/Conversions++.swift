import Foundation
import JSONSchemaBuilder

public enum Conversions {}

extension Conversions {
  public static let uuid = UUIDConversion()
  public static let dateTime = DateTimeConversion()
  public static let date = DateConversion()
  public static let time = TimeConversion()
  public static let url = URLConversion()
}
