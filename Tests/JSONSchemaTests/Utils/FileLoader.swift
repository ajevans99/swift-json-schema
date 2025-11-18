import Foundation
import JSONSchema

struct FileLoader<T: Decodable> {
  let subdirectory: String

  func listFiles() -> [URL] {
    guard
      let fileURLs = Bundle.module.urls(
        forResourcesWithExtension: "json",
        subdirectory: subdirectory
      )
    else {
      print("Failed to find JSON files")
      return []
    }
    #if os(Linux)
      return fileURLs.map { $0 as URL }
    #else
      return fileURLs
    #endif
  }

  func readFile(at url: URL) -> Data? {
    do {
      let data = try Data(contentsOf: url)
      return data
    } catch {
      print("Error reading file at \(url): \(error)")
      return nil
    }
  }

  func decodeFile(from data: Data) -> T? {
    let decoder = JSONDecoder()
    do {
      let decodedObject = try decoder.decode(T.self, from: data)
      return decodedObject
    } catch {
      print("Error decoding file: \(error)")
      return nil
    }
  }

  func loadAllFiles() -> [(url: URL, decodedObject: T)] {
    let fileURLs = listFiles()
    var decodedObjects: [(url: URL, decodedObject: T)] = []

    for fileURL in fileURLs {
      if let data = readFile(at: fileURL),
        let decodedObject = decodeFile(from: data)
      {
        decodedObjects.append((fileURL, decodedObject))
      }
    }

    return decodedObjects
  }
}

struct RemoteLoader {
  private func fetchRemoteSchemas() throws -> [String: JSONValue] {
    guard
      let binDirectory = Bundle.module.url(
        forResource: "jsonschema_suite",
        withExtension: nil,
        subdirectory: "JSON-Schema-Test-Suite/bin"
      )
    else {
      throw NSError(domain: "Invalid Path", code: 1, userInfo: nil)
    }

    let outputData = try runCommand(
      "./jsonschema_suite remotes",
      at: binDirectory.deletingLastPathComponent()
    )

    let decoder = JSONDecoder()
    let remoteSchemas = try decoder.decode([String: JSONValue].self, from: outputData)

    return remoteSchemas
  }

  func loadSchemas() -> [String: JSONValue] {
    do {
      var remotes = try fetchRemoteSchemas()
      let outputSchemas = try fetchOutputSchemas()
      remotes.merge(outputSchemas) { _, new in new }
      return remotes
    } catch {
      print("Error: \(error)")
      return [:]
    }
  }

  private func fetchOutputSchemas() throws -> [String: JSONValue] {
    guard let resourcesURL = Bundle.module.resourceURL else { return [:] }
    let outputTestsURL = resourcesURL.appendingPathComponent("JSON-Schema-Test-Suite/output-tests")

    let directoryEnumerator = FileManager.default.enumerator(
      at: outputTestsURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    var discoveredSchemas: [String: JSONValue] = [:]

    while let url = directoryEnumerator?.nextObject() as? URL {
      guard url.lastPathComponent == "output-schema.json" else { continue }

      let data = try Data(contentsOf: url)
      let schema = try JSONDecoder().decode(JSONValue.self, from: data)

      if case .object(let object) = schema,
        case .string(let identifier)? = object["$id"]
      {
        discoveredSchemas[identifier] = schema
      }
    }

    return discoveredSchemas
  }
}

func runCommand(_ command: String, at path: URL) throws -> Data {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/bin/bash")
  process.arguments = ["-c", command]
  process.currentDirectoryURL = path

  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = pipe

  try process.run()
  process.waitUntilExit()

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return data
}
