//
//  ContentView.swift
//  ReSwift-Effect-Demo
//
//  Created by Arthas on 2025/12/25.
//

import SwiftUI
import ReSwiftEffect

/// 计数器视图
/// 
/// 通过订阅 Store 的状态变化来更新 UI
struct ContentView: View {
    /// 计算属性：当前计数器的值
    private var counter: Int {
        appStore.state.counter
    }
    
    /// 计算属性：是否正在加载
    private var isLoading: Bool {
        appStore.state.isLoading
    }
    
    // 订阅者
    let subscriber = CounterSubscriber()
    
    var body: some View {
        VStack(spacing: 30) {
            // 标题
            Text("ReSwift-Effect 计数器")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 计数器显示
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 150, height: 150)
                
                VStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        Text("\(counter)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // 按钮组
            VStack(spacing: 15) {
                // 增加和减少按钮
                HStack(spacing: 20) {
                    Button(action: {
                        appStore.dispatch(CounterAction.decrease)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                    }
                    .disabled(isLoading)
                    
                    Button(action: {
                        appStore.dispatch(CounterAction.increase)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                    }
                    .disabled(isLoading)
                }
                
                // 异步增加按钮
                Button(action: {
                    appStore.dispatch(CounterAction.increaseAsync)
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("异步增加 (+1)")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
                .padding(.horizontal, 40)
                
                // 重置按钮
                Button(action: {
                    appStore.dispatch(CounterAction.reset)
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
                .padding(.horizontal, 40)
            }
            
            // 说明文字
            VStack(alignment: .leading, spacing: 8) {
                Text("功能说明：")
                    .font(.headline)
                Text("• 点击 + / - 按钮：同步修改计数器")
                Text("• 点击「异步增加」：模拟异步操作（1秒延迟）")
                Text("• 点击「重置」：将计数器归零")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding()
        .onAppear {
            // 视图出现时订阅 Store
            subscribeToStore()
        }
    }
    
    /// 订阅 Store 的状态变化
    @MainActor
    private func subscribeToStore() {
        // 订阅 Store
        appStore.subscribe(subscriber)
    }
}

/// Store 订阅者
/// 
/// 实现 StoreSubscriber 协议以接收状态更新
@MainActor
class CounterSubscriber: StoreSubscriber {
    typealias StoreSubscriberStateType = AppState
    
    func newState(state: AppState) {
        print("newState.counter:\(state.counter)")
        print("newState.isLoading:\(state.isLoading)")
    }
}

#Preview {
    ContentView()
}
