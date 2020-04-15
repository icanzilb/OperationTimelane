import XCTest
@testable import TimelaneCore
import TimelaneCoreTestUtils
@testable import OperationTimelane

final class OperationTimelaneTests: XCTestCase {
    /// Test subscription
    func testEmitsSubscription() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true

        let op = BlockOperation { sleep(1) }
            .lane("Sleep operation", filter: [.subscription], logger: recorder.log)
        
        op.start()
        
        XCTAssertEqual(recorder.logged.count, 2)
        guard recorder.logged.count == 2 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].signpostType, "begin")
        XCTAssertEqual(recorder.logged[0].subscribe, "Sleep operation")
        XCTAssertEqual(recorder.logged[1].signpostType, "end")
    }

    /// Test cancelled
    func testEmitsCancelled() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true

        let op = BlockOperation { sleep(1) }
            .lane("Sleep operation", filter: [.subscription], logger: recorder.log)
        op.cancel()
        op.start()
        
        XCTAssertEqual(recorder.logged.count, 1)
        guard recorder.logged.count == 1 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].signpostType, "end")
    }

    /// Test operation queue
    func testVanillaOperationQueue() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true

        let queue = OperationQueue()
        let op = BlockOperation { sleep(1) }
            .lane("Operation", filter: [.subscription], logger: recorder.log)
        
        queue.addOperation(op)
        
        XCTAssertEqual(recorder.logged.count, 0)
        
        queue.waitUntilAllOperationsAreFinished()
        
        // Wait asynchronously to give the queue a chance to finish
        let expectation1 = expectation(description: "Finished")
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5.0)
        
        XCTAssertEqual(recorder.logged.count, 2)
        guard recorder.logged.count == 2 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].signpostType, "begin")
        XCTAssertEqual(recorder.logged[0].subscribe, "Operation")
        XCTAssertEqual(recorder.logged[1].signpostType, "end")
    }

    /// Test operation queue
    func testLaneOperationQueue() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true

        let queue = LaneOperationQueue("Queue", filter: [.subscription], logger: recorder.log)
        let op = BlockOperation { sleep(1) }
        
        queue.addOperation(op)
        
        XCTAssertEqual(recorder.logged.count, 0)
        
        queue.waitUntilAllOperationsAreFinished()
        
        // Wait asynchronously to give the queue a chance to finish
        let expectation1 = expectation(description: "Finished")
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5.0)
        
        XCTAssertEqual(recorder.logged.count, 2)
        guard recorder.logged.count == 2 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].signpostType, "begin")
        XCTAssertEqual(recorder.logged[0].subscribe, "Queue")
        XCTAssertEqual(recorder.logged[1].signpostType, "end")
    }

    class TestValuesOperation: Operation {
        private var _finished = false
        override var isFinished: Bool {
            get { return _finished }
            set {
                willChangeValue(forKey: "isFinished")
                _finished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }

        private var _executing = false
        override var isExecuting: Bool{
            get { return _executing }
            set {
                willChangeValue(forKey: "isExecuting")
                _executing = newValue
                didChangeValue(forKey: "isExecuting")
            }
        }
        
        override func start() {
            // Initialize
            isExecuting = true
            isFinished = false
            
            self.laneValue(1)
            sleep(1)
            self.laneValue(2)
            
            isFinished = true
            isExecuting = false
        }
    }
    
    /// Test values
    func testEmitsValues() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true

        let op = TestValuesOperation()
            .lane("Test operation", filter: [.event], logger: recorder.log)
        
        op.start()
        
        XCTAssertEqual(recorder.logged.count, 3)
        guard recorder.logged.count == 3 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].signpostType, "event")
        XCTAssertEqual(recorder.logged[0].value, "1")
        XCTAssertEqual(recorder.logged[0].type, "Output")
        XCTAssertEqual(recorder.logged[1].signpostType, "event")
        XCTAssertEqual(recorder.logged[1].value, "2")
        XCTAssertEqual(recorder.logged[1].type, "Output")
        XCTAssertEqual(recorder.logged[2].signpostType, "event")
        XCTAssertEqual(recorder.logged[2].type, "Completed")
    }
    
    static var allTests = [
        ("testEmitsSubscription", testEmitsSubscription),
        ("testEmitsCancelled", testEmitsCancelled),
        ("testVanillaOperationQueue", testVanillaOperationQueue),
        ("testLaneOperationQueue", testLaneOperationQueue),
        ("testEmitsValues", testEmitsValues),
    ]
}

