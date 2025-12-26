//
//  ReSwift_Effect_DemoApp.swift
//  ReSwift-Effect-Demo
//
//  Created by Arthas on 2025/12/25.
//

import SwiftUI
import ReSwiftEffect

/// 创建全局的 Store 实例
/// Store 负责管理应用状态，处理动作分发，并通知订阅者
@MainActor
let appStore = Store<AppState, AppEnvironment>(
    reducer: appReducer,
    state: AppState(),
    environment: AppEnvironment()
)

@main
struct ReSwift_Effect_DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
