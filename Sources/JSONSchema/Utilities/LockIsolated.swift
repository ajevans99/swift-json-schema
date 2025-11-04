import Foundation

/// A thread-safe wrapper that uses a lock to protect access to a mutable value.
///
/// This type provides a simple way to make a value safe to access from multiple threads
/// by wrapping it in a lock. Access to the value is controlled through the `withLock` method.
final class LockIsolated<Value>: @unchecked Sendable {
  private var value: Value
  private let lock = NSRecursiveLock()

  init(_ value: @autoclosure @Sendable () throws -> Value) rethrows {
    self.value = try value()
  }

  func withLock<T: Sendable>(
    _ operation: @Sendable (inout Value) throws -> T
  ) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    var value = self.value
    defer { self.value = value }
    return try operation(&value)
  }
}
