import Foundation
import OrderedJSON
import SnapshotTesting
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
    do {
      let files = try FileManager.default
        .contentsOfDirectory(at: suiteRoot, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
      if files.isEmpty {
        // The suite directory exists but contains no JSON — almost
        // certainly a test-bundle packaging regression. Fail loudly so
        // we never silently pass a zero-case parameterized test.
        fatalError(
          """
          JSONTestSuite directory \(suiteRoot.path) is present but contains no \
          .json files. Re-check the package's resources block and the \
          submodule contents.
          """
        )
      }
      return files
    } catch {
      // Same intent: failing to find the suite at all (submodule not
      // initialized, resources not bundled, …) should be a hard CI
      // failure, not a silent skip. The test bundle is misconfigured.
      fatalError(
        """
        Could not enumerate JSONTestSuite at \(suiteRoot.path): \(error). \
        Did you `git submodule update --init --recursive`? Is the \
        Tests/OrderedJSONTests/JSONTestSuite resource being copied into \
        the test bundle?
        """
      )
    }
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

  /// Snapshots our current accept/reject decision for each `i_*` file. RFC
  /// 8259 doesn't pin one — implementations are free to choose — but the
  /// choice should be **stable** so a regression that flips a previously-
  /// accepted file to rejected (or vice versa) shows up in CI as a
  /// snapshot diff.
  ///
  /// The snapshot is a one-line `accepted` / `rejected` string per file,
  /// which keeps the diffs readable.
  @Test(arguments: implementationDefined)
  func implementationDefinedDecision(file: URL) throws {
    let data = try Data(contentsOf: file)
    let decision: String
    do {
      _ = try JSONValue.parse(data)
      decision = "accepted"
    } catch {
      decision = "rejected"
    }
    assertSnapshot(of: decision, as: .description, named: file.lastPathComponent)
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
