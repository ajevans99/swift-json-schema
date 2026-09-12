import Foundation
import JSONSchema
import Testing

struct FixtureLoadingError: Error, CustomStringConvertible {
  let path: URL
  let reason: String
  var underlyingError: (any Error)?

  var description: String {
    "\(reason) at \(path.path)"
      + (underlyingError.map { ": \($0)" } ?? "")
  }
}

struct FileLoader<T: Decodable> {
  let directory: URL
  let decode: (Data) throws -> T

  init(
    bundle: Bundle = .module,
    subdirectory: String? = nil,
    decode: @escaping (Data) throws -> T = { try JSONDecoder().decode(T.self, from: $0) }
  ) throws {
    guard let resources = bundle.resourceURL else {
      throw FixtureLoadingError(path: bundle.bundleURL, reason: "Missing bundle resources")
    }
    directory = subdirectory.map { resources.appendingPathComponent($0) } ?? resources
    self.decode = decode
  }

  init(
    directory: URL,
    decode: @escaping (Data) throws -> T = { try JSONDecoder().decode(T.self, from: $0) }
  ) {
    self.directory = directory
    self.decode = decode
  }

  func listFiles(recursive: Bool = false) throws -> [URL] {
    let files = try discoverFiles(in: directory, recursive: recursive)
      .sorted { $0.path < $1.path }
    guard !files.isEmpty else {
      throw FixtureLoadingError(path: directory, reason: "No .json fixtures found")
    }
    return files
  }

  private func discoverFiles(in directory: URL, recursive: Bool) throws -> [URL] {
    do {
      let entries = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
      var files: [URL] = []
      for entry in entries {
        if try entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
          if recursive {
            files += try discoverFiles(in: entry, recursive: true)
          }
        } else if entry.pathExtension == "json" {
          files.append(entry)
        }
      }
      return files
    } catch {
      throw FixtureLoadingError(
        path: directory,
        reason: "Could not enumerate fixtures",
        underlyingError: error
      )
    }
  }

  func loadFile(named name: String) throws -> T {
    try loadFile(at: directory.appendingPathComponent(name).appendingPathExtension("json"))
  }

  func loadFile(at url: URL) throws -> T {
    try decodeFile(from: readFile(at: url), at: url)
  }

  func readFile(at url: URL) throws -> Data {
    do {
      return try Data(contentsOf: url)
    } catch {
      throw FixtureLoadingError(
        path: url,
        reason: "Could not read fixture",
        underlyingError: error
      )
    }
  }

  func decodeFile(from data: Data, at url: URL) throws -> T {
    do {
      return try decode(data)
    } catch {
      throw FixtureLoadingError(
        path: url,
        reason: "Could not decode fixture",
        underlyingError: error
      )
    }
  }

  func loadAllFiles() throws -> [(url: URL, decodedObject: T)] {
    try listFiles().map { ($0, try loadFile(at: $0)) }
  }
}

extension FileLoader where T: Collection {
  func loadNonEmptyFiles() throws -> [(url: URL, decodedObject: T)] {
    let files = try loadAllFiles()
    for file in files where file.decodedObject.isEmpty {
      throw FixtureLoadingError(path: file.url, reason: "Fixture contains no test groups")
    }
    return files
  }
}

// Static parameter discovery cannot throw. Match JSONTestSuiteConformance's
// fail-loudly behavior instead of passing a zero-case parameterized test.
func requiredFixtures<T>(_ load: () throws -> T) -> T {
  do {
    return try load()
  } catch {
    fatalError(
      """
      Could not load conformance fixtures: \(error).
      Run `git submodule update --init --recursive` and check the test bundle's copied resources.
      """
    )
  }
}

struct RemoteLoader {
  let suiteRoot: URL

  init(bundle: Bundle = .module) throws {
    suiteRoot = try FileLoader<JSONValue>(bundle: bundle).directory
      .appendingPathComponent("JSON-Schema-Test-Suite")
  }

  init(suiteRoot: URL) {
    self.suiteRoot = suiteRoot
  }

