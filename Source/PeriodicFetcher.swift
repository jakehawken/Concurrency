//  PeriodicFetcher.swift
//  Concurrency
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation
import RxSwift


public enum StreamState<T> {
    case noData
    case newData(T)
    case error(Error)
    
    @discardableResult public func onError(_ errorBlock: (Error)->()) -> StreamState<T> {
        switch self {
        case .error(let error):
            errorBlock(error)
        default:
            break
        }
        return self
    }
    
    @discardableResult public func onNew(_ successBlock: (T)->()) -> StreamState<T> {
        switch self {
        case .newData(let val):
            successBlock(val)
        default:
            break
        }
        return self
    }
    
}

public extension StreamState where T: Equatable {
    public static func ==(lhs: StreamState, rhs: StreamState) -> Bool {
        switch (lhs, rhs) {
        case (.noData, .noData), (.error(_), .error(_)):
            return true
        case (.newData(let value1), .newData(let value2)):
            return value1 == value2
        default:
            return false
        }
    }
    
    public static func ==(lhs: StreamState<T>?, rhs: StreamState<T>) -> Bool {
        guard let lhs = lhs else {
            return false
        }
        return lhs == rhs
    }
    
    public static func ==(lhs: StreamState<T>, rhs: StreamState<T>?) -> Bool {
        guard let rhs = rhs else {
            return false
        }
        return lhs == rhs
    }
}

public class PeriodicFetcher<T> {
    
    public typealias FutureGenerator = ()->(Future<T>)
    public typealias TimeIntervalGenerator = ()->(Double)
    
    //MARK: - PROPERTIES -
    //MARK: private
    
    private var variable: Variable<StreamState<T>> = Variable(.noData)
    private var timer: Timer?
    private let operationQueue = OperationQueue()
    fileprivate let disposeBag = DisposeBag()
    
    private var timeIntervalIsCurrent: Bool {
        return timer?.timeInterval == getTimeInterval()
    }
    
    private var shouldEmit = false
    
    //MARK: injected
    
    private var getFuture: FutureGenerator
    private var currentFuture: Future<T>?
    private var getTimeInterval: TimeIntervalGenerator
    
    //MARK: - public
    
    public var isFetching: Bool {
        if let timer = timer {
            return timer.isValid
        }
        return false
    }
    
    //MARK: initialization
    
    public init(futureGenerator: @escaping FutureGenerator,
         timeInterval: @escaping TimeIntervalGenerator) {
        self.getFuture = futureGenerator
        self.getTimeInterval = timeInterval
    }
    
    //MARK: - PUBLIC METHODS
    
    public func observable() -> Observable<StreamState<T>> {
        return variable.asObservable()
    }
    
    public func startPeriodicFetch() {
        shouldEmit = true
        if !isFetching || !timeIntervalIsCurrent {
            createTimerAndFire()
        }
    }
    
    public func stopPeriodicFetch() {
        shouldEmit = false
        currentFuture = nil
        timer?.invalidate()
        timer = nil
    }
    
    public func fetchOnce() {
        shouldEmit = true
        if isFetching {
            if timeIntervalIsCurrent {
                timer?.fire()
            }
            else {
                stopPeriodicFetch()
                createTimerAndFire()
            }
        }
        else {
            fetch()
        }
    }
    
    //MARK: - PRIVATE / HELPER METHODS
    
    private func createTimerAndFire() {
        timer = newTimer()
        timer?.fire()
    }
    
    private func newTimer() -> Timer {
        return Timer.scheduledTimer(withTimeInterval: getTimeInterval(), repeats: true) { [weak self](_) in
            self?.fetch()
        }
    }
    
    private func fetch() {
        guard shouldEmit else {
            stopPeriodicFetch()
            return
        }
        
        currentFuture = getFuture().then { [weak self](value) in
            self?.operationQueue.addOperation { [weak self] in
                self?.emitIfPossible(.newData(value))
            }
        }.error { [weak self](errorFromFuture) in
            self?.operationQueue.addOperation { [weak self] in
                self?.emitIfPossible(.error(errorFromFuture))
            }
        }
    }
    
    private func emitIfPossible(_ streamState: StreamState<T>) {
        guard shouldEmit else {
            stopPeriodicFetch()
            return
        }
        variable.value = streamState
    }
}

public protocol PeriodicService {
    associatedtype T: Equatable
    func observable() -> Observable<StreamState<T>>
    func startPeriodicFetch()
    func stopPeriodicFetch()
    func fetchOnce()
    var isPeriodicFetching: Bool {get}
}
