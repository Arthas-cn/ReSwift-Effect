//
//  AppEnvironment.swift
//  ReSwift-Effect-Demo
//
//  Created by Arthas on 2025/12/25.
//

import Foundation

/// 应用的环境配置，用于依赖注入
struct AppEnvironment {
    /// 模拟一个延迟服务
    let delayService: DelayService
    
    init(delayService: DelayService = DelayService()) {
        self.delayService = delayService
    }

    /// 延迟指定时间
    func delay(seconds: Double) async throws -> CounterAction {
        await delayService.delay(seconds: seconds)
        return CounterAction.increase
    }
}

/// 模拟一个延迟服务，用于演示异步操作
struct DelayService {
    /// 延迟指定时间
    func delay(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
}