  private func fetchRemoteSchemas() throws -> [String: JSONValue] {
    let binDirectory = suiteRoot.appendingPathComponent("bin")
    let command = "./jsonschema_suite remotes"
    let outputData = try runCommand(command, at: binDirectory)
    let remoteSchemas: [String: JSONValue]
    do {
      guard let object = try JSONValue.parse(outputData).object else {
        throw DecodingError.typeMismatch(
          [String: JSONValue].self,
          .init(codingPath: [], debugDescription: "Remote schemas must be an object")
        )
      }
      remoteSchemas = Dictionary(uniqueKeysWithValues: object.map { ($0.key, $0.value) })
    } catch {
      throw FixtureLoadingError(
        path: binDirectory,
        reason: "Could not decode output of `\(command)`",
        underlyingError: error
      )
    }
    guard !remoteSchemas.isEmpty else {
      throw FixtureLoadingError(
        path: suiteRoot.appendingPathComponent("remotes"),
        reason: "`\(command)` returned no remote schemas"
      )
    }
    return remoteSchemas
  }

  func loadSchemas() throws -> [String: JSONValue] {
    var remotes = try fetchRemoteSchemas()
    let outputSchemas = try fetchOutputSchemas()
    remotes.merge(outputSchemas) { _, new in new }
    return remotes
  }

  private func fetchOutputSchemas() throws -> [String: JSONValue] {
    let loader = FileLoader<JSONValue>(
      directory: suiteRoot.appendingPathComponent("output-tests"),
      decode: { try JSONValue.parse($0) }
    )
    let files = try loader.listFiles(recursive: true)
      .filter { $0.lastPathComponent == "output-schema.json" }
    guard !files.isEmpty else {
      throw FixtureLoadingError(
        path: loader.directory,
        reason: "No output-schema.json fixtures found"
      )
    }

    var discoveredSchemas: [String: JSONValue] = [:]
    for url in files {
      let schema = try loader.loadFile(at: url)
      guard let identifier = schema.object?["$id"]?.string, !identifier.isEmpty else {
        throw FixtureLoadingError(path: url, reason: "Output schema requires a nonempty string $id")
      }
      discoveredSchemas[identifier] = schema
    }
    return discoveredSchemas
  }
}

struct CommandFailure: Error, CustomStringConvertible {
  let command: String
  let directory: URL
  let status: Int32
  let reason: Process.TerminationReason
  let standardError: String

  var description: String {
    """
    Command `\(command)` at \(directory.path) failed \
    (\(reason == .exit ? "exit status" : "signal") \(status)): \(standardError)
    """
  }
}

func runCommand(
  _ command: String,
  at path: URL,
  temporaryRoot: URL = FileManager.default.temporaryDirectory
) throws -> Data {
  try withTemporaryFixtureDirectory(in: temporaryRoot) { temporaryDirectory in
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    process.currentDirectoryURL = path

    // Separate files keep diagnostics out of JSON and cannot fill up like
    // pipes. They also avoid Foundation's trapping pipe reads on Linux EINTR.
    let outputURL = temporaryDirectory.appendingPathComponent("stdout")
    let diagnosticsURL = temporaryDirectory.appendingPathComponent("stderr")
    try Data().write(to: outputURL)
    try Data().write(to: diagnosticsURL)
    let output = try FileHandle(forWritingTo: outputURL)
    defer { output.closeFile() }
    let diagnostics = try FileHandle(forWritingTo: diagnosticsURL)
    defer { diagnostics.closeFile() }
    process.standardOutput = output
    process.standardError = diagnostics

    do {
      guard try path.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
        throw FixtureLoadingError(path: path, reason: "Command working path is not a directory")
      }
      try process.run()
    } catch {
      throw FixtureLoadingError(
        path: path,
        reason: "Could not launch `\(command)`",
        underlyingError: error
      )
    }
    process.waitUntilExit()

    guard process.terminationReason == .exit, process.terminationStatus == 0 else {
      throw CommandFailure(
        command: command,
        directory: path,
        status: process.terminationStatus,
        reason: process.terminationReason,
        standardError: String(decoding: try Data(contentsOf: diagnosticsURL), as: UTF8.self)
      )
    }
    do {
      return try Data(contentsOf: outputURL)
    } catch {
      throw FixtureLoadingError(
        path: path,
        reason: "Could not read output of `\(command)`",
        underlyingError: error
      )
    }
  }
}

func withTemporaryFixtureDirectory<T>(
  in root: URL = FileManager.default.temporaryDirectory,
  _ body: (URL) throws -> T
) throws -> T {
  let directory = root.appendingPathComponent("json-schema-fixtures-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer {
    do {
      try FileManager.default.removeItem(at: directory)
    } catch {
      Issue.record(error, "Could not remove temporary fixtures at \(directory.path)")
    }
  }
  return try body(directory)
}
