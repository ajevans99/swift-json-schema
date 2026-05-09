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
///   but behavior should be stable across runs. We pin the current decision
///   per file in ``expectedImplementationDefinedDecisions`` so any future
///   parser change that flips a yes/no shows up as a failing test.
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

  private static let mustAcceptFiles = allFiles.filter { $0.lastPathComponent.hasPrefix("y_") }
  private static let mustRejectFiles = allFiles.filter { $0.lastPathComponent.hasPrefix("n_") }
  private static let implementationDefinedFiles = allFiles.filter {
    $0.lastPathComponent.hasPrefix("i_")
  }

  // MARK: - Implementation-defined decision contract
  //
  // RFC 8259 leaves these cases up to the parser. Each entry below records
  // the choice OrderedJSON's parser currently makes. A future change that
  // intentionally flips a decision should update the corresponding entry;
  // an unintentional flip is a regression and the test fails.

  enum Decision: String, CustomStringConvertible {
    case accepted
    case rejected
    var description: String { rawValue }
  }

  private static let expectedImplementationDefinedDecisions: [String: Decision] = [
    "i_number_double_huge_neg_exp.json": .accepted,
    "i_number_huge_exp.json": .accepted,
    "i_number_neg_int_huge_exp.json": .accepted,
    "i_number_pos_double_huge_exp.json": .accepted,
    "i_number_real_neg_overflow.json": .accepted,
    "i_number_real_pos_overflow.json": .accepted,
    "i_number_real_underflow.json": .accepted,
    "i_number_too_big_neg_int.json": .accepted,
    "i_number_too_big_pos_int.json": .accepted,
    "i_number_very_big_negative_int.json": .accepted,
    "i_object_key_lone_2nd_surrogate.json": .rejected,
    "i_string_1st_surrogate_but_2nd_missing.json": .rejected,
    "i_string_1st_valid_surrogate_2nd_invalid.json": .rejected,
    "i_string_UTF-16LE_with_BOM.json": .rejected,
    "i_string_UTF-8_invalid_sequence.json": .rejected,
    "i_string_UTF8_surrogate_U+D800.json": .rejected,
    "i_string_incomplete_surrogate_and_escape_valid.json": .rejected,
    "i_string_incomplete_surrogate_pair.json": .rejected,
    "i_string_incomplete_surrogates_escape_valid.json": .rejected,
    "i_string_invalid_lonely_surrogate.json": .rejected,
    "i_string_invalid_surrogate.json": .rejected,
    "i_string_invalid_utf-8.json": .rejected,
    "i_string_inverted_surrogates_U+1D11E.json": .rejected,
    "i_string_iso_latin_1.json": .rejected,
    "i_string_lone_second_surrogate.json": .rejected,
    "i_string_lone_utf8_continuation_byte.json": .rejected,
    "i_string_not_in_unicode_range.json": .rejected,
    "i_string_overlong_sequence_2_bytes.json": .rejected,
    "i_string_overlong_sequence_6_bytes.json": .rejected,
    "i_string_overlong_sequence_6_bytes_null.json": .rejected,
    "i_string_truncated-utf-8.json": .rejected,
    "i_string_utf16BE_no_BOM.json": .rejected,
    "i_string_utf16LE_no_BOM.json": .rejected,
    "i_structure_500_nested_arrays.json": .rejected,
    "i_structure_UTF-8_BOM_empty_object.json": .rejected,
  ]

  // MARK: - "Must accept" cases

  @Test(arguments: Self.mustAcceptFiles)
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

  @Test(arguments: Self.mustRejectFiles)
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

  @Test(arguments: Self.implementationDefinedFiles)
  func implementationDefinedDecision(file: URL) throws {
    let data = try Data(contentsOf: file)
    let actual: Decision = (try? JSONValue.parse(data)) != nil ? .accepted : .rejected
    let name = file.lastPathComponent
    guard let expected = Self.expectedImplementationDefinedDecisions[name] else {
      Issue.record(
        """
        i_ case \(name) is not pinned in `expectedImplementationDefinedDecisions`. \
        OrderedJSON \(actual) it on this run; please add the corresponding entry \
        so the decision is locked in for future runs.
        """
      )
      return
    }
    #expect(
      actual == expected,
      """
      Decision for \(name) drifted from \(expected) to \(actual). \
      If intentional, update `expectedImplementationDefinedDecisions`.
      """
    )
  }

  // MARK: - Roundtrip determinism

  /// For each `y_*` file, parsing → serializing → parsing → serializing
  /// must produce byte-identical output between the two emit passes.
  /// Locks in the parser → serializer round-trip stability that motivates
  /// this whole effort (see #149).
  @Test(arguments: Self.mustAcceptFiles)
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
