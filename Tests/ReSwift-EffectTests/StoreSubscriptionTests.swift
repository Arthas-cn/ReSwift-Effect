//
//  StoreSubscriptionTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 11/27/15.
//  Copyright © 2015 ReSwift Community. All rights reserved.
//

import Testing
import Foundation
/**
 @testable import for testing of `Store.subscriptions`
 */
@testable import ReSwiftEffect

@MainActor
struct StoreSubscriptionTests {
    typealias TestSubscriber = TestStoreSubscriber<TestAppState>

    /**
     It does not strongly capture an observer
     */
    @Test("Does not strongly capture an observer")
    func testDoesNotCaptureStrongly() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        var subscriber: TestSubscriber? = TestSubscriber()

        store.subscribe(subscriber!)
        #expect(store.subscriptions.compactMap({ $0.subscriber }).count == 1)
        // Ensure `subscriber` is accessed at least once to prevent it being optimised
        // away when tests are built using 'release' scheme. #459 refers.
        #expect(subscriber != nil)

        subscriber = nil
        #expect(store.subscriptions.compactMap({ $0.subscriber }).count == 0)
    }

    /**
     it removes deferenced subscribers before notifying state changes
     */
    @Test("Removes dereferenced subscribers before notifying state changes")
    func testRemoveSubscribers() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        var subscriber1: TestSubscriber? = TestSubscriber()
        var subscriber2: TestSubscriber? = TestSubscriber()

        store.subscribe(subscriber1!)
        store.subscribe(subscriber2!)
        store.dispatch(SetValueAction(3))
        #expect(store.subscriptions.count == 2)
        #expect(subscriber1?.receivedStates.last?.testValue == 3)
        #expect(subscriber2?.receivedStates.last?.testValue == 3)

        subscriber1 = nil
        store.dispatch(SetValueAction(5))
        #expect(store.subscriptions.count == 1)
        #expect(subscriber2?.receivedStates.last?.testValue == 5)

        subscriber2 = nil
        store.dispatch(SetValueAction(8))
        #expect(store.subscriptions.count == 0)
    }

    /**
     it replaces the subscription of an existing subscriber with the new one.
     */
    @Test("Replaces subscription of existing subscriber with new one")
    func testDuplicateSubscription() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = TestSubscriber()

        // Initial subscription.
        store.subscribe(subscriber)
        // Subsequent subscription that skips repeated updates.
        store.subscribe(subscriber) { $0.skipRepeats { $0.testValue == $1.testValue } }

        // One initial state update for every subscription.
        #expect(subscriber.receivedStates.count == 2)

        store.dispatch(SetValueAction(3))
        store.dispatch(SetValueAction(3))
        store.dispatch(SetValueAction(3))
        store.dispatch(SetValueAction(3))

        // Only a single further state update, since latest subscription skips repeated values.
        #expect(subscriber.receivedStates.count == 3)
    }

    /**
     it dispatches initial value upon subscription
     */
    @Test("Dispatches initial value upon subscription")
    func testDispatchInitialValue() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(testValue: 7), environment: environment)
        let subscriber = TestSubscriber()

        store.subscribe(subscriber)

        #expect(subscriber.receivedStates.map(\.testValue) == [7])
    }

    /**
     it dispatches initial value upon subscription and subsequent state changes
     */
    @Test("Dispatches initial value and subsequent state changes")
    func testDispatchStateChanges() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = TestSubscriber()

        store.subscribe(subscriber)
        store.dispatch(SetValueAction(9))

        #expect(subscriber.receivedStates.map(\.testValue) == [nil, 9])
    }

    /**
     it dispatches initial value upon subscription and subsequent state changes
     */
    @Test("Dispatches initial state after state change")
    func testDispatchInitialStateAfterStateChange() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = TestSubscriber()

        // Change state first ...
        store.dispatch(SetValueAction(13))
        // ... and then subscribe to receive the current state.
        store.subscribe(subscriber)

        #expect(subscriber.receivedStates.map(\.testValue) == [13])
    }

    /**
     it allows dispatching from within an observer
     */
    @Test("Allows dispatching from within an observer")
    func testAllowDispatchWithinObserver() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = DispatchingSubscriber(store: store)

        store.subscribe(subscriber)
        store.dispatch(SetValueAction(2))

        #expect(store.state.testValue == 5)
    }

    /**
     it does not dispatch value after subscriber unsubscribes
     */
    @Test("Does not dispatch value after subscriber unsubscribes")
    func testDontDispatchToUnsubscribers() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = TestSubscriber()

        store.dispatch(SetValueAction(5))
        store.subscribe(subscriber)
        store.dispatch(SetValueAction(10))

        store.unsubscribe(subscriber)
        // Following value is missed due to not being subscribed:
        store.dispatch(SetValueAction(15))
        store.dispatch(SetValueAction(25))

        store.subscribe(subscriber)

        store.dispatch(SetValueAction(20))

        #expect(subscriber.receivedStates.count == 4)
        #expect(subscriber.receivedStates[subscriber.receivedStates.count - 4].testValue == 5)
        #expect(subscriber.receivedStates[subscriber.receivedStates.count - 3].testValue == 10)
        #expect(subscriber.receivedStates[subscriber.receivedStates.count - 2].testValue == 25)
        #expect(subscriber.receivedStates[subscriber.receivedStates.count - 1].testValue == 20)
    }

    /**
     it ignores identical subscribers
     */
    @Test("Ignores identical subscribers")
    func testIgnoreIdenticalSubscribers() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = TestSubscriber()

        store.subscribe(subscriber)
        store.subscribe(subscriber)

        #expect(store.subscriptions.count == 1)
    }

    /**
     it ignores identical subscribers that provide substate selectors
     */
    @Test("Ignores identical substate subscribers")
    func testIgnoreIdenticalSubstateSubscribers() async throws {
        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
        let subscriber = TestSubscriber()

        store.subscribe(subscriber) { $0 }
        store.subscribe(subscriber) { $0 }

        #expect(store.subscriptions.count == 1)
    }

    @Test("New state modifying subscriptions does not discard new subscription")
    func testNewStateModifyingSubscriptionsDoesNotDiscardNewSubscription() async throws {
        // This was built as a failing test due to a bug introduced by #325
        // The bug occured by adding a subscriber during `newState`
        // The bug was caused by creating a copy of `subscriptions` before calling
        // `newState`, and then assigning that copy back to `subscriptions`, losing
        // the mutation that occured during `newState`

        let reducer = TestReducer()
        let environment = TestEnvironment()
        let store = Store(reducer: reducer.handleAction, state: TestAppState(), environment: environment)

        let subscriber2 = BlockSubscriber<TestAppState> { _ in
            store.dispatch(SetValueAction(2))
        }

        let subscriber1 = BlockSubscriber<TestAppState> { state in
            if state.testValue == 1 {
                store.subscribe(subscriber2) {
                    $0.skip(when: { _, _ in return true })
                }
            }
        }

        store.subscribe(subscriber1) {
            $0.only(when: { _, new in new.testValue.map { $0 == 1 } ?? false })
        }

        store.dispatch(SetValueAction(1))

        #expect(store.subscriptions.contains(where: {
            guard let subscriber = $0.subscriber else {
                return false
            }
            return subscriber === subscriber1
        }))
        #expect(store.subscriptions.contains(where: {
            guard let subscriber = $0.subscriber else {
                return false
            }
            return subscriber === subscriber2
        }))
    }
}

