//  Copyright © 2019 ReSwift Community. All rights reserved.

import Testing
@testable import ReSwiftEffect

@MainActor
struct PerformanceTests {
    struct MockState {}
    struct MockAction: Action {}
    struct MockEnvironment {}
    
    class MockSubscriber: StoreSubscriber {
        func newState(state: MockState) {
            // Do nothing
        }
    }
    
    @Test("Test notify performance with 3000 subscribers")
    func testNotify() async throws {
        let subscribers = (0..<3000).map { _ in MockSubscriber() }
        let environment = MockEnvironment()
        let store = Store<MockState, MockEnvironment>(
            reducer: { state, action, environment in
                // Simple reducer that does nothing
                return nil
            },
            state: MockState(),
            environment: environment,
            automaticallySkipsRepeats: false
        )
        
        // Subscribe all subscribers
        for subscriber in subscribers {
            store.subscribe(subscriber)
        }
        
        // Measure dispatch performance
        let clock = ContinuousClock()
        let startTime = clock.now
        
        for _ in 0..<100 {
            store.dispatch(MockAction())
        }
        
        let elapsed = clock.now - startTime
        let averageTime = elapsed / 100
        
        // Verify that dispatch completed (basic sanity check)
        #expect(elapsed > .zero)
        
        // Log performance metrics
        print("Average dispatch time: \(averageTime)")
    }
    
    @Test("Test subscribe performance with 3000 subscribers")
    func testSubscribe() async throws {
        let subscribers = (0..<3000).map { _ in MockSubscriber() }
        let environment = MockEnvironment()
        let store = Store<MockState, MockEnvironment>(
            reducer: { state, action, environment in
                // Simple reducer that does nothing
                return nil
            },
            state: MockState(),
            environment: environment,
            automaticallySkipsRepeats: false
        )
        
        // Measure subscribe performance
        let clock = ContinuousClock()
        let startTime = clock.now
        
        for subscriber in subscribers {
            store.subscribe(subscriber)
        }
        
        let elapsed = clock.now - startTime
        
        // Verify that subscribe completed
        #expect(elapsed > .zero)
        
        // Log performance metrics
        print("Total subscribe time for 3000 subscribers: \(elapsed)")
    }
}
