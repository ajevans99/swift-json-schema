import Foundation

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
    return fileURLs
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

  func loadAllFiles() -> [(fileName: String, decodedObject: T)] {
    let fileURLs = listFiles()
    var decodedObjects: [(fileName: String, decodedObject: T)] = []

    for fileURL in fileURLs {
      if let data = readFile(at: fileURL),
        let decodedObject = decodeFile(from: data)
      {
        decodedObjects.append((fileURL.lastPathComponent, decodedObject))
      }
    }

    return decodedObjects
  }
}
