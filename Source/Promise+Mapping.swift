//  Promise+Mapping.swift
//  Concurrency
//  Created by Jake Hawken on 11/27/19.
//  Copyright © 2019 Jacob Hawken. All rights reserved.

import Foundation

public extension Future {
    
    @discardableResult func mapResult<NewT, NewE: Error>(_ mapBlock:@escaping (Result<T, E>) -> (Result<NewT, NewE>)) -> Future<NewT, NewE> {
        let promise = Promise<NewT, NewE>()
        
        finally { (result) in
            let newResult = mapBlock(result)
            promise.complete(withResult: newResult)
        }
        
        return promise.future
    }
    
    @discardableResult func mapValue<NewValue>(_ mapBlock:@escaping (T) -> (NewValue)) -> Future<NewValue, E> {
        let promise = Promise<NewValue, E>()
        
        onSuccess { (value) in
            let newVal = mapBlock(value)
            promise.resolve(newVal)
        }
        
        return promise.future
    }
    
    @discardableResult func mapError<NewError: Error>(_ mapBlock:@escaping (E) -> (NewError)) -> Future<T, NewError> {
        let promise = Promise<T, NewError>()
        
        onFailure { (error) in
            let newError = mapBlock(error)
            promise.reject(newError)
        }
        
        return promise.future
    }
    
    @discardableResult func flatMap<Q>(_ block:@escaping (T) -> (Q?)) -> Future<Q, Result<T, E>.MapError<Q>> {
        let promise = Promise<Q, Result<T, E>.MapError<Q>>()
        
        finally { (result) in
            let mapped = result.map(block)
            switch mapped {
            case .success(let value):
                promise.resolve(value)
            case .failure(let mapErr):
                promise.reject(mapErr)
            }
        }
        
        return promise.future
    }

    @discardableResult func then<NewValue>(_ mapBlock:@escaping (T)->(Future<NewValue, E>)) -> Future<NewValue, E> {
        let promise = Promise<NewValue, E>()
        
        onSuccess { (value) in
            let newFuture = mapBlock(value)
            promise.resolveOn(future: newFuture)
        }
        
        return promise.future
    }
    
}

public extension Promise {
    
    func resolveOn(future: Future<T, E>) {
        future.onSuccess {
            self.resolve($0)
        }.onFailure {
            self.reject($0)
        }
    }
    
}
