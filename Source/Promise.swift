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
    
    private var thenBlocks:  [ThenBlock]  = []
    private var errorBlocks: [ErrorBlock] = []
    
    private let operationQueue = OperationQueue()
    
    //MARK: - PUBLIC -
    
    private(set) var value: T?
    private(set) var error: Error?
    
    var succeeded: Bool {
        return value != nil
    }
    
    var failed: Bool {
        return error != nil
    }
    
    var isComplete: Bool {
        return succeeded || failed
    }
    
    @discardableResult func then(_ callback: @escaping ThenBlock) -> Future<T> {
        operationQueue.addOperation {
            if let value = self.value { //If the future has already been resolved with a value. Call the block immediately.
                callback(value)
            }
            else {
                self.thenBlocks.append(callback)
            }
        }
        return self
    }
    
    @discardableResult func error(_ callback: @escaping ErrorBlock) -> Future<T> {
        operationQueue.addOperation {
            if let error = self.error { //If the future has already been rejected with an error. Call the block immediately.
                callback(error)
            }
            else {
                self.errorBlocks.append(callback)
            }
        }
        return self
    }
    
    fileprivate func resolve(_ val: T) {
        operationQueue.addOperation {
            if self.isComplete {
                return
            }
            
            self.value = val
            
            self.thenBlocks.forEach({ (thenBlock) in
                thenBlock(val)
            })
        }
    }
    
    fileprivate func reject(_ err: Error) {
        operationQueue.addOperation {
            if self.isComplete {
                return
            }
            
            self.error = err
            
            self.errorBlocks.forEach({ (errorBlock) in
                errorBlock(err)
            })
        }
    }
}
