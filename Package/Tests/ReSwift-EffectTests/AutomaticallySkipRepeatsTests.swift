//
//  AutomaticallySkipRepeatsTests.swift
//  ReSwift
//
//  Created by Daniel Martín Prieto on 03/11/2017.
//  Copyright © 2017 ReSwift Community. All rights reserved.
//
import Testing
@testable import ReSwiftEffect

private struct State {
    let age: Int
    let name: String
}

extension State: Equatable {
    static func == (lhs: State, rhs: State) -> Bool {
        return lhs.age == rhs.age && lhs.name == rhs.name
    }
}

private struct ChangeAge: Action {
    let newAge: Int
}

private let initialState = State(age: 29, name: "Daniel")

private func reducer(state: inout State, action: Action, environment: TestEnvironment) -> Task<Action, Error>? {
    switch action {
    case let changeAge as ChangeAge:
        state = State(age: changeAge.newAge, name: state.name)
    default:
        break
    }
    return nil
}

@MainActor
struct AutomaticallySkipRepeatsTests {
    
    class TestSubscriber: StoreSubscriber {
        var subscriptionUpdates: Int = 0
        
        func newState(state: String) {
            subscriptionUpdates += 1
        }
    }

    @Test("Initial subscription with regular substate selection")
    func testInitialSubscriptionWithRegularSubstateSelection() async throws {
        let environment = TestEnvironment()
        let store = Store<State, TestEnvironment>(reducer: reducer, state: initialState, environment: environment)
        let subscriber = TestSubscriber()
        
        store.subscribe(subscriber) { $0.select { $0.name } }
        
        #expect(subscriber.subscriptionUpdates == 1)
    }

    @Test("Initial subscription with key path")
    func testInitialSubscriptionWithKeyPath() async throws {
        let environment = TestEnvironment()
        let store = Store<State, TestEnvironment>(reducer: reducer, state: initialState, environment: environment)
        let subscriber = TestSubscriber()
        
        store.subscribe(subscriber) { $0.select(\.name) }
        
        #expect(subscriber.subscriptionUpdates == 1)
    }

    @Test("Dispatch unrelated action with explicit skipRepeats with regular substate selection")
    func testDispatchUnrelatedActionWithExplicitSkipRepeatsWithRegularSubstateSelection() async throws {
        let environment = TestEnvironment()
        let store = Store<State, TestEnvironment>(reducer: reducer, state: initialState, environment: environment)
        let subscriber = TestSubscriber()
        
        store.subscribe(subscriber) { $0.select { $0.name }.skipRepeats() }
        #expect(subscriber.subscriptionUpdates == 1)
        
        store.dispatch(ChangeAge(newAge: 30))
        #expect(subscriber.subscriptionUpdates == 1)
    }

    @Test("Dispatch unrelated action with explicit skipRepeats with key path")
    func testDispatchUnrelatedActionWithExplicitSkipRepeatsWithKeyPath() async throws {
        let environment = TestEnvironment()
        let store = Store<State, TestEnvironment>(reducer: reducer, state: initialState, environment: environment)
        let subscriber = TestSubscriber()
        
        store.subscribe(subscriber) { $0.select(\.name).skipRepeats() }
        #expect(subscriber.subscriptionUpdates == 1)
        
        store.dispatch(ChangeAge(newAge: 30))
        #expect(subscriber.subscriptionUpdates == 1)
    }

    @Test("Dispatch unrelated action without explicit skipRepeats with regular substate selection")
    func testDispatchUnrelatedActionWithoutExplicitSkipRepeatsWithRegularSubstateSelection() async throws {
        let environment = TestEnvironment()
        let store = Store<State, TestEnvironment>(reducer: reducer, state: initialState, environment: environment)
        let subscriber = TestSubscriber()
        
        store.subscribe(subscriber) { $0.select { $0.name } }
        #expect(subscriber.subscriptionUpdates == 1)
        
        store.dispatch(ChangeAge(newAge: 30))
        #expect(subscriber.subscriptionUpdates == 1)
    }

    @Test("Dispatch unrelated action without explicit skipRepeats with key path")
    func testDispatchUnrelatedActionWithoutExplicitSkipRepeatsWithKeyPath() async throws {
        let environment = TestEnvironment()
        let store = Store<State, TestEnvironment>(reducer: reducer, state: initialState, environment: environment)
        let subscriber = TestSubscriber()
        
        store.subscribe(subscriber) { $0.select(\.name) }
        #expect(subscriber.subscriptionUpdates == 1)
        
        store.dispatch(ChangeAge(newAge: 30))
        #expect(subscriber.subscriptionUpdates == 1)
    }
}
