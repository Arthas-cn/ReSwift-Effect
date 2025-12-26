//
//  StoreSubscriberTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 1/23/16.
//  Copyright © 2016 ReSwift Community. All rights reserved.
//

import Testing
@testable import ReSwiftEffect

@MainActor
struct StoreSubscriberTests {
    /**
     it allows to pass a state selector closure
     */
    @Test("Allows to pass a state selector closure")
    func testAllowsSelectorClosure() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = TestFilteredSubscriber<Int?>()

        store.subscribe(subscriber) {
            $0.select { $0.testValue }
        }

        store.dispatch(SetValueAction(3))

        #expect(subscriber.receivedValue == 3)

        store.dispatch(SetValueAction(nil))

        #expect(subscriber.receivedValue == .some(.none))
    }

    /**
     it allows to pass a state selector key path
     */
    @Test("Allows to pass a state selector key path")
    func testAllowsSelectorKeyPath() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = TestFilteredSubscriber<Int?>()

        store.subscribe(subscriber) {
            $0.select(\.testValue)
        }

        store.dispatch(SetValueAction(3))

        #expect(subscriber.receivedValue == 3)

        store.dispatch(SetValueAction(nil))

        #expect(subscriber.receivedValue == .some(.none))
    }

    /**
     it supports complex state selector closures
     */
    @Test("Supports complex state selector closures")
    func testComplexStateSelector() async throws {
        let reducer = TestComplexAppStateReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestComplexAppState(), environment: environment)
        let subscriber = TestSelectiveSubscriber()

        store.subscribe(subscriber) {
            $0.select {
                ($0.testValue, $0.otherState?.name)
            }
        }
        store.dispatch(SetValueAction(5))
        store.dispatch(SetOtherStateAction(
            otherState: OtherState(name: "TestName", age: 99)
        ))

        #expect(subscriber.receivedValue.0 == 5)
        #expect(subscriber.receivedValue.1 == "TestName")
    }

    /**
     it does not notify subscriber for unchanged substate state when using `skipRepeats`.
     */
    @Test("Does not notify subscriber for unchanged substate with regular substate selection")
    func testUnchangedStateWithRegularSubstateSelection() async throws {
        let reducer = TestReducer()
        var state = TestAppState()
        state.testValue = 3
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<Int?>()

        store.subscribe(subscriber) {
            $0
            .select { $0.testValue }
            .skipRepeats { $0 == $1 }
        }

        #expect(subscriber.receivedValue == 3)

        store.dispatch(SetValueAction(3))

        #expect(subscriber.receivedValue == 3)
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Does not notify subscriber for unchanged substate with key path")
    func testUnchangedStateWithKeyPath() async throws {
        let reducer = TestReducer()
        var state = TestAppState()
        state.testValue = 3
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<Int?>()

        store.subscribe(subscriber) {
            $0
            .select(\.testValue)
            .skipRepeats { $0 == $1 }
        }

        #expect(subscriber.receivedValue == 3)

        store.dispatch(SetValueAction(3))

        #expect(subscriber.receivedValue == 3)
        #expect(subscriber.newStateCallCount == 1)
    }

    /**
     it does not notify subscriber for unchanged substate state when using the default
     `skipRepeats` implementation.
     */
    @Test("Does not notify subscriber for unchanged substate with default skipRepeats and regular substate selection")
    func testUnchangedStateDefaultSkipRepeatsWithRegularSubstateSelection() async throws {
        let reducer = TestValueStringReducer()
        let state = TestStringAppState()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<String>()

        store.subscribe(subscriber) {
            $0
            .select { $0.testValue }
            .skipRepeats()
        }

        #expect(subscriber.receivedValue == "Initial")

        store.dispatch(SetValueStringAction("Initial"))

        #expect(subscriber.receivedValue == "Initial")
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Does not notify subscriber for unchanged substate with default skipRepeats and key path")
    func testUnchangedStateDefaultSkipRepeatsWithKeyPath() async throws {
        let reducer = TestValueStringReducer()
        let state = TestStringAppState()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<String>()

        store.subscribe(subscriber) {
            $0
            .select(\.testValue)
            .skipRepeats()
        }

        #expect(subscriber.receivedValue == "Initial")

        store.dispatch(SetValueStringAction("Initial"))

        #expect(subscriber.receivedValue == "Initial")
        #expect(subscriber.newStateCallCount == 1)
    }

    /**
     it skips repeated state values by when `skipRepeats` returns `true`.
     */
    @Test("Skips state updates for custom equality checks with regular substate selection")
    func testSkipsStateUpdatesForCustomEqualityChecksWithRegularSubstateSelection() async throws {
        let reducer = TestCustomAppStateReducer()
        let state = TestCustomAppState(substateValue: 5)
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<TestCustomAppState.TestCustomSubstate>()

        store.subscribe(subscriber) {
            $0
            .select { $0.substate }
            .skipRepeats { $0.value == $1.value }
        }

        #expect(subscriber.receivedValue.value == 5)

        store.dispatch(SetCustomSubstateAction(5))

        #expect(subscriber.receivedValue.value == 5)
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Skips state updates for custom equality checks with key path")
    func testSkipsStateUpdatesForCustomEqualityChecksWithKeyPath() async throws {
        let reducer = TestCustomAppStateReducer()
        let state = TestCustomAppState(substateValue: 5)
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<TestCustomAppState.TestCustomSubstate>()

        store.subscribe(subscriber) {
            $0
            .select(\.substate)
            .skipRepeats { $0.value == $1.value }
        }

        #expect(subscriber.receivedValue.value == 5)

        store.dispatch(SetCustomSubstateAction(5))

        #expect(subscriber.receivedValue.value == 5)
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Passes on duplicate substate updates by default with regular substate selection")
    func testPassesOnDuplicateSubstateUpdatesByDefaultWithRegularSubstateSelection() async throws {
        let reducer = TestNonEquatableReducer()
        let state = TestNonEquatable()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<NonEquatable>()

        store.subscribe(subscriber) {
            $0.select { $0.testValue }
        }

        #expect(subscriber.receivedValue.testValue == "Initial")

        store.dispatch(SetNonEquatableAction(NonEquatable()))

        #expect(subscriber.receivedValue.testValue == "Initial")
        #expect(subscriber.newStateCallCount == 2)
    }

    @Test("Passes on duplicate substate updates by default with key path")
    func testPassesOnDuplicateSubstateUpdatesByDefaultWithKeyPath() async throws {
        let reducer = TestNonEquatableReducer()
        let state = TestNonEquatable()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<NonEquatable>()

        store.subscribe(subscriber) {
            $0.select(\.testValue)
        }

        #expect(subscriber.receivedValue.testValue == "Initial")

        store.dispatch(SetNonEquatableAction(NonEquatable()))

        #expect(subscriber.receivedValue.testValue == "Initial")
        #expect(subscriber.newStateCallCount == 2)
    }

    @Test("Passes on duplicate substate when skips false with regular substate selection")
    func testPassesOnDuplicateSubstateWhenSkipsFalseWithRegularSubstateSelection() async throws {
        let reducer = TestValueStringReducer()
        let state = TestStringAppState()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment, middleware: [], automaticallySkipsRepeats: false)
        let subscriber = TestFilteredSubscriber<String>()

        store.subscribe(subscriber) {
            $0.select { $0.testValue }
        }

        #expect(subscriber.receivedValue == "Initial")

        store.dispatch(SetValueStringAction("Initial"))

        #expect(subscriber.receivedValue == "Initial")
        #expect(subscriber.newStateCallCount == 2)
    }

    @Test("Passes on duplicate substate when skips false with key path")
    func testPassesOnDuplicateSubstateWhenSkipsFalseWithKeyPath() async throws {
        let reducer = TestValueStringReducer()
        let state = TestStringAppState()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment, middleware: [], automaticallySkipsRepeats: false)
        let subscriber = TestFilteredSubscriber<String>()

        store.subscribe(subscriber) {
            $0.select(\.testValue)
        }

        #expect(subscriber.receivedValue == "Initial")

        store.dispatch(SetValueStringAction("Initial"))

        #expect(subscriber.receivedValue == "Initial")
        #expect(subscriber.newStateCallCount == 2)
    }

    @Test("Skips state updates for equatable state by default")
    func testSkipsStateUpdatesForEquatableStateByDefault() async throws {
        let reducer = TestValueStringReducer()
        let state = TestStringAppState()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment, middleware: [])
        let subscriber = TestFilteredSubscriber<TestStringAppState>()

        store.subscribe(subscriber)

        #expect(subscriber.receivedValue.testValue == "Initial")

        store.dispatch(SetValueStringAction("Initial"))

        #expect(subscriber.receivedValue.testValue == "Initial")
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Skips state updates for equatable substate by default with regular substate selection")
    func testSkipsStateUpdatesForEquatableSubStateByDefaultWithRegularSubstateSelection() async throws {
        let reducer = TestNonEquatableReducer()
        let state = TestNonEquatable()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<String>()

        store.subscribe(subscriber) {
            $0.select { $0.testValue.testValue }
        }

        #expect(subscriber.receivedValue == "Initial")

        store.dispatch(SetValueStringAction("Initial"))

        #expect(subscriber.receivedValue == "Initial")
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Skips state updates for equatable substate by default with key path on generic store type")
    func testSkipsStateUpdatesForEquatableSubStateByDefaultWithKeyPathOnGenericStoreType() async throws {
        let reducer = TestNonEquatableReducer()
        let state = TestNonEquatable()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)

        func runTests<S: StoreType>(store: S) where S.State == TestNonEquatable {
            let subscriber = TestFilteredSubscriber<String>()

            store.subscribe(subscriber) {
                $0.select(\.testValue.testValue)
            }

            #expect(subscriber.receivedValue == "Initial")

            store.dispatch(SetValueStringAction("Initial"))

            #expect(subscriber.receivedValue == "Initial")
            #expect(subscriber.newStateCallCount == 1)
        }

        runTests(store: store)
    }

    @Test("Skips state updates for equatable substate by default with key path")
    func testSkipsStateUpdatesForEquatableSubStateByDefaultWithKeyPath() async throws {
        let reducer = TestNonEquatableReducer()
        let state = TestNonEquatable()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<String>()

        store.subscribe(subscriber) {
            $0.select(\.testValue.testValue)
        }

        #expect(subscriber.receivedValue == "Initial")

        store.dispatch(SetValueStringAction("Initial"))

        #expect(subscriber.receivedValue == "Initial")
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Passes on duplicate state updates in customized store")
    func testPassesOnDuplicateStateUpdatesInCustomizedStore() async throws {
        let reducer = TestValueStringReducer()
        let state = TestStringAppState()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment, middleware: [], automaticallySkipsRepeats: false)
        let subscriber = TestFilteredSubscriber<TestStringAppState>()

        store.subscribe(subscriber)

        #expect(subscriber.receivedValue.testValue == "Initial")

        store.dispatch(SetValueStringAction("Initial"))

        #expect(subscriber.receivedValue.testValue == "Initial")
        #expect(subscriber.newStateCallCount == 2)
    }

    @Test("Skip when with regular substate selection")
    func testSkipWhenWithRegularSubstateSelection() async throws {
        let reducer = TestCustomAppStateReducer()
        let state = TestCustomAppState(substateValue: 5)
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<TestCustomAppState.TestCustomSubstate>()

        store.subscribe(subscriber) {
            $0
            .select { $0.substate }
            .skip { $0.value == $1.value }
        }

        #expect(subscriber.receivedValue.value == 5)

        store.dispatch(SetCustomSubstateAction(5))

        #expect(subscriber.receivedValue.value == 5)
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Skip when with key path")
    func testSkipWhenWithKeyPath() async throws {
        let reducer = TestCustomAppStateReducer()
        let state = TestCustomAppState(substateValue: 5)
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<TestCustomAppState.TestCustomSubstate>()

        store.subscribe(subscriber) {
            $0
            .select(\.substate)
            .skip { $0.value == $1.value }
        }

        #expect(subscriber.receivedValue.value == 5)

        store.dispatch(SetCustomSubstateAction(5))

        #expect(subscriber.receivedValue.value == 5)
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Only when with regular substate selection")
    func testOnlyWhenWithRegularSubstateSelection() async throws {
        let reducer = TestCustomAppStateReducer()
        let state = TestCustomAppState(substateValue: 5)
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<TestCustomAppState.TestCustomSubstate>()

        store.subscribe(subscriber) {
            $0
            .select { $0.substate }
            .only { $0.value != $1.value }
        }

        #expect(subscriber.receivedValue.value == 5)

        store.dispatch(SetCustomSubstateAction(5))

        #expect(subscriber.receivedValue.value == 5)
        #expect(subscriber.newStateCallCount == 1)
    }

    @Test("Only when with key path")
    func testOnlyWhenWithKeyPath() async throws {
        let reducer = TestCustomAppStateReducer()
        let state = TestCustomAppState(substateValue: 5)
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: state, environment: environment)
        let subscriber = TestFilteredSubscriber<TestCustomAppState.TestCustomSubstate>()

        store.subscribe(subscriber) {
            $0
            .select(\.substate)
            .only { $0.value != $1.value }
        }

        #expect(subscriber.receivedValue.value == 5)

        store.dispatch(SetCustomSubstateAction(5))

        #expect(subscriber.receivedValue.value == 5)
        #expect(subscriber.newStateCallCount == 1)
    }
}

class TestFilteredSubscriber<T>: StoreSubscriber {
    var receivedValue: T!
    var newStateCallCount = 0

    func newState(state: T) {
        receivedValue = state
        newStateCallCount += 1
    }
}

/**
 Example of how you can select a substate. The return value from
 `selectSubstate` and the argument for `newState` need to match up.
 */
class TestSelectiveSubscriber: StoreSubscriber {
    var receivedValue: (Int?, String?)

    func newState(state: (Int?, String?)) {
        receivedValue = state
    }
}

struct TestComplexAppState {
    var testValue: Int?
    var otherState: OtherState?
}

struct OtherState {
    var name: String?
    var age: Int?
}

struct TestComplexAppStateReducer {
    func handleAction(state: inout TestComplexAppState, action: Action, environment: TestEnvironment) -> Task<Action, Error>? {
        switch action {
        case let action as SetValueAction:
            state.testValue = action.value
        case let action as SetOtherStateAction:
            state.otherState = action.otherState
        default:
            break
        }
        return nil
    }
}

struct SetOtherStateAction: Action {
    var otherState: OtherState
}
