//
//  AppActions.swift
//  ReSwift-Effect-Demo
//
//  Created by Arthas on 2025/12/25.
//

import Foundation
import ReSwiftEffect

/// 计数器相关的动作枚举
enum CounterAction: Action {
    /// 增加计数器
    case increase
    /// 减少计数器
    case decrease
    /// 重置计数器
    case reset
    /// 异步增加计数器（模拟异步操作）
    case increaseAsync
    /// 设置加载状态
    case setLoading(Bool)
}

