# ReSwift-Effect

[![Platform support](https://img.shields.io/badge/platform-ios%20%7C%20osx%20%7C%20tvos%20%7C%20watchos-lightgrey.svg?style=flat-square)](https://github.com/ReSwift/ReSwift/blob/master/LICENSE.md) [![License MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://github.com/ReSwift/ReSwift/blob/master/LICENSE.md)

[English](README.md) | 中文

# 简介

**ReSwift-Effect** 是对 [ReSwift](https://github.com/ReSwift/ReSwift) 的现代化重写，增强了对异步操作和依赖注入的支持。这个分支在原始 ReSwift 架构的基础上扩展了以下功能：

- **Async/Await 支持**：Reducers 可以返回 `Task<Action, Error>?` 来管理异步副作用
- **Environment 模式**：通过 Reducers 中的 `Environment` 参数进行依赖注入
- **线程安全**：所有状态修改都通过 `@MainActor` 保证在主线程上进行
- **Swift 6.2**：基于 Swift 6.2 和现代并发特性构建
- **Swift Testing**：测试套件已迁移到新的 Swift Testing 框架

ReSwift-Effect 保持了原始 ReSwift 的核心原则，同时提供了更现代、类型安全且并发友好的 API。

# 架构概览

## 架构图

ReSwift-Effect 遵循单向数据流架构，增强了对异步操作和依赖注入的支持：

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

## Reducer 签名

新的 reducer 签名支持同步和异步操作：

```swift
typealias Reducer<ReducerStateType, EnvironmentType> =
    (_ state: inout ReducerStateType, _ action: Action, _ environment: EnvironmentType) -> Task<Action, Error>?
```

- **`state: inout`**：可直接修改的可变状态
- **`action: Action`**：正在处理的操作
- **`environment: EnvironmentType`**：通过环境注入的依赖
- **返回值**：`Task<Action, Error>?` - 可选的异步任务，可以派发后续操作

## 异步操作

Reducers 可以返回一个 `Task` 来处理异步副作用：

```swift
func fetchUserReducer(
    state: inout AppState,
    action: Action,
    environment: AppEnvironment
) -> Task<Action, Error>? {
    guard let fetchAction = action as? FetchUserAction else {
        return nil
    }
    
    // 更新状态以显示加载中
    state.isLoading = true
    
    // 返回异步任务处理副作用
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

Store 自动管理任务生命周期：
- 任务会被跟踪，当 store 被销毁时可以取消
- 当任务完成时，返回的操作会自动派发
- 错误会被处理，可以记录或作为错误操作派发

## Environment 模式

`Environment` 是一个简单的结构体，包含应用的依赖：

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

这使得测试更容易 - 你可以注入模拟依赖：

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

## 线程安全

所有状态修改都保证在主线程上进行：

- `Store` 标记为 `@MainActor`
- 所有 `StoreSubscriber` 方法都在主线程上调用
- Reducers 在主线程上执行
- 状态更新安全地触发 UI 更新

# 目录

- [关于 ReSwift-Effect](#关于-reswift-effect)
- [核心特性](#核心特性)
- [快速开始](#快速开始)
- [架构概览](#架构概览)
- [示例](#示例)
- [安装](#安装)
- [要求](#要求)
- [贡献](#贡献)

# 关于 ReSwift-Effect

ReSwift-Effect 是 Swift 中类似 [Redux](https://github.com/reactjs/redux) 的单向数据流架构实现。它帮助你分离应用组件的三个重要关注点：

- **状态**：整个应用状态显式存储在一个数据结构中。这有助于避免复杂的状态管理代码，并实现更好的调试。
- **视图**：当状态改变时，视图自动更新。你的视图成为当前应用状态的简单可视化。
- **状态变更**：状态只能通过操作进行修改。操作是描述状态变更的小数据片段。通过大幅限制状态可以变更的方式，你的应用变得更容易理解和维护。

## 与原始 ReSwift 的主要区别

1. **异步 Reducers**：Reducers 可以返回 `Task<Action, Error>?` 来处理异步副作用
2. **Environment 注入**：Reducers 接收一个 `Environment` 参数进行依赖注入
3. **主线程隔离**：所有状态修改都保证在主线程上进行
4. **现代 Swift**：需要 Swift 6.2+ 并使用现代并发特性

# 核心特性

- ✅ **单向数据流**：通过操作和 reducers 进行可预测的状态管理
- ✅ **Async/Await 支持**：通过 Swift Concurrency 内置支持异步操作
- ✅ **依赖注入**：Environment 模式用于清晰的依赖管理
- ✅ **线程安全**：`@MainActor` 确保所有状态更新都在主线程上进行
- ✅ **类型安全**：整个架构中的强类型
- ✅ **中间件支持**：可扩展的中间件系统用于操作处理
- ✅ **订阅系统**：高效的状态订阅，自动跳过重复项

# 快速开始

## 基础示例

对于一个简单的计数器应用，定义应用状态：

```swift
struct AppState {
    var counter: Int = 0
}
```

定义操作：

```swift
enum CounterAction: Action {
    case increase
    case decrease
    case reset
    case increaseAsync
    case setLoading(Bool)
}
```

创建依赖的环境：

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

使用新签名实现 reducer：

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

创建 store：

```swift
@MainActor
let appStore = Store<AppState, AppEnvironment>(
    reducer: counterReducer,
    state: AppState(),
    environment: AppEnvironment()
)
```

订阅状态变更（SwiftUI 示例）：

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
                Text("异步增加")
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

# 示例

## 示例 1：简单计数器

查看上面的[基础示例](#快速开始)了解完整的计数器实现。

## 示例 2：异步数据获取

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

// 使用
@MainActor
let appStore = Store<AppState, AppEnvironment>(
    reducer: appReducer,
    state: AppState(),
    environment: AppEnvironment()
)

// 派发获取用户的操作
appStore.dispatch(UserAction.fetchUsers)
```

## 示例 3：子状态选择

订阅状态的特定部分：

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
        // 处理状态更新
    }
}
```

# 安装

## Swift Package Manager

将 ReSwift-Effect 添加到你的 `Package.swift`：

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

或通过 Xcode 添加：
1. File → Add Packages...
2. 输入仓库 URL
3. 选择版本

## 要求

- Swift 6.2+
- macOS 15.0+
- iOS 17.0+
- tvOS 17.0+
- watchOS 11.0+

# 架构原则

ReSwift-Effect 依赖于几个核心原则：

1. **Store** 将整个应用状态存储在单个数据结构中。状态只能通过向 store 派发操作来修改。每当状态改变时，store 会通知所有订阅者。

2. **Actions** 是描述状态变更的声明式方式。操作不包含任何代码 - 它们被 store 消费并转发给 reducers。

3. **Reducers** 是基于当前操作和当前应用状态创建新应用状态的纯函数。Reducers 可以选择返回异步任务来处理副作用。

4. **Environment** 提供依赖注入，使 reducers 可测试且依赖关系明确。

5. **线程安全** 通过 `@MainActor` 保证，确保所有状态修改都在主线程上进行。

# 贡献

欢迎贡献！请随时提交 Pull Request。

# 致谢

- 基于 ReSwift 社区的 [ReSwift](https://github.com/ReSwift/ReSwift)
- 受 Dan Abramov 的 [Redux](https://github.com/reactjs/redux) 启发
- 使用现代 Swift 并发特性增强

# 许可证

MIT 许可证。详见 LICENSE 文件。

