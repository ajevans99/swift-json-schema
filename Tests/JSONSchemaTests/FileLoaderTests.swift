import Foundation
import JSONSchema
import Testing

struct FileLoaderTests {
  @Test func missingDirectory() throws {
    try withTemporaryFixtureDirectory { root in
      let directory = root.appendingPathComponent("missing")
      #expect {
        try FileLoader<JSONValue>(directory: directory).loadAllFiles()
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.path == directory.path && failure.underlyingError != nil
          && failure.description.contains("Could not enumerate")
      }
    }
  }

  @Test func emptyDirectory() throws {
    try withTemporaryFixtureDirectory { root in
      try Data("not a fixture".utf8).write(to: root.appendingPathComponent("README.txt"))
      #expect {
        try FileLoader<JSONValue>(directory: root).loadAllFiles()
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.path == root.path && failure.description.contains("No .json fixtures")
      }
    }
  }

  @Test(arguments: ["missing", "directory", "dangling-link"])
  func unreadableFile(kind: String) throws {
    try withTemporaryFixtureDirectory { root in
      let file = root.appendingPathComponent("fixture.json")
      if kind == "directory" {
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
      } else if kind == "dangling-link" {
        try FileManager.default.createSymbolicLink(
          at: file,
          withDestinationURL: root.appendingPathComponent("missing")
        )
      }
      #expect {
        try FileLoader<JSONValue>(directory: root).loadFile(named: "fixture")
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.path == file.path && failure.underlyingError != nil
          && failure.description.contains("Could not read fixture")
      }
    }
  }

  @Test(arguments: ["{", #"{"wrong":"shape"}"#])
  func invalidFileIsNotOmitted(contents: String) throws {
    try withTemporaryFixtureDirectory { root in
      try Data("[1]".utf8).write(to: root.appendingPathComponent("a-valid.json"))
      let invalid = root.appendingPathComponent("b-invalid.json")
      try Data(contents.utf8).write(to: invalid)
      #expect {
        try FileLoader<[Int]>(directory: root).loadAllFiles()
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.resolvingSymlinksInPath().path == invalid.resolvingSymlinksInPath().path
          && failure.underlyingError is DecodingError
          && failure.description.contains("Could not decode fixture")
      }
    }
  }

  @Test func unreadableFileIsNotOmitted() throws {
    try withTemporaryFixtureDirectory { root in
      try Data("[1]".utf8).write(to: root.appendingPathComponent("valid.json"))
      try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("unreadable.json"),
        withDestinationURL: root.appendingPathComponent("missing")
      )
      #expect(throws: FixtureLoadingError.self) {
        try FileLoader<[Int]>(directory: root).loadAllFiles()
      }
    }
  }

  @Test func emptyTestGroups() throws {
    try withTemporaryFixtureDirectory { root in
      let empty = root.appendingPathComponent("empty.json")
      try Data("[]".utf8).write(to: empty)
      #expect {
        try FileLoader<[JSONSchemaTest]>(directory: root).loadNonEmptyFiles()
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.resolvingSymlinksInPath().path == empty.resolvingSymlinksInPath().path
          && failure.description.contains("no test groups")
      }
      #expect(throws: FixtureLoadingError.self) {
        try FileLoader<[OutputTestDocument]>(directory: root).loadNonEmptyFiles()
      }
    }
  }

  @Test func validFilesAreSortedAndOptionalSubdirectoriesStayOptIn() throws {
    try withTemporaryFixtureDirectory { root in
      let optional = root.appendingPathComponent("optional")
      try FileManager.default.createDirectory(at: optional, withIntermediateDirectories: false)
      try Data("[2]".utf8).write(to: root.appendingPathComponent("b.json"))
      try Data("[1]".utf8).write(to: root.appendingPathComponent("a.json"))
      try Data("[3]".utf8).write(to: optional.appendingPathComponent("c.json"))
      let loader = FileLoader<[Int]>(directory: root)

      let files = try loader.loadNonEmptyFiles()
      #expect(files.map(\.url.lastPathComponent) == ["a.json", "b.json"])
      #expect(files.map(\.decodedObject) == [[1], [2]])
      #expect(try loader.loadFile(named: "a") == [1])
      #expect(try loader.listFiles(recursive: true).count == 3)
    }
  }
}

