//  Promise.swift
//  Concurrency
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation


public class Promise<T> {

    let future = Future<T>()

    func resolve(_ val: T) {
        future.resolve(val)
    }

    func reject(_ err: Error) {
        future.reject(err)
    }

}

public class Future<T> {
    public typealias ThenBlock  = (T)->()
    public typealias ErrorBlock = (Error)->()

    private var thenBlock: ThenBlock?
    private var errorBlock: ErrorBlock?
    private var finallyBlock: (()->())?
    private var childFuture: Future?
    fileprivate var result: Result<T>?
    
    private let lockQueue = DispatchQueue(label: "com.concurrency.future.\(NSUUID().uuidString)")

    //MARK: - PUBLIC -
    
    //MARK: public properties
    
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
    
    public var error: Error? {
        guard let result = result else {
            return nil
        }
        switch result {
        case .error(let err):
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
        return succeeded || failed
    }
    
    //MARK: - Public methods

    @discardableResult public func then(_ callback: @escaping ThenBlock) -> Future<T> {
        if let value = self.value { //If the future has already been resolved with a value. Call the block immediately.
            callback(value)
        }
        else if self.thenBlock == nil {
            self.thenBlock = callback
        }
        else {
            self.appendChild().then(callback)
        }
        return self
    }

    @discardableResult public func error(_ callback: @escaping ErrorBlock) -> Future<T> {
        if let error = self.error { //If the future has already been rejected with an error. Call the block immediately.
            callback(error)
        }
        else if self.errorBlock == nil {
            self.errorBlock = callback
        }
        else {
            self.appendChild().error(callback)
        }
        return self
    }
    
    @discardableResult public func finally(_ callback: @escaping ()->()) -> Future<T> {
        if self.value != nil {
            callback()
        }
        else {
            self.finallyBlock = callback
        }
        return self
    }

    //MARK: - PRIVATE

    fileprivate func resolve(_ val: T) {
        if self.isComplete {
            return
        }
        
        self.result = .success(val)
        
        lockQueue.sync {
            self.thenBlock?(val)
        }
        lockQueue.sync {
            self.childFuture?.resolve(val)
        }
        lockQueue.sync {
            self.finallyBlock?()
        }
    }

    fileprivate func reject(_ err: Error) {
        if self.isComplete {
            return
        }
        
        self.result = .error(err)
        
        lockQueue.sync {
            self.errorBlock?(err)
        }
        lockQueue.sync {
            self.childFuture?.reject(err)
        }
        lockQueue.sync {
            self.finallyBlock?()
        }
    }

    private func appendChild() -> Future<T> {
        if let child = childFuture {
            return child.appendChild()
        }
        else {
            let future = Future<T>()
            childFuture = future
            return future
        }
    }
}

public extension Future {
    
    public static func preResolved(value: T) -> Future<T> {
        let future = Future<T>()
        future.result = .success(value)
        return future
    }
    
    public static func preRejected(error: Error) -> Future<T> {
        let future = Future<T>()
        future.result = .error(error)
        return future
    }
    
    public func map<Q>(_ block:@escaping (T)->(Q?)) -> Future<Q> {
        let promise = Promise<Q>()
        
        then { (value) in
            if let mapVal = block(value) {
                promise.resolve(mapVal)
            }
            else {
                let cantMapError = NSError.cantMap(value: value, toType: Q.self)
                promise.reject(cantMapError)
            }
        }
        error { (error) in
            promise.reject(error)
        }
        
        return promise.future
    }
    
}

public extension Future {

    public class func joining(_ futures:[Future<T>]) -> Future<[T]> {
        return JoinedFuture(futures).future
    }

}

fileprivate class JoinedFuture<T> {
    
    let future = Future<[T]>()
    
    private var successValues = [T]()
    
    let lockQueue = DispatchQueue(label: "com.concurrency.joinedfuture.\(NSUUID().uuidString)")
    
    init(_ futures: [Future<T>]) {
        let totalCount = futures.count
        
        futures.forEach { (future) in
            future.then { (value) in
                self.lockQueue.sync {
                    if !self.future.isComplete {
                        self.successValues.append(value)
                        if self.successValues.count == totalCount {
                            self.future.resolve(self.successValues)
                        }
                    }
                }
            }.error { (error) in
                self.lockQueue.sync {
                    self.future.reject(error)
                }
            }
        }
    }
    
}

