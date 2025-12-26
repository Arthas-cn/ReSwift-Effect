//
//  SynchronizedTests.swift
//  ReSwift
//
//  Created by Basem Emara on 2020-08-18.
//  Copyright © 2020 ReSwift Community. All rights reserved.
//

import Testing
/**
 @testable import for testing of `Utils.Synchronized`
 */
@testable import ReSwiftEffect

struct SynchronizedTests {
    private let iterations = 100 // 1_000_000
    private let writeMultipleOf = 10 // 1000
    
    private actor Database {
        static let shared = Database()
        private var data = Synchronized<[String: Bool]>([:])
        func get(key: String) -> Bool? {
            return data.value { $0[key] }
        }
        func set(key: String, value: Bool) {
            data.value { $0[key] = value }
        }
    }
    
    private actor Counter {
        private var temp = Synchronized<Int>(0)
        
        func reset() {
            temp.value { $0 = 0 }
        }
        
        func increment() {
            temp.value { $0 += 1 }
        }
        
        func value() -> Int {
            return temp.value
        }
    }
    
    @Test("Shared variable access")
    func testSharedVariable() async throws {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await Database.shared.set(key: "test", value: true)
                }
            }
        }
        
        // Verify the value was set
        let value = await Database.shared.get(key: "test")
        #expect(value != nil)
    }
    
    @Test("Write performance")
    func testWritePerformance() async throws {
        let wrapper = Counter()
        let clock = ContinuousClock()
        let startTime = clock.now
        
        await wrapper.reset() // Reset
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await wrapper.increment()
                }
            }
        }
        
        let elapsed = clock.now - startTime
        let finalValue = await wrapper.value()
        #expect(finalValue == iterations)
        #expect(elapsed > .zero)
    }
    
    @Test("Read performance")
    func testReadPerformance() async throws {
        let wrapper = Counter()
        let clock = ContinuousClock()
        let startTime = clock.now
        
        await wrapper.reset() // Reset
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    guard i % writeMultipleOf != 0 else { return }
                    await wrapper.increment()
                }
            }
        }
        
        let elapsed = clock.now - startTime
        let finalValue = await wrapper.value()
        #expect(finalValue >= iterations / writeMultipleOf)
        #expect(elapsed > .zero)
    }
}
