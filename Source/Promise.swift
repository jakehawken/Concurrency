//  Promise.swift
//  Concurrency
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation

public class Promise<T, E: Error> {
    public let future = Future<T, E>()
    
    public init() {}
    
    public convenience init(value: T) {
        self.init()
        resolve(value)
    }
    
    public convenience init(error: E) {
        self.init()
        reject(error)
    }

    public func resolve(_ val: T) {
        future.resolve(val)
    }

    public func reject(_ err: E) {
        future.reject(err)
    }
    
    internal func complete(withResult result: Result<T, E>) {
        future.complete(withResult: result)
    }
}

public class Future<T, E: Error> {
    public typealias ThenBlock  = (T) -> Void
    public typealias ErrorBlock = (E) -> Void

    private var successBlock: ThenBlock?
    private var errorBlock: ErrorBlock?
    private var finallyBlock: ((Result<T, E>) -> Void)?
    private var childFuture: Future?
    fileprivate var result: Result<T, E>?
    
    private let lockQueue = DispatchQueue(label: "com.concurrency.future.\(NSUUID().uuidString)")

    // MARK: - PUBLIC -
    
    // MARK: public properties
    
    public var value: T? {
        guard let result = result else {
            return nil
        }
        switch result {
        case .success(let val):
            return val
        default:
            return nil
        }
    }
    
    public var error: E? {
        guard let result = result else {
            return nil
        }
        switch result {
        case .failure(let err):
            return err
        default:
            return nil
        }
    }
    
    public var succeeded: Bool {
        return value != nil
    }

    public var failed: Bool {
        return error != nil
    }

    public var isComplete: Bool {
        return result != nil
    }
    
    // MARK: - Public methods

    @discardableResult public func onSuccess(_ callback: @escaping ThenBlock) -> Future<T, E> {
        if let value = value { //If the future has already been resolved with a value. Call the block immediately.
            callback(value)
        }
        else if successBlock == nil {
            successBlock = callback
        }
        else if let child = childFuture, child.successBlock == nil {
            child.successBlock = callback
        }
        else {
            self.appendChild().onSuccess(callback)
        }
        return self
    }

    @discardableResult public func onFailure(_ callback: @escaping ErrorBlock) -> Future<T, E> {
        if let error = self.error { //If the future has already been rejected with an error. Call the block immediately.
            callback(error)
        }
        else if self.errorBlock == nil {
            self.errorBlock = callback
        }
        else if let child = childFuture, child.errorBlock == nil {
            child.errorBlock = callback
        }
        else {
            self.appendChild().onFailure(callback)
        }
        return self
    }
    
    @discardableResult public func finally(_ callback: @escaping (Result<T, E>) -> Void) -> Future<T, E> {
        if let result = result {
            callback(result)
        }
        else if finallyBlock == nil {
            finallyBlock = callback
        }
        else if let child = childFuture, child.finallyBlock == nil {
            child.finallyBlock = callback
        }
        else {
            appendChild().finally(callback)
        }
        return self
    }

    // MARK: - PRIVATE

    fileprivate func resolve(_ val: T) {
        guard !isComplete else {
            return
        }
        
        let result: Result<T, E> = .success(val)
        self.result = result
        
        if let success = successBlock {
            lockQueue.sync {
                success(val)
            }
        }
        if let child = childFuture {
            lockQueue.sync {
                child.resolve(val)
            }
        }
        if let finally = finallyBlock {
            lockQueue.sync {
                finally(result)
            }
        }
    }

    fileprivate func reject(_ err: E) {
        guard !isComplete else {
            return
        }
        
        let result: Result<T, E> = .failure(err)
        self.result = result
        
        if let errBlock = errorBlock {
            lockQueue.sync {
                errBlock(err)
            }
        }
        if let child = childFuture {
            lockQueue.sync {
                child.reject(err)
            }
        }
        if let finally = finallyBlock {
            lockQueue.sync {
                finally(result)
            }
        }
    }
    
    fileprivate func complete(withResult result: Result<T, E>) {
        switch result {
        case .success(let value):
            resolve(value)
        case .failure(let error):
            reject(error)
        }
    }

    private func appendChild() -> Future<T, E> {
        if let child = childFuture {
            return child.appendChild()
        }
        else {
            let future = Future<T, E>()
            childFuture = future
            return future
        }
    }
}

public extension Future {
    static func preResolved(value: T) -> Future<T, E> {
        let future = Future<T, E>()
        future.result = .success(value)
        return future
    }
    
    static func preRejected(error: E) -> Future<T, E> {
        let future = Future<T, E>()
        future.result = .failure(error)
        return future
    }
}

public extension Future {
    
    class func zip(_ futures: [Future<T, E>]) -> Future<[T], E> {
        let promise = Promise<[T], E>()
        let lockQueue = promise.future.lockQueue
        
        futures.forEach {
            $0.finally { (_) in
                lockQueue.sync {
                    let results = futures.compactMap { $0.result }
                    let failures = results.compactMap { $0.failure }
                    if let firstError = failures.first {
                        promise.reject(firstError)
                    }
                    guard promise.future.isComplete == false else {
                        return
                    }
                    let successValues = results.compactMap { $0.success }
                    guard successValues.count == futures.count else {
                        return
                    }
                    promise.resolve(successValues)
                }
            }
        }
        
        return promise.future
    }
    
}