struct RemoteLoaderTests {
  @Test func validRemotesAndNestedOutputSchemas() throws {
    try withTemporaryFixtureDirectory { root in
      try prepareSuite(at: root)
      let remotes = try RemoteLoader(suiteRoot: root).loadSchemas()
      #expect(remotes.count == 2)
      #expect(remotes["https://example.com/remote"] == .boolean(true))
      #expect(remotes["https://example.com/output"]?.object?["type"] == .string("object"))
    }
  }

  @Test(arguments: ["{", "[]", "{}"])
  func invalidOrEmptyRemoteOutput(output: String) throws {
    try withTemporaryFixtureDirectory { root in
      try prepareSuite(at: root, command: "printf '%s' '\(output)'")
      #expect {
        try RemoteLoader(suiteRoot: root).loadSchemas()
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.path.hasPrefix(root.path)
          && failure.description.contains("jsonschema_suite remotes")
          && (output == "{}" || failure.underlyingError is DecodingError)
      }
    }
  }

  @Test(arguments: ["missing", "empty", "no-output-schema"])
  func missingOutputSchemas(kind: String) throws {
    try withTemporaryFixtureDirectory { root in
      try prepareSuite(at: root)
      let outputRoot = root.appendingPathComponent("output-tests")
      try FileManager.default.removeItem(at: outputRoot)
      if kind != "missing" {
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: false)
      }
      if kind == "no-output-schema" {
        try Data("[]".utf8).write(to: outputRoot.appendingPathComponent("content.json"))
      }
      #expect {
        try RemoteLoader(suiteRoot: root).loadSchemas()
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.path == outputRoot.path
          && (kind != "missing" || failure.underlyingError != nil)
      }
    }
  }

  @Test(arguments: ["{", "true", "{}", #"{"$id":1}"#, #"{"$id":""}"#])
  func invalidOutputSchema(contents: String) throws {
    try withTemporaryFixtureDirectory { root in
      try prepareSuite(at: root)
      let file = root.appendingPathComponent("output-tests/draft2020-12/output-schema.json")
      try Data(contents.utf8).write(to: file)
      #expect {
        try RemoteLoader(suiteRoot: root).loadSchemas()
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.resolvingSymlinksInPath().path == file.resolvingSymlinksInPath().path
          && (contents != "{" || failure.underlyingError is DecodingError)
      }
    }
  }

  @Test func remoteCommandFailureIsNotAnEmptyDictionary() throws {
    try withTemporaryFixtureDirectory { root in
      try prepareSuite(at: root, command: "printf 'broken remote fixture' >&2; exit 17")
      #expect {
        try RemoteLoader(suiteRoot: root).loadSchemas()
      } throws: { error in
        guard let failure = error as? CommandFailure else { return false }
        return failure.status == 17 && failure.standardError == "broken remote fixture"
          && failure.description.contains(root.path)
      }
    }
  }

  @Test func missingRemoteScript() throws {
    try withTemporaryFixtureDirectory { root in
      try prepareSuite(at: root)
      try FileManager.default.removeItem(at: root.appendingPathComponent("bin/jsonschema_suite"))
      #expect {
        try RemoteLoader(suiteRoot: root).loadSchemas()
      } throws: { error in
        guard let failure = error as? CommandFailure else { return false }
        return failure.status != 0 && failure.standardError.contains("jsonschema_suite")
      }
    }
  }

  private func prepareSuite(
    at root: URL,
    command: String = #"printf '%s' '{"https://example.com/remote":true}'"#
  ) throws {
    let bin = root.appendingPathComponent("bin")
    let output = root.appendingPathComponent("output-tests/draft2020-12")
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let script = bin.appendingPathComponent("jsonschema_suite")
    try Data("#!/bin/bash\n\(command)\n".utf8).write(to: script)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
    try Data(#"{"$id":"https://example.com/output","type":"object"}"#.utf8)
      .write(to: output.appendingPathComponent("output-schema.json"))
  }
}