// MARK: Retain Cycle Detection

private struct TracerAction: Action { }

// Helper actor to track deinit in a Sendable-compatible way
private actor DeinitFlag {
    private var _value = false
    
    var value: Bool {
        get { _value }
    }
    
    func set() {
        _value = true
    }
}

private class TestSubscriptionBox<S>: SubscriptionBox<S> {
    override init<T>(
        originalSubscription: Subscription<S>,
        transformedSubscription: Subscription<T>?,
        subscriber: AnyStoreSubscriber
        ) {
        super.init(originalSubscription: originalSubscription,
                   transformedSubscription: transformedSubscription,
                   subscriber: subscriber)
    }

    var didDeinit: (@Sendable () -> Void)?
    deinit {
        didDeinit?()
    }
}

private class TestStore<State, Environment>: Store<State, Environment> {
    override func subscriptionBox<T>(
        originalSubscription: Subscription<State>,
        transformedSubscription: Subscription<T>?,
        subscriber: AnyStoreSubscriber) -> SubscriptionBox<State> {
        return TestSubscriptionBox(
            originalSubscription: originalSubscription,
            transformedSubscription: transformedSubscription,
            subscriber: subscriber
        )
    }
}

extension StoreSubscriptionTests {
    @Test("Retain cycle - original subscription")
    func testRetainCycle_OriginalSubscription() async throws {
        let didDeinit = DeinitFlag()

        autoreleasepool {
            let reducer = TestReducer()
            let environment = TestEnvironment()
            let store = TestStore(reducer: reducer.handleAction, state: TestAppState(), environment: environment)
            let subscriber: TestSubscriber = TestSubscriber()

            // Preconditions
            #expect(subscriber.receivedStates.count == 0)
            #expect(store.subscriptions.count == 0)

            autoreleasepool {
                store.subscribe(subscriber)
                #expect(subscriber.receivedStates.count == 1)
                let subscriptionBox = store.subscriptions.first! as! TestSubscriptionBox<TestAppState>
                subscriptionBox.didDeinit = { 
                    Task { await didDeinit.set() }
                }

                store.dispatch(TracerAction())
                #expect(subscriber.receivedStates.count == 2)
                store.unsubscribe(subscriber)
            }

            #expect(store.subscriptions.count == 0)
            store.dispatch(TracerAction())
            #expect(subscriber.receivedStates.count == 2)
        }

        // Wait a bit for the async Task to complete
        try? await Task.sleep(for: .milliseconds(10))
        let value = await didDeinit.value
        #expect(value == true)
    }

    @Test("Retain cycle - transformed subscription")
    func testRetainCycle_TransformedSubscription() async throws {
        let didDeinit = DeinitFlag()

        autoreleasepool {
            let reducer = TestReducer()
            let environment = TestEnvironment()
            let store = TestStore(reducer: reducer.handleAction, state: TestAppState(), environment: environment, automaticallySkipsRepeats: false)
            let subscriber = TestStoreSubscriber<Int?>()

            // Preconditions
            #expect(subscriber.receivedStates.count == 0)
            #expect(store.subscriptions.count == 0)

            autoreleasepool {
                store.subscribe(subscriber, transform: {
                    $0.select { $0.testValue }
                })
                #expect(subscriber.receivedStates.count == 1)
                let subscriptionBox = store.subscriptions.first! as! TestSubscriptionBox<TestAppState>
                subscriptionBox.didDeinit = { 
                    Task { await didDeinit.set() }
                }

                store.dispatch(TracerAction())
                #expect(subscriber.receivedStates.count == 2)
                store.unsubscribe(subscriber)
            }

            #expect(store.subscriptions.count == 0)
            store.dispatch(TracerAction())
            #expect(subscriber.receivedStates.count == 2)
        }

        // Wait a bit for the async Task to complete
        try? await Task.sleep(for: .milliseconds(10))
        let value = await didDeinit.value
        #expect(value == true)
    }
}
