//
//  Store.swift
//  ReSwift
//
//  Created by Benjamin Encz on 11/11/15.
//  Copyright © 2015 ReSwift Community. All rights reserved.
//

import Foundation

/**
 This class is the default implementation of the `StoreType` protocol. You will use this store in most
 of your applications. You shouldn't need to implement your own store.
 You initialize the store with a reducer and an initial application state. If your app has multiple
 reducers you can combine them by initializing a `MainReducer` with all of your reducers as an
 argument.
 
 All state modifications are guaranteed to happen on the main thread via @MainActor.
 */
@MainActor
@Observable
open class Store<State, Environment>: StoreType {

    typealias SubscriptionType = SubscriptionBox<State>

    private(set) public var state: State! {
        didSet {
            subscriptions.forEach {
                if $0.subscriber == nil {
                    subscriptions.remove($0)
                } else {
                    $0.newValues(oldState: oldValue, newState: state)
                }
            }
        }
    }

    @ObservationIgnored
    public lazy var dispatchFunction: DispatchFunction! = createDispatchFunction()
    @ObservationIgnored
    private var reducer: Reducer<State, Environment>
    private let environment: Environment
    
    // Track active tasks for lifecycle management
    // Using dictionary with UUID keys since Task doesn't conform to Hashable
    // Wrapped in Any to handle availability
    // Marked as nonisolated(unsafe) to allow access from deinit
    @ObservationIgnored
    nonisolated(unsafe) private var activeTasks: [UUID: Any] = [:]

    @ObservationIgnored
    var subscriptions: Set<SubscriptionType> = []

    @ObservationIgnored
    private var isDispatching = Synchronized<Bool>(false)

    /// Indicates if new subscriptions attempt to apply `skipRepeats` 
    /// by default.
    @ObservationIgnored
    fileprivate let subscriptionsAutomaticallySkipRepeats: Bool
    
    @ObservationIgnored
    public var middleware: [Middleware<State>] {
        didSet {
            dispatchFunction = createDispatchFunction()
        }
    }

    /// Initializes the store with a reducer, an initial state and a list of middleware.
    ///
    /// Middleware is applied in the order in which it is passed into this constructor.
    ///
    /// - parameter reducer: Main reducer that processes incoming actions.
    /// - parameter state: Initial state, if any. Can be `nil` and will be 
    ///   provided by the reducer in that case.
    /// - parameter environment: Environment containing dependencies for side effects.
    /// - parameter middleware: Ordered list of action pre-processors, acting 
    ///   before the root reducer.
    /// - parameter automaticallySkipsRepeats: If `true`, the store will attempt 
    ///   to skip idempotent state updates when a subscriber's state type 
    ///   implements `Equatable`. Defaults to `true`.
    public required init(
        reducer: @escaping Reducer<State, Environment>,
        state: State?,
        environment: Environment,
        middleware: [Middleware<State>] = [],
        automaticallySkipsRepeats: Bool = true
    ) {
        self.subscriptionsAutomaticallySkipRepeats = automaticallySkipsRepeats
        self.reducer = reducer
        self.environment = environment
        self.middleware = middleware

        if let state = state {
            self.state = state
        } else {
            dispatch(ReSwiftInit())
        }
    }
    
    deinit {
        // Cancel all active tasks when store is deinitialized
        activeTasks.values.forEach { task in
            if let cancellableTask = task as? Task<Void, Never> {
                cancellableTask.cancel()
            }
        }
    }

    private func createDispatchFunction() -> DispatchFunction! {
        // Wrap the dispatch function with all middlewares
        return middleware
            .reversed()
            .reduce(
                { [unowned self] action in
                    self._defaultDispatch(action: action) },
                { dispatchFunction, middleware in
                    // If the store get's deinitialized before the middleware is complete; drop
                    // the action without dispatching.
                    let dispatch: (Action) -> Void = { [weak self] in self?.dispatch($0) }
                    let getState: () -> State? = { [weak self] in self?.state }
                    return middleware(dispatch, getState)(dispatchFunction)
            })
    }

    fileprivate func _subscribe<SelectedState, S: StoreSubscriber>(
        _ subscriber: S, originalSubscription: Subscription<State>,
        transformedSubscription: Subscription<SelectedState>?)
        where S.StoreSubscriberStateType == SelectedState
    {
        let subscriptionBox = self.subscriptionBox(
            originalSubscription: originalSubscription,
            transformedSubscription: transformedSubscription,
            subscriber: subscriber
        )

        subscriptions.update(with: subscriptionBox)

        if let state = self.state {
            originalSubscription.newValues(oldState: nil, newState: state)
        }
    }