struct RunCommandTests {
  @Test(arguments: ["success", "launch-failure", "exit-failure", "signal"])
  func removesCaptureFiles(outcome: String) throws {
    try withTemporaryFixtureDirectory { root in
      let captures = root.appendingPathComponent("captures")
      try FileManager.default.createDirectory(at: captures, withIntermediateDirectories: false)
      switch outcome {
      case "success":
        let output = try runCommand(
          "printf 'output'; printf 'diagnostic' >&2",
          at: root,
          temporaryRoot: captures
        )
        #expect(output == Data("output".utf8))
      case "launch-failure":
        #expect(throws: FixtureLoadingError.self) {
          try runCommand(
            "true",
            at: root.appendingPathComponent("missing"),
            temporaryRoot: captures
          )
        }
      default:
        let termination = outcome == "signal" ? "kill -KILL $$" : "exit 17"
        #expect {
          try runCommand(
            "printf 'output'; printf 'diagnostic' >&2; \(termination)",
            at: root,
            temporaryRoot: captures
          )
        } throws: { error in
          guard let failure = error as? CommandFailure else { return false }
          return failure.standardError == "diagnostic"
            && (outcome == "signal" ? failure.reason == .uncaughtSignal : failure.status == 17)
        }
      }
      #expect(try FileManager.default.contentsOfDirectory(atPath: captures.path).isEmpty)
    }
  }

  @Test(arguments: 0 ..< 8)
  func concurrentCommandOutput(index: Int) throws {
    try withTemporaryFixtureDirectory { root in
      let output = try runCommand(
        "printf '\(index)'; sleep 0.05; printf '\(index)'",
        at: root
      )
      #expect(String(decoding: output, as: UTF8.self) == "\(index)\(index)")
    }
  }

  @Test func standardErrorDoesNotCorruptJSON() throws {
    try withTemporaryFixtureDirectory { root in
      let output = try runCommand("printf 'warning' >&2; printf '{\"valid\":true}'", at: root)
      #expect(try JSONDecoder().decode([String: Bool].self, from: output) == ["valid": true])
    }
  }

  @Test func signalTerminationFailsEvenWithValidOutput() throws {
    try withTemporaryFixtureDirectory { root -> Void in
      // Test runners can pass on ignored/blocked SIGTERM; SIGKILL cannot be ignored.
      #expect {
        try runCommand("printf '{}'; kill -KILL $$", at: root)
      } throws: { error in
        guard let failure = error as? CommandFailure else { return false }
        return failure.reason == .uncaughtSignal && failure.description.contains("signal")
      }
    }
  }

  @Test func missingWorkingDirectory() throws {
    try withTemporaryFixtureDirectory { root in
      let missing = root.appendingPathComponent("missing")
      #expect {
        try runCommand("printf '{}'", at: missing)
      } throws: { error in
        guard let failure = error as? FixtureLoadingError else { return false }
        return failure.path.path == missing.path && failure.underlyingError != nil
          && failure.description.contains("Could not launch")
      }
    }
  }

  @Test(.timeLimit(.minutes(1)))
  func capturesOutputLargerThanPipeCapacity() throws {
    try withTemporaryFixtureDirectory { root in
      let output = try runCommand(
        """
        for ((i=0; i<20000; i++)); do
          printf '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
          printf '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' >&2
        done
        """,
        at: root
      )
      #expect(output.count == 1_280_000)
      #expect(String(decoding: output.prefix(16), as: UTF8.self) == "0123456789abcdef")
    }
  }
}
