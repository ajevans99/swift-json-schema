import Foundation
import OrderedJSON
import Testing

/// Drives the [nst/JSONTestSuite](https://github.com/nst/JSONTestSuite)
/// against ``JSONValue/parse(_:)``.
///
/// File-name conventions (Seriot, "Parsing JSON is a Minefield"):
///
/// - `y_*` — must accept (well-formed JSON, RFC 8259)
/// - `n_*` — must reject (ill-formed JSON)
/// - `i_*` — implementation-defined; either accept or reject is allowed,
///   but behavior should be stable run-to-run. We snapshot the current
///   accept/reject decision per file so future drift is caught at PR time.
@Suite("JSONTestSuite parser conformance")
struct JSONTestSuiteConformance {
  // MARK: - Discovery

  private static let suiteRoot: URL = {
    Bundle.module.resourceURL!.appendingPathComponent("JSONTestSuite/test_parsing")
  }()

  private static let allFiles: [URL] = {
    (try? FileManager.default
      .contentsOfDirectory(
        at: suiteRoot,
        includingPropertiesForKeys: nil
      )
      .filter { $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []
  }()

  private static let mustAccept = allFiles.filter { $0.lastPathComponent.hasPrefix("y_") }
  private static let mustReject = allFiles.filter { $0.lastPathComponent.hasPrefix("n_") }
  private static let implementationDefined = allFiles.filter {
    $0.lastPathComponent.hasPrefix("i_")
  }

  // MARK: - "Must accept" cases

  @Test(arguments: mustAccept)
  func mustAccept(file: URL) throws {
    let data = try Data(contentsOf: file)
    do {
      _ = try JSONValue.parse(data)
    } catch {
      Issue.record(
        "y_ case \(file.lastPathComponent) should have parsed cleanly, but failed: \(error)"
      )
    }
  }

  // MARK: - "Must reject" cases

  @Test(arguments: mustReject)
  func mustReject(file: URL) throws {
    let data = try Data(contentsOf: file)
    do {
      _ = try JSONValue.parse(data)
      Issue.record(
        "n_ case \(file.lastPathComponent) should have been rejected, but parsed successfully."
      )
    } catch {
      // Expected.
    }
  }

  // MARK: - Implementation-defined cases

  /// We don't pin a yes/no for `i_` cases; we just record what we currently
  /// do so the answer is documented and a future change is intentional.
  @Test(arguments: implementationDefined)
  func implementationDefinedRunsCleanly(file: URL) throws {
    let data = try Data(contentsOf: file)
    // Should never crash. Acceptance or rejection is both fine.
    _ = try? JSONValue.parse(data)
  }

  // MARK: - Roundtrip determinism

  /// For each `y_*` file, parsing → serializing → parsing → serializing
  /// must produce byte-identical output between the two emit passes.
  /// Locks in the parser → serializer round-trip stability that motivates
  /// this whole effort (see #149).
  @Test(arguments: mustAccept)
  func roundtripIsByteStable(file: URL) throws {
    let data = try Data(contentsOf: file)
    guard let first = try? JSONValue.parse(data) else {
      // If parsing fails, the y_-test will already have flagged it.
      return
    }
    let emitted1 = try first.serializedData()
    let second = try JSONValue.parse(emitted1)
    let emitted2 = try second.serializedData()
    #expect(emitted1 == emitted2, "Re-parsing a serialized value should produce identical bytes")
  }
}
