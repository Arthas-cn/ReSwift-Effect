//
//  StoreMiddlewareTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 12/24/15.
//  Copyright © 2015 ReSwift Community. All rights reserved.
//

import Testing
import Foundation
@testable import ReSwiftEffect

nonisolated(unsafe) let firstMiddleware: Middleware<Any> = { dispatch, getState in
    return { next in
        return { action in
            if var action = action as? SetValueStringAction {
                action.value += " First Middleware"
                next(action)
            } else {
                next(action)
            }
        }
    }
}

nonisolated(unsafe) let secondMiddleware: Middleware<Any> = { dispatch, getState in
    return { next in
        return { action in
            if var action = action as? SetValueStringAction {
                action.value += " Second Middleware"
                next(action)
            } else {
                next(action)
            }
        }
    }
}

nonisolated(unsafe) let dispatchingMiddleware: Middleware<Any> = { dispatch, getState in
    return { next in
        return { action in
            if var action = action as? SetValueAction {
                dispatch(SetValueStringAction("\(action.value ?? 0)"))
            }
            next(action)
        }
    }
}

nonisolated(unsafe) let stateAccessingMiddleware: Middleware<TestStringAppState> = { dispatch, getState in
    return { next in
        return { action in
            let appState = getState()
            let stringAction = action as? SetValueStringAction

            // avoid endless recursion by checking if we've dispatched exactly this action
            if appState?.testValue == "OK" && stringAction?.value != "Not OK" {
                // dispatch a new action
                dispatch(SetValueStringAction("Not OK"))
                // and swallow the current one
                next(NoOpAction())
            } else {
                next(action)
            }
        }
    }
}

func middleware(executing block: @escaping () -> Void) -> Middleware<Any> {
    return { dispatch, getState in
        return { next in
            return { action in
                block()
            }
        }
    }
}

@MainActor
struct StoreMiddlewareTests {
    /**
     it can decorate dispatch function
     */
    @Test("Can decorate dispatch function")
    func testDecorateDispatch() async throws {
        let reducer = TestValueStringReducer()
        // Swift 4.1 fails to cast this from Middleware<StateType> to Middleware<TestStringAppState>
        // as expected during runtime, see: <https://bugs.swift.org/browse/SR-7362>
        let middleware: [Middleware<TestStringAppState>] = [
            firstMiddleware,
            secondMiddleware
        ]
        let environment = TestEnvironment()
        let store = Store<TestStringAppState, TestEnvironment>(
            reducer: reducer.handleAction,
            state: TestStringAppState(),
            environment: environment,
            middleware: middleware)

        let subscriber = TestStoreSubscriber<TestStringAppState>()
        store.subscribe(subscriber)

        let action = SetValueStringAction("OK")
        store.dispatch(action)

        #expect(store.state.testValue == "OK First Middleware Second Middleware")
    }

    /**
     it can dispatch actions
     */
    @Test("Can dispatch actions")
    func testCanDispatch() async throws {
        let reducer = TestValueStringReducer()
        // Swift 4.1 fails to cast this from Middleware<StateType> to Middleware<TestStringAppState>
        // as expected during runtime, see: <https://bugs.swift.org/browse/SR-7362>
        let middleware: [Middleware<TestStringAppState>] = [
            firstMiddleware,
            secondMiddleware,
            dispatchingMiddleware
        ]
        let environment = TestEnvironment()
        let store = Store<TestStringAppState, TestEnvironment>(
            reducer: reducer.handleAction,
            state: TestStringAppState(),
            environment: environment,
            middleware: middleware)

        let subscriber = TestStoreSubscriber<TestStringAppState>()
        store.subscribe(subscriber)

        let action = SetValueAction(10)
        store.dispatch(action)

        #expect(store.state.testValue == "10 First Middleware Second Middleware")
    }

    /**
     it middleware can access the store's state
     */
    @Test("Middleware can access the store's state")
    func testMiddlewareCanAccessState() async throws {
        let reducer = TestValueStringReducer()
        var state = TestStringAppState()
        state.testValue = "OK"

        let environment = TestEnvironment()
        let store = Store<TestStringAppState, TestEnvironment>(
            reducer: reducer.handleAction,
            state: state,
            environment: environment,
            middleware: [stateAccessingMiddleware])

        store.dispatch(SetValueStringAction("Action That Won't Go Through"))

        #expect(store.state.testValue == "Not OK")
    }

    @Test("Can mutate middleware after init")
    func testCanMutateMiddlewareAfterInit() async throws {
        let reducer = TestValueStringReducer()
        let state = TestStringAppState()
        let environment = TestEnvironment()
        let store = Store<TestStringAppState, TestEnvironment>(
            reducer: reducer.handleAction,
            state: state,
            environment: environment,
            middleware: [])

        // Adding
        var added = false
        store.middleware.append(middleware(executing: { added = true }))
        store.dispatch(SetValueStringAction(""))
        #expect(added == true)

        // Removing
        added = false
        store.middleware = []
        store.dispatch(SetValueStringAction(""))
        #expect(added == false)
    }
}
