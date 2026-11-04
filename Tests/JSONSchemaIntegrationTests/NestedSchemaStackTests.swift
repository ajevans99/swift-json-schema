import Dispatch
import Foundation
import JSONSchemaBuilder
import Testing

// First access must happen on the constrained thread.
private enum NestedSchemaStackFixtures {
  static let constrainedStackBytes = 512 * 1_024

  @Schemable(optionalNulls: false)
  struct Leaf {
    let asset: String?
    let rate: Double?
    let frames: [Int]
  }

  @Schemable(optionalNulls: false)
  struct Node {
    let down: Leaf?
    let left: Leaf?
    let right: Leaf?
    let up: Leaf?
    let rate: Double?
  }

  @Schemable(optionalNulls: false)
  struct Branch {
    let first: Node?
    let second: Node?
    let third: Node?
    let fourth: Node?
    let fifth: Node?
    let sixth: Node?
    let seventh: Node?
    let eighth: Node?
    let ninth: Node?
    let width: Int
    let height: Int
    let rate: Double
    let padding: Int
    let asset: String?
    let anchorX: Int?
    let anchorY: Int?
  }

  @Schemable(optionalNulls: false)
  struct Root {
    let first: Branch?
    let second: Branch?
    let third: Branch?
    let fourth: Branch?
    let fifth: Branch?
    let sixth: Branch?
    let seventh: Branch?
    let eighth: Branch?
    let ninth: Branch?
    let tenth: Branch?
    let eleventh: Branch?
    let twelfth: Branch?
  }
}

private final class ConstrainedStackTask: @unchecked Sendable {
  private(set) var outcome: Result<Void, any Error>?

  func run() {
    outcome = Result {
      _ = NestedSchemaStackFixtures.Root.schema.definition()
    }
  }
}

struct NestedSchemaStackTests {
  @Test func deeplyNestedSchemaInstantiatesOnConstrainedStack() throws {
    let task = ConstrainedStackTask()
    let finished = DispatchSemaphore(value: 0)
    let thread = Thread {
      task.run()
      finished.signal()
    }
    thread.stackSize = NestedSchemaStackFixtures.constrainedStackBytes
    thread.start()
    finished.wait()

    try #require(task.outcome).get()
  }
}
