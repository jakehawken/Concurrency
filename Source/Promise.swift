//  Promise.swift
//  Concurrency
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation

//swiftlint:disable line_length

/**
 Promise is the object responsible for creating and completing a future. Generically typed `Promise<T,E>`, where `T` is the success type and `E` is the error type.
 
 Promises/Futures are for single-use events and can only be completed (resolved/rejected) once. Subsequent completion attempts will be no-ops.
 
 In typical use, the promise is not revealed to the consumer of the future. A method returns a future and privately completes the promise on completion of the asynchronous work.
*/
public class Promise<T, E: Error> {
    
    /// The generated future, which only this promise can resolve.
    public let future = Future<T, E>()
    
    public init() {}
    
    /**
    Convenience initializer. Synchronously returns a promise with a pre-resolved future. Useful for testing.
    
    - Parameter value: The success value.
    - returns: A promise with a future that comes pre-resolved with the provided value.
    */
    public convenience init(value: T) {
        self.init()
        resolve(value)
    }
    
    /**
    Convenience initializer. Synchronously returns a promise with a pre-rejected future. Useful for testing.
    
    - Parameter error: The failing error.
    - returns: A promise with a future that comes pre-rejected with the provided error.
    */
    public convenience init(error: E) {
        self.init()
        reject(error)
    }

    /**
     Triggers the success state of the associated future and locks the future as completed.
     
     - Parameter val: The success value.
     */
    public func resolve(_ val: T) {
        future.resolve(val)
    }

    /**
    Triggers the failure state of the associated future and locks the future as completed.
    
    - Parameter err: The error value.
    */
    public func reject(_ err: E) {
        future.reject(err)
    }
    
    /**
    Triggers a completed state on the associated future, corresponding to the `.success` or `.failure` state of the result, and locks the future as completed.
    
    - Parameter result: A result of type `Result<T,E>`, where `T` and `E` correspond to the value and error types of the promise.
    */
    internal func complete(withResult result: Result<T, E>) {
        future.complete(withResult: result)
    }
}

/**
 A Future is an object which represents a one-time unit of failable, asynchronous work. Generically typed `Future<T,E>` where `T` is the success type and `E` is the error type. Since futures are single-use, all completion attempts after the first will be no-ops.
*/
public class Future<T, E: Error> {
    public typealias SuccessBlock  = (T) -> Void
    public typealias ErrorBlock = (E) -> Void

    private var successBlock: SuccessBlock?
    private var errorBlock: ErrorBlock?
    private var finallyBlock: ((Result<T, E>) -> Void)?
    private var childFuture: Future?
    fileprivate var result: Result<T, E>?
    
    private let lockQueue = DispatchQueue(label: "com.concurrency.future.\(NSUUID().uuidString)")

    // MARK: - PUBLIC -
    
    // MARK: public properties
    
    /// The value of the future. Will return `nil` if the future failed or is incomplete.
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
    
    /// The error of the future. Will return `nil` if the future succeeded or is incomplete.
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
    
    /// Convenience property. Returns `true` if the future is completed with a success value.
    public var succeeded: Bool {
        return value != nil
    }

    /// Convenience property. Returns `true` if the future is completed with an error value.
    public var failed: Bool {
        return error != nil
    }

    /// Convenience property. Returns `true` if the future completed, regardless of whether it was a success for failure.
    public var isComplete: Bool {
        return result != nil
    }
    
    // MARK: - Public methods

    /**
    Adds a block to be executed when and if the future is resolved with a success value. Can be called multiple times to add multiple blocks. Note: Blocks will execute serially, in the order in which they were added.    
    
    - Parameter callback: The block to be executed on success. Block takes a single argument, which is of the success type of the future.
    - returns: The future iself, as a `@discardableResult` to allow for chaining of callback methods.
    */
    @discardableResult public func onSuccess(_ callback: @escaping SuccessBlock) -> Future<T, E> {
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

    /**
    Adds a block to be executed when and if the future is rejected with an error. Can be called multiple times to add multiple blocks. Note: Blocks will execute serially, in the order in which they were added.
    
    - Parameter callback: The block to be executed on failure. Block takes a single argument, which is of the error type of the future.
    - returns: The future iself, as a `@discardableResult` to allow for chaining of callback methods.
    */
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
    
    /**
    Adds a block to be executed when and if the future completes, regardless of success/failure state. Can be called multiple times to add multiple blocks. Note: Blocks will execute serially, in the order in which they were added.
    
    - Parameter callback: The block to be executed on completion. Block takes a single argument, which is a `Result<T,E>`.
    - returns: The future iself, as a `@discardableResult` to allow for chaining of callback methods.
    */
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
}

fileprivate extension Future {
    
    func resolve(_ val: T) {
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

    func reject(_ err: E) {
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
    
    func complete(withResult result: Result<T, E>) {
        switch result {
        case .success(let value):
            resolve(value)
        case .failure(let error):
            reject(error)
        }
    }

    func appendChild() -> Future<T, E> {
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

// MARK: - convenience constructors

public extension Future {
    /**
    Convenience constructor. Synchronously returns a pre-resolved future. Useful for testing.
    
    - Parameter value: The success value.
    - returns: A future that comes pre-resolved with the provided value.
    */
    static func preResolved(value: T) -> Future<T, E> {
        let future = Future<T, E>()
        future.result = .success(value)
        return future
    }
    
    /**
    Convenience constructor. Synchronously returns a pre-rejected future. Useful for testing.
    
    - Parameter error: The failing error.
    - returns: A future that comes pre-rejected with the provided error.
    */
    static func preRejected(error: E) -> Future<T, E> {
        let future = Future<T, E>()
        future.result = .failure(error)
        return future
    }
}

// MARK: - combination

public extension Future {
    
    /**
     Returns a future that succeeds only when all of the supplied futures succeed, but fails as soon as any of them fail.
     
     - Parameter futures: An array of like-typed futures which must all succeed in order for the returned future to succeed.
     - returns: A future where the success value is an array of the success values from the array of promises, and the error is whichever error happened first.
    */
    static func zip(_ futures: [Future<T, E>]) -> Future<[T], E> {
        let promise = Promise<[T], E>()
        
        futures.forEach {
            $0.finally { (_) in
                promise.future.lockQueue.sync {
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
    
    /**
     Takes an array of futures, and completes with the state/value of the first future in that array to finish.
     
     - Parameter futures: An array of like-typed futures which must all succeed in order for the returned future to succeed.
     - returns: A future that completes with the state/value of which ever future in the array finishes first.
    */
    static func firstFinished(from futures: [Future]) -> Future {
        let promise = Promise<T, E>()
        
        futures.forEach {
            $0.onSuccess { (value) in
                promise.future.lockQueue.sync {
                    promise.resolve(value)
                }
            }
            .onFailure { (error) in
                promise.future.lockQueue.sync {
                    guard promise.future.isComplete == false else {
                        return
                    }
                    let failures = futures.compactMap { $0.error }
                    guard failures.count == futures.count else {
                        return
                    }
                    promise.reject(error)
                }
            }
        }
        
        return promise.future
    }
    
}
