//
//  AppReducer.swift
//  ReSwift-Effect-Demo
//
//  Created by Arthas on 2025/12/25.
//

import Foundation
import ReSwiftEffect

/// 应用的主 Reducer
/// 
/// Reducer 是一个纯函数，接收当前状态、动作和环境，返回新的状态和可选的异步任务
func appReducer(
    state: inout AppState,
    action: Action,
    environment: AppEnvironment
) -> Task<Action, Error>? {
    guard let counterAction = action as? CounterAction else {
        return nil
    }
    
    switch counterAction {
    case .increase:
        state.isLoading = false
        // 同步增加计数器
        state.counter += 1
        return nil
        
    case .decrease:
        // 同步减少计数器
        state.counter -= 1
        return nil
        
    case .reset:
        // 重置计数器
        state.counter = 0
        return nil
        
    case .increaseAsync:
        // 异步增加计数器（模拟网络请求）
        state.isLoading = true
        
        // 返回一个异步任务
        return Task {
            // 模拟延迟 1 秒
            try await environment.delay(seconds: 1)
        }
        
    case .setLoading(let isLoading):
        // 设置加载状态
        state.isLoading = isLoading
        return nil
    }
}

