//
// Copyright(c) Marin Todorov 2020
// For the license agreement for this code check the LICENSE file.
//

import Foundation
import TimelaneCore

fileprivate let lock = NSLock()
fileprivate let operationTimelane = OperationTimelane()

class OperationTimelane: NSObject {
    
    /// Private wrapper to ensure operations emit begin event only once.
    private class OperationWrapper: NSObject {
        weak var op: Operation?
        var started = false
        
        let filter: Set<Timelane.LaneType>
        let source: String
        let subscription: Timelane.Subscription
        
        init(_ op: Operation, name: String, filter: Set<Timelane.LaneType>, source: String, logger: @escaping Timelane.Logger) {
            self.op = op
            
            self.filter = filter
            self.source = source
            self.subscription = Timelane.Subscription(name: name, logger: logger)
        }
    }
    
    /// List of actively tracked operations
    private var operations: [OperationWrapper] = []
    
    /// The states of an operation Timelane tracks
    private enum State: String {
        case executing, cancelled, finished
    }

    /// Start tracking an operation
    func addOperation(_ operation: Operation, name: String, filter: Set<Timelane.LaneType>, source: String, logger: @escaping Timelane.Logger) {
        lock.lock()
        defer { lock.unlock() }
        
        operation.addObserver(self, forKeyPath: State.executing.rawValue, options: [.initial, .new], context: nil)
        operation.addObserver(self, forKeyPath: State.cancelled.rawValue, options: .new, context: nil)
        operation.addObserver(self, forKeyPath: State.finished.rawValue, options: .new, context: nil)
        operations.append(OperationWrapper(operation, name: name, filter: filter, source: source, logger: logger))
    }

    /// Stop tracking an operation
    func removeOperation(_ op: Operation) {
        lock.lock()
        defer { lock.unlock() }

        op.removeObserver(self, forKeyPath: State.executing.rawValue)
        op.removeObserver(self, forKeyPath: State.cancelled.rawValue)
        op.removeObserver(self, forKeyPath: State.finished.rawValue)
        
        if let index = operations.firstIndex(where: { wrapper -> Bool in
            return wrapper.op == op
        }) {
            operations.remove(at: index)
        }
    }

    /// Receives an update event for a tracked operation.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let op = object as? Operation,
            let keyPath = keyPath,
            let newValue = change?[NSKeyValueChangeKey.newKey] as? Bool,
            let wrapper = operations.first(where: { wrapper -> Bool in
                return wrapper.op == op
            })
            else { return }
        
        switch keyPath {
        case State.executing.rawValue where newValue && !wrapper.started:
            // Should happen only once, remove observer for this event
            lock.lock()
            defer { lock.unlock() }

            // Begin the operation
            wrapper.started = true
            if wrapper.filter.contains(.subscription) {
                wrapper.subscription.begin(source: wrapper.source)
            }

        case State.cancelled.rawValue where newValue && wrapper.started:
            // Should happen only once, remove observer for this event
            lock.lock()
            defer { lock.unlock() }

            wrapper.subscription.end(state: .cancelled)
            removeOperation(op)
            
        case State.finished.rawValue where newValue:
            // Should happen only once, remove observer for this event
            if wrapper.filter.contains(.subscription) {
                wrapper.subscription.end(state: .completed)
            }
            if wrapper.filter.contains(.event) {
                wrapper.subscription.event(value: .completion, source: wrapper.source)
            }
            
            removeOperation(op)
        default:
            return
        }
    }
    
    func emitValue(_ value: String, op: Operation, source: String) {
        guard let wrapper = operations.first(where: { wrapper -> Bool in
                return wrapper.op == op
            })
            else { return }
        wrapper.subscription.event(value: .value(value), source: source)
    }
}

/// An operation queue that logs its operations in Timelane.
public class LaneOperationQueue: OperationQueue {
    public override init() {
        super.init()
    }
    
    var filter: Set<Timelane.LaneType> = Set(Timelane.LaneType.allCases)
    var logger: Timelane.Logger = Timelane.defaultLogger
    
    
    /// Creates an operation queue that logs its operations in Timelane.
    /// - Parameters:
    ///   - name: The name to use for creating a lane in Timelane.
    ///   - name: A name for the lane when visualized in Instruments
    ///   - filter: Which events to log, subscriptions or data events.
    public init(_ name: String, filter: Set<Timelane.LaneType> = Set(Timelane.LaneType.allCases), logger: @escaping Timelane.Logger = Timelane.defaultLogger) {
        super.init()
        self.name = name
        self.filter = filter
        self.logger = logger
    }
    
    private static let unnamed = "Unnamed Operation Queue"
    
    public override func addOperation(_ op: Operation) {
        super.addOperation(op.lane(name ?? LaneOperationQueue.unnamed, filter: filter, logger: logger))
    }
    
    public override func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        super.addOperations(ops.map { operation in
            return operation.lane(name ?? LaneOperationQueue.unnamed, filter: filter, logger: logger)
        }, waitUntilFinished: wait)
    }
    
    public override func addOperation(_ block: @escaping () -> Void) {
        self.addOperation(BlockOperation(block: block).lane(name ?? LaneOperationQueue.unnamed, filter: filter, logger: logger))
    }
}

public extension Operation {
    
    /// Logs a value event for the current operation in Timelane.
    /// - Parameters:
    ///   - value: A value to log in Timelane
    @available(macOS 10.14, iOS 12, tvOS 12, watchOS 5, *)
    func laneValue(_ value: Any,
                   file: StaticString = #file,
                   function: StaticString = #function, line: UInt = #line) {

        let fileName = file.description.components(separatedBy: "/").last!
        let source = "\(fileName):\(line) - \(function)"

        let string = (value as? String) ?? String(describing: value)
        operationTimelane.emitValue(string, op: self, source: source)
    }
    
    /// The `lane` method logs the operation and its events to the Timelane Instrument.
    ///
    ///  - Note: You can download the Timelane Instrument from http://timelane.tools
    /// - Parameters:
    ///   - name: A name for the lane when visualized in Instruments
    ///   - filter: Which events to log subscriptions or data events.
    @discardableResult
    @available(macOS 10.14, iOS 12, tvOS 12, watchOS 5, *)
    func lane(_ name: String,
              filter: Set<Timelane.LaneType> = Set(Timelane.LaneType.allCases),
              file: StaticString = #file,
              function: StaticString = #function, line: UInt = #line,
              logger: @escaping Timelane.Logger = Timelane.defaultLogger) -> Self {
      
        let fileName = file.description.components(separatedBy: "/").last!
        let source = "\(fileName):\(line) - \(function)"
        
        // Start tracking the operation in Timelane
        operationTimelane.addOperation(self, name: name, filter: filter, source: source, logger: logger)
        
        return self
    }
}