    open func subscribe<S: StoreSubscriber>(_ subscriber: S)
        where S.StoreSubscriberStateType == State {
            subscribe(subscriber, transform: nil)
    }

    open func subscribe<SelectedState, S: StoreSubscriber>(
        _ subscriber: S, transform: ((Subscription<State>) -> Subscription<SelectedState>)?
    ) where S.StoreSubscriberStateType == SelectedState
    {
        // Create a subscription for the new subscriber.
        let originalSubscription = Subscription<State>()
        // Call the optional transformation closure. This allows callers to modify
        // the subscription, e.g. in order to subselect parts of the store's state.
        let transformedSubscription = transform?(originalSubscription)

        _subscribe(subscriber, originalSubscription: originalSubscription,
                   transformedSubscription: transformedSubscription)
    }

    func subscriptionBox<T>(
        originalSubscription: Subscription<State>,
        transformedSubscription: Subscription<T>?,
        subscriber: AnyStoreSubscriber
        ) -> SubscriptionBox<State> {

        return SubscriptionBox(
            originalSubscription: originalSubscription,
            transformedSubscription: transformedSubscription,
            subscriber: subscriber
        )
    }

    open func unsubscribe(_ subscriber: AnyStoreSubscriber) {
        if let index = subscriptions.firstIndex(where: { return $0.subscriber === subscriber }) {
            subscriptions.remove(at: index)
        }
    }

    // swiftlint:disable:next identifier_name
    open func _defaultDispatch(action: Action) {
        guard !isDispatching.value else {
            raiseFatalError(
                "ReSwift:ConcurrentMutationError- Action has been dispatched while" +
                " a previous action is being processed. A reducer" +
                " is dispatching an action, or ReSwift is used in a concurrent context" +
                " (e.g. from multiple threads). Action: \(action)"
            )
        }

        isDispatching.value { $0 = true }
        
        // Call reducer with inout state and environment
        // Since reducer requires inout state, we need to ensure state is initialized
        // If state is nil, we need to create a temporary state for initialization
        var mutableState: State
        if let currentState = state {
            mutableState = currentState
        } else {
            // For initial state, we need to create a temporary state
            // This requires State to have a default initializer or we handle it differently
            // For now, we'll use a workaround: create state through reducer with a dummy value
            // This is a limitation - State must be initializable
            fatalError("State must be initialized before calling reducer. Provide initial state in Store.init")
        }
        
        let task = reducer(&mutableState, action, environment)
        
        // Reset isDispatching before updating state to allow subscribers to dispatch new actions
        isDispatching.value { $0 = false }
        
        // Update state (this will trigger didSet and notify subscribers)
        state = mutableState
        
        // Handle async side effect task if returned
        if let sideEffectTask = task {
            let taskId = UUID()
            let wrappedTask = Task<Void, Never> { [weak self] in
                do {
                    let nextAction = try await sideEffectTask.value
                    // Dispatch the next action on the main actor
                    guard let self = self else { return }
                    self.dispatch(nextAction)
                } catch {
                    // Error handling: could dispatch an error action or log
                    print(error)
                }
                
                guard let self = self else { return }
                self.activeTasks.removeValue(forKey: taskId)
            }
            
            // Store the task for lifecycle management
            activeTasks[taskId] = wrappedTask
        }
    }

    open func dispatch(_ action: Action) {
        dispatchFunction(action)
    }
}

// MARK: Skip Repeats for Equatable States

extension Store {
    public func subscribe<SelectedState: Equatable, S: StoreSubscriber>(
        _ subscriber: S, transform: ((Subscription<State>) -> Subscription<SelectedState>)?
        ) where S.StoreSubscriberStateType == SelectedState
    {
        let originalSubscription = Subscription<State>()

        var transformedSubscription = transform?(originalSubscription)
        if subscriptionsAutomaticallySkipRepeats {
            transformedSubscription = transformedSubscription?.skipRepeats()
        }
        _subscribe(subscriber, originalSubscription: originalSubscription,
                   transformedSubscription: transformedSubscription)
    }
}

extension Store where State: Equatable {
	public func subscribe<S: StoreSubscriber>(_ subscriber: S)
        where S.StoreSubscriberStateType == State {
            guard subscriptionsAutomaticallySkipRepeats else {
                subscribe(subscriber, transform: nil)
                return
            }
            subscribe(subscriber, transform: { $0.skipRepeats() })
    }
}
