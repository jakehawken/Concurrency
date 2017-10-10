//  Promise.swift
//  Concurrency
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation


class Promise<T> {

    let future = Future<T>()

    func resolve(_ val: T) {
        future.resolve(val)
    }

    func reject(_ err: Error) {
        future.reject(err)
    }

}

class Future<T> {
    typealias ThenBlock  = (T)->()
    typealias ErrorBlock = (Error)->()

    private var thenBlock: ThenBlock?
    private var errorBlock: ErrorBlock?
    private var childFuture: Future?

    private let operationQueue = OperationQueue()

    //MARK: - PUBLIC -

    private(set) var value: T?
    private(set) var error: Error?

    public var succeeded: Bool {
        return value != nil
    }

    public var failed: Bool {
        return error != nil
    }

    public var isComplete: Bool {
        return succeeded || failed
    }

    @discardableResult public func then(_ callback: @escaping ThenBlock) -> Future<T> {
        operationQueue.addOperation {
            if let value = self.value { //If the future has already been resolved with a value. Call the block immediately.
                callback(value)
            }
            else if self.thenBlock == nil {
                self.thenBlock = callback
            }
            else {
                self.appendChild().then(callback)
            }
        }
        return self
    }

    @discardableResult public func error(_ callback: @escaping ErrorBlock) -> Future<T> {
        operationQueue.addOperation {
            if let error = self.error { //If the future has already been rejected with an error. Call the block immediately.
                callback(error)
            }
            else if self.errorBlock == nil {
                self.errorBlock = callback
            }
            else {
                self.appendChild().error(callback)
            }
        }
        return self
    }
    
    //MARK: - PRIVATE
    
    fileprivate func resolve(_ val: T) {
        operationQueue.addOperation {
            if self.isComplete {
                return
            }
            
            self.value = val
            
            self.thenBlock?(val)
            self.childFuture?.resolve(val)
        }
    }
    
    fileprivate func reject(_ err: Error) {
        operationQueue.addOperation {
            if self.isComplete {
                return
            }
            
            self.error = err
            
            self.errorBlock?(err)
            self.childFuture?.reject(err)
        }
    }
    
    private func appendChild() -> Future<T> {
        if let child = childFuture {
            return child.appendChild()
        }
        let future = Future<T>()
        childFuture = future
        return future
    }
}
