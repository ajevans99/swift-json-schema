import Foundation
import JSONSchema
import JSONSchemaBuilder

setLineBufferedStdout()

func main() throws {
  let encoder = JSONEncoder()
  encoder.keyEncodingStrategy = .convertToSnakeCase
  let decoder = JSONDecoder()

  var bowtieProcess = BowtieProcessor(encoder: encoder, decoder: decoder)

  while true {
    guard let line = readLine() else { continue }

    let command = try decoder.decode(Command.self, from: line.data(using: .utf8)!)
    try bowtieProcess.handle(command: command)
  }
}

do {
  try main()
} catch {
  log("An error occurred: \(error)")
  exit(1)
}
