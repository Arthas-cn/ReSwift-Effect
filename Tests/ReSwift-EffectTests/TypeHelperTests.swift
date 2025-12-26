//
//  TypeHelperTests.swift
//  ReSwift
//
//  Created by Benjamin Encz on 12/20/15.
//  Copyright © 2015 ReSwift Community. All rights reserved.
//

import Testing
/**
 @testable import for testing of `withSpecificTypes`
 */
@testable import ReSwiftEffect

struct AppState1 {}
struct AppState2 {}

struct TypeHelperTests {
    /**
     it calls methods if the source type can be casted into the function signature type
     */
    @Test("Calls method if source type can be casted to function signature type")
    func testSourceTypeCasting() async throws {
        var called = false
        let reducerFunction: (Action, AppState1?) -> AppState1 = { action, state in
            called = true
            return state ?? AppState1()
        }

        withSpecificTypes(NoOpAction(), state: AppState1(), function: reducerFunction)

        #expect(called == true)
    }

    /**
     it calls the method if the source type is nil
     */
    @Test("Calls method if source type is nil")
    func testCallsIfSourceTypeIsNil() async throws {
        var called = false
        let reducerFunction: (Action, AppState1?) -> AppState1 = { action, state in
            called = true
            return state ?? AppState1()
        }

        withSpecificTypes(NoOpAction(), state: nil, function: reducerFunction)

        #expect(called == true)
    }

    /**
     it doesn't call if source type can't be casted to function signature type
     */
    @Test("Doesn't call if source type can't be casted to function signature type")
    func testDoesntCallIfCastFails() async throws {
        var called = false
        let reducerFunction: (Action, AppState1?) -> AppState1 = { action, state in
            called = true
            return state ?? AppState1()
        }

        withSpecificTypes(NoOpAction(), state: AppState2(), function: reducerFunction)

        #expect(called == false)
    }
}
