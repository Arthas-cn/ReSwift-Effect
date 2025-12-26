# ReSwift-Effect

[![Platform support](https://img.shields.io/badge/platform-ios%20%7C%20osx%20%7C%20tvos%20%7C%20watchos-lightgrey.svg?style=flat-square)](https://github.com/ReSwift/ReSwift/blob/master/LICENSE.md) [![License MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://github.com/ReSwift/ReSwift/blob/master/LICENSE.md)

English | [中文](README_CN.md)

# Introduction

**ReSwift-Effect** is a modern rewrite of [ReSwift](https://github.com/ReSwift/ReSwift) with enhanced support for asynchronous operations and dependency injection. This fork extends the original ReSwift architecture with:

- **Async/Await Support**: Reducers can return `Task<Action, Error>?` for managing asynchronous side effects
- **Environment Pattern**: Dependency injection through an `Environment` parameter in reducers
- **Thread Safety**: All state modifications are guaranteed to happen on the main thread via `@MainActor`
- **Swift 6.2**: Built with Swift 6.2 and modern concurrency features
- **Swift Testing**: Test suite migrated to the new Swift Testing framework

ReSwift-Effect maintains the core principles of the original ReSwift while providing a more modern, type-safe, and concurrency-friendly API.

# Architecture Overview

## Architecture Diagram

ReSwift-Effect follows a unidirectional data flow architecture with enhanced support for async operations and dependency injection:

```
    ┌─────────────────────────────────────────────────────────────────────────┐
    │                         ReSwift-Effect Architecture                     │
    └─────────────────────────────────────────────────────────────────────────┘

    ┌──────────┐
    │   View   │ (UI Layer - @MainActor)
    │          │
    └────┬─────┘
         │ 1. User Interaction
         │    dispatch(action)
         ▼
    ┌──────────┐
    │  Action  │ (Intent to change state)
    └────┬─────┘
         │ 2. Dispatch
         ▼
    ┌──────────────────────────────────────────────────────────────────────────┐
    │                      Store                                               │
    │                  (@MainActor)                                            │
    │  ┌─────────────────────────────────────────────────────────────────────┐ │
    │  │              State (Immutable)                                      │ │
    │  └─────────────────────────────────────────────────────────────────────┘ │
    └────┬───────────────────────────────┬─────────────────────────────────────┘
         │                               │
         │ 3. Pass to Reducer            │ 6. Update State
         │    (state, action, env)       │    state = newState
         ▼                               │
    ┌────────────────────────────────────┴─────────────────────────────────────┐
    │                    Reducer                                               │
    │  func reducer(                                                           │
    │    state: inout State,                                                   │
    │    action: Action,                                                       │
    │    environment: Environment                                              │
    │  ) -> Task<Action, Error>?                                               │
    └────┬─────────────────────────────────────────────────────────────────────┘
         │
         │ 4. Access Dependencies
         ▼
    ┌──────────────────────────────────────────────────────────────────────────┐
    │                  Environment                                             │
    │  • API Clients                                                           │
    │  • Database                                                              │
    │  • Services                                                              │
    │  • Dependencies                                                          │
    └──────────────────────────────────────────────────────────────────────────┘
         │
         │ 5. Return Task<Action, Error>? (Optional)
         │    - nil: Synchronous update
         │    - Task: Async side effect
         ▼
    ┌──────────────────────────────────────────────────────────────────────────┐
    │              Async Task (if returned)                                    │
    │  ┌─────────────────────────────────────────────────────────────────────┐ │
    │  │  Task {                                                             │ │
    │  │    let result = await env.service.fetch()                           │ │
    │  │    return NextAction(data: result)                                  │ │
    │  │  }                                                                  │ │
    │  └─────────────────────────────────────────────────────────────────────┘ │
    │                                                                          │
    │  ┌─────────────────────────────────────────────────────────────────────┐ │
    │  │  Store automatically:                                               │ │
    │  │  • Tracks task lifecycle                                            │ │
    │  │  • Cancels on deinit                                                │ │
    │  │  • Dispatches result action when complete                           │ │
    │  │  • Handles errors                                                   │ │
    │  └─────────────────────────────────────────────────────────────────────┘ │
    └──────────────────────────────────────────────────────────────────────────┘
         │
         │ 7. Task completes → dispatch(nextAction)
         │    (back to step 2)
         │
    ┌────┴─────┐
    │   View   │ 8. State change notification
    │          │    newState(state) called
    └──────────┘    (UI updates automatically)

    ┌─────────────────────────────────────────────────────────────────────────┐
    │ Key Features:                                                           │
    │                                                                         │
    │  • Unidirectional Flow: Action → Store → Reducer → State → View         │
    │  • Environment Injection: Dependencies passed to reducers               │
    │  • Async Support: Reducers can return Task for side effects             │
    │  • Thread Safety: All state updates on @MainActor                       │
    │  • Automatic Task Management: Lifecycle handled by Store                │
    └─────────────────────────────────────────────────────────────────────────┘
```

## Reducer Signature

The new reducer signature supports both synchronous and asynchronous operations:

```swift
typealias Reducer<ReducerStateType, EnvironmentType> =
    (_ state: inout ReducerStateType, _ action: Action, _ environment: EnvironmentType) -> Task<Action, Error>?
```

- **`state: inout`**: Mutable state that can be modified directly
- **`action: Action`**: The action being processed
- **`environment: EnvironmentType`**: Dependencies injected through the environment
- **Returns**: `Task<Action, Error>?` - Optional async task that can dispatch a follow-up action

## Asynchronous Operations

Reducers can return a `Task` to handle asynchronous side effects:

```swift
func fetchUserReducer(
    state: inout AppState,
    action: Action,
    environment: AppEnvironment
) -> Task<Action, Error>? {
    guard let fetchAction = action as? FetchUserAction else {
        return nil
    }
    
    // Update state to show loading
    state.isLoading = true
    
    // Return async task for side effect
    return Task {
        do {
            let user = try await environment.userService.fetchUser(id: fetchAction.userId)
            return SetUserAction(user: user)
        } catch {
            return SetErrorAction(error: error)
        }
    }
}
```

The store automatically manages the task lifecycle:
- Tasks are tracked and can be cancelled when the store is deinitialized
- When a task completes, the returned action is automatically dispatched
- Errors are handled and can be logged or dispatched as error actions

## Environment Pattern

The `Environment` is a simple struct that contains your app's dependencies:

```swift
struct AppEnvironment {
    let apiClient: APIClient
    let database: Database
    let analytics: AnalyticsService
    
    init(
        apiClient: APIClient = APIClient(),
        database: Database = Database(),
        analytics: AnalyticsService = AnalyticsService()
    ) {
        self.apiClient = apiClient
        self.database = database
        self.analytics = analytics
    }
}
```

This makes testing easier - you can inject mock dependencies:

```swift
// Production
let environment = AppEnvironment()

// Testing
let mockEnvironment = AppEnvironment(
    apiClient: MockAPIClient(),
    database: MockDatabase(),
    analytics: MockAnalytics()
)
```

## Thread Safety

All state modifications are guaranteed to happen on the main thread:

- `Store` is marked with `@MainActor`
- All `StoreSubscriber` methods are called on the main thread
- Reducers are executed on the main thread
- State updates trigger UI updates safely

# Table of Contents

- [About ReSwift-Effect](#about-reswift-effect)
- [Key Features](#key-features)
- [Getting Started](#getting-started)
- [Architecture Overview](#architecture-overview)
- [Examples](#examples)
- [Installation](#installation)
- [Requirements](#requirements)
- [Contributing](#contributing)

# About ReSwift-Effect

ReSwift-Effect is a [Redux](https://github.com/reactjs/redux)-like implementation of the unidirectional data flow architecture in Swift. It helps you to separate three important concerns of your app's components:

- **State**: The entire app state is explicitly stored in a data structure. This helps avoid complicated state management code and enables better debugging.
- **Views**: Views update automatically when state changes. Your views become simple visualizations of the current app state.
- **State Changes**: State can only be modified through actions. Actions are small pieces of data that describe a state change. By drastically limiting the way state can be mutated, your app becomes easier to understand and maintain.

## Key Differences from Original ReSwift

1. **Async Reducers**: Reducers can return `Task<Action, Error>?` to handle asynchronous side effects
2. **Environment Injection**: Reducers receive an `Environment` parameter for dependency injection
3. **Main Actor Isolation**: All state modifications are guaranteed to happen on the main thread
4. **Modern Swift**: Requires Swift 6.2+ and uses modern concurrency features

# Key Features

- ✅ **Unidirectional Data Flow**: Predictable state management through actions and reducers
- ✅ **Async/Await Support**: Built-in support for asynchronous operations via Swift Concurrency
- ✅ **Dependency Injection**: Environment pattern for clean dependency management
- ✅ **Thread Safety**: `@MainActor` ensures all state updates happen on the main thread
- ✅ **Type Safety**: Strong typing throughout the architecture
- ✅ **Middleware Support**: Extensible middleware system for action processing
- ✅ **Subscription System**: Efficient state subscription with automatic duplicate skipping

# Getting Started

## Basic Example

For a simple counter app, define the app state:

```swift
struct AppState {
    var counter: Int = 0
    var isLoading: Bool = false
}
```

Define actions:

```swift
enum CounterAction: Action {
    case increase
    case decrease
    case reset
    case increaseAsync
    case setLoading(Bool)
}
```

Create an environment for dependencies:

```swift
struct AppEnvironment {
    let delayService: DelayService
    
    init(delayService: DelayService = DelayService()) {
        self.delayService = delayService
    }
    
    func delay(seconds: Double) async throws -> CounterAction {
        await delayService.delay(seconds: seconds)
        return CounterAction.increase
    }
}

struct DelayService {
    func delay(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
```

Implement a reducer with the new signature:

```swift
func counterReducer(
    state: inout AppState, 
    action: Action, 
    environment: AppEnvironment
) -> Task<Action, Error>? {
    guard let counterAction = action as? CounterAction else {
        return nil
    }
    
    switch counterAction {
    case .increase:
        state.counter += 1
        return nil
        
    case .decrease:
        state.counter -= 1
        return nil
        
    case .reset:
        state.counter = 0
        return nil
        
    case .increaseAsync:
        state.isLoading = true
        return Task {
            try await environment.delay(seconds: 1)
        }
        
    case .setLoading(let isLoading):
        state.isLoading = isLoading
        return nil
    }
}
```

Create the store:

```swift
@MainActor
let appStore = Store<AppState, AppEnvironment>(
    reducer: counterReducer,
    state: AppState(),
    environment: AppEnvironment()
)
```

Subscribe to state changes (SwiftUI example):

```swift
struct ContentView: View {
    private var counter: Int {
        appStore.state.counter
    }
    
    private var isLoading: Bool {
        appStore.state.isLoading
    }
    
    let subscriber = CounterSubscriber()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("\(counter)")
                .font(.system(size: 60, weight: .bold))
            
            HStack(spacing: 20) {
                Button(action: {
                    appStore.dispatch(CounterAction.decrease)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 50))
                }
                .disabled(isLoading)
                
                Button(action: {
                    appStore.dispatch(CounterAction.increase)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                }
                .disabled(isLoading)
            }
            
            Button(action: {
                appStore.dispatch(CounterAction.increaseAsync)
            }) {
                Text("Async Increase")
            }
            .disabled(isLoading)
        }
        .onAppear {
            appStore.subscribe(subscriber)
        }
    }
}

@MainActor
class CounterSubscriber: StoreSubscriber {
    typealias StoreSubscriberStateType = AppState
    
    func newState(state: AppState) {
        print("Counter: \(state.counter), Loading: \(state.isLoading)")
    }
}
```

# Examples

## Example 1: Simple Counter

See the [Basic Example](#getting-started) above for a complete counter implementation.

## Example 2: Async Data Fetching

```swift
struct AppState {
    var users: [User] = []
    var isLoading: Bool = false
    var error: Error?
}

struct AppEnvironment {
    let userService: UserService
    
    init(userService: UserService = UserService()) {
        self.userService = userService
    }
}

enum UserAction: Action {
    case fetchUsers
    case setUsers([User])
    case setError(Error)
}

func appReducer(
    state: inout AppState,
    action: Action,
    environment: AppEnvironment
) -> Task<Action, Error>? {
    guard let userAction = action as? UserAction else {
        return nil
    }
    
    switch userAction {
    case .fetchUsers:
        state.isLoading = true
        state.error = nil
        
        return Task {
            do {
                let users = try await environment.userService.fetchUsers()
                return UserAction.setUsers(users)
            } catch {
                return UserAction.setError(error)
            }
        }
        
    case .setUsers(let users):
        state.users = users
        state.isLoading = false
        return nil
        
    case .setError(let error):
        state.error = error
        state.isLoading = false
        return nil
    }
}

// Usage
@MainActor
let appStore = Store<AppState, AppEnvironment>(
    reducer: appReducer,
    state: AppState(),
    environment: AppEnvironment()
)

// Dispatch fetch action
appStore.dispatch(UserAction.fetchUsers)
```

## Example 3: Substate Selection

Subscribe to a specific part of the state:

```swift
struct UserListView: View {
    @State private var users: [User] = []
    let subscriber = UserListSubscriber()
    
    var body: some View {
        List(users) { user in
            Text(user.name)
        }
        .onAppear {
            appStore.subscribe(subscriber) { subscription in
                subscription.select { $0.users }
            }
        }
        .onDisappear {
            appStore.unsubscribe(subscriber)
        }
    }
}

@MainActor
class UserListSubscriber: StoreSubscriber {
    typealias StoreSubscriberStateType = [User]
    
    func newState(state: [User]) {
        // Handle state updates
    }
}
```

# Installation

## Swift Package Manager

Add ReSwift-Effect to your `Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v11)
    ],
    dependencies: [
        .package(url: "https://github.com/Arthas-cn/ReSwift-Effect.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "ReSwiftEffect", package: "reswift-effect")
            ]
        )
    ]
)
```

Or add it through Xcode:
1. File → Add Packages...
2. Enter the repository URL
3. Select the version

## Requirements

- Swift 6.2+
- macOS 15.0+
- iOS 17.0+
- tvOS 17.0+
- watchOS 11.0+

# Architecture Principles

ReSwift-Effect relies on a few core principles:

1. **The Store** stores your entire app state in a single data structure. State can only be modified by dispatching Actions to the store. Whenever the state changes, the store notifies all subscribers.

2. **Actions** are a declarative way of describing a state change. Actions don't contain any code - they are consumed by the store and forwarded to reducers.

3. **Reducers** are pure functions that, based on the current action and current app state, create a new app state. Reducers can optionally return async tasks for side effects.

4. **Environment** provides dependency injection, making reducers testable and dependencies explicit.

5. **Thread Safety** is guaranteed through `@MainActor`, ensuring all state modifications happen on the main thread.

# Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

# Credits

- Based on [ReSwift](https://github.com/ReSwift/ReSwift) by the ReSwift community
- Inspired by [Redux](https://github.com/reactjs/redux) by Dan Abramov
- Enhanced with modern Swift concurrency features

# License

MIT License. See LICENSE file for details.
