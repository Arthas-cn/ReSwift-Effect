//
//  StoreTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 11/27/15.
//  Copyright © 2015 ReSwift Community. All rights reserved.
//

import Testing
import Foundation
@testable import ReSwiftEffect

// Thread-safe counter for testing deinitialization
// Uses actor for true Swift 6.0 concurrency safety
actor CounterActor {
    private var _value: Int = 0
    
    var value: Int {
        _value
    }
    
    func increment() {
        _value += 1
    }
}

@MainActor
struct StoreTests {
    /**
     it dispatches an Init action when it doesn't receive an initial state
     */
//    @Test("Dispatches Init action when no initial state provided")
//    func testInit() async throws {
//        let reducer = MockReducer()
//        let environment = TestEnvironment()
//        _ = Store<CounterState, TestEnvironment>(reducer: reducer.handleAction, state: nil, environment: environment)
//
//        #expect(reducer.calledWithAction[0] is ReSwiftInit)
//    }

    /**
     it deinitializes when no reference is held
     */
    @Test("Deinitializes when no reference is held")
    func testDeinit() async throws {
        let deInitCount = CounterActor()

        autoreleasepool {
            let reducer = TestReducer()
            let environment = TestEnvironment()
            _ = DeInitStore<TestAppState, TestEnvironment>(
                reducer: reducer.handleAction,
                state: TestAppState(),
                environment: environment,
                deInitAction: { 
                    // Use Task.detached to call actor method from deinit
                    Task.detached { await deInitCount.increment() }
                })
        }

        // Wait a short time for deinit and async increment to complete
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        let count = await deInitCount.value
        #expect(count == 1)
    }
}

// Used for deinitialization test
class DeInitStore<State, Environment>: Store<State, Environment> {
    var deInitAction: (@Sendable () -> Void)?

    deinit {
        deInitAction?()
    }

    required convenience init(
        reducer: @escaping Reducer<State, Environment>,
        state: State?,
        environment: Environment,
        deInitAction: (@Sendable () -> Void)?) {
            self.init(
                reducer: reducer,
                state: state,
                environment: environment,
                middleware: [],
                automaticallySkipsRepeats: false)
            self.deInitAction = deInitAction
    }

    required init(
        reducer: @escaping Reducer<State, Environment>,
        state: State?,
        environment: Environment,
        middleware: [Middleware<State>],
        automaticallySkipsRepeats: Bool) {
            super.init(
                reducer: reducer,
                state: state,
                environment: environment,
                middleware: middleware,
                automaticallySkipsRepeats: automaticallySkipsRepeats)
    }
}

struct CounterState {
    var count: Int = 0
}

class MockReducer {
    var calledWithAction: [Action] = []

    func handleAction(state: inout CounterState, action: Action, environment: TestEnvironment) -> Task<Action, Error>? {
        calledWithAction.append(action)
        
        if state.count == 0 && calledWithAction.count == 1 {
            // Initialize state if needed
            state = CounterState()
        }

        return nil
    }
}
