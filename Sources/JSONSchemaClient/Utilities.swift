import Foundation

// MARK: Standard Out

func setLineBufferedStdout() {
  setvbuf(stdout, nil, _IOLBF, 0)
}
/// Writes to standard error for logging in Bowtie.
func log(_ message: String) {
  FileHandle.standardError.write("\(message)\n".data(using: .utf8)!)
}

// MARK: JSON
extension JSONEncoder {
  func encodeToString<E: Encodable>(_ encodable: E) throws -> String {
    let data = try encode(encodable)
    return String(data: data, encoding: .utf8)!
  }
}
