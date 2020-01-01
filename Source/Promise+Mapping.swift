//  Promise+Mapping.swift
//  Concurrency
//  Created by Jake Hawken on 11/27/19.
//  Copyright © 2019 Jacob Hawken. All rights reserved.

import Foundation

//swiftlint:disable line_length
public extension Future {
    
    /**
    Mutation method. Generates a new Future with potentially different success and/or error types.
     
     Example:
     ```
     let myFuture = Promise<Int, MyIntError>.future
     let myNewFuture = myFuture.mapResult { (result) -> Result<String, MyStringError>
        switch result {
        case .success(let firstValue):
            if firstValue < 5 {
                return .success("\(firstValue)")
            }
            else {
                return .failure(.couldntMakeString)
            }
        case .failure(let firstError):
            return .failure(.couldntGetInt)
        }
     }
     // Returns a future of type Future<String, MyStringError>
     ```
    
    - Parameter mapBlock: The mapping block, which is executed on completion of the future. The block takes a single argument, which is of the `Result<T,E>` of the original future, and returns a `Result` with a different success and/or error type.
    - returns: The new future, as a `@discardableResult` to allow for the chaining of mutation/callback methods.
    */
    @discardableResult func mapResult<NewT, NewE: Error>(_ mapBlock:@escaping (Result<T, E>) -> (Result<NewT, NewE>)) -> Future<NewT, NewE> {
        let promise = Promise<NewT, NewE>()
        
        finally { (result) in
            let newResult = mapBlock(result)
            promise.complete(withResult: newResult)
        }
        
        return promise.future
    }
    
    /**
    Mutation method. Generates a new Future with a different success type, but the same error type. If the first future fails, the error will be passed through to the new future. Ideal when there is not a new possible failure stage introduced by the mutation.
     
     Example:
     ```
     let myFuture = Promise<Int, MyIntError>.future
     let myNewFuture = myFuture.mapValue { (firstValue)
        return "\(firstValue)"
     }
     // Returns a future of type Future<String, MyIntError>
     ```
    
    - Parameter mapBlock: The mapping block, which is executed on completion of the future. The block takes a single argument, which is of the success type `T` of the original future, and returns a value of the success type `NewValue` of the new future.
    - returns: The new future, as a `@discardableResult` to allow for the chaining of mutation/callback methods.
    */
    @discardableResult func mapValue<NewValue>(_ mapBlock:@escaping (T) -> (NewValue)) -> Future<NewValue, E> {
        let promise = Promise<NewValue, E>()
        
        onSuccess { (value) in
            let newVal = mapBlock(value)
            promise.resolve(newVal)
        }
        onFailure { (error) in
            promise.reject(error)
        }
        
        return promise.future
    }
    
    /**
    Mutation method. Generates a new Future with the same success type, but a different error type. If the first future succeeds, the success value will be passed through to the new future. Ideal for when a more domain-specific error is needed.
     
     Example:
     ```
     let myFuture = Promise<Int, MyIntError>.future
     let myNewFuture = myFuture.mapError { (firstError)
        return MyErrorType(message: "Couldn't get the integer.")
     }
     // Returns a future of type Future<Int, MyErrorType>
     ```
    
    - Parameter mapBlock: The mapping block, which is executed on completion of the future. The block takes a single argument, which is of the error type `E` of the original future, and returns a value of the error type `NewError` of the new future.
    - returns: The new future, as a `@discardableResult` to allow for the chaining of mutation/callback methods.
    */
    @discardableResult func mapError<NewError: Error>(_ mapBlock:@escaping (E) -> (NewError)) -> Future<T, NewError> {
        let promise = Promise<T, NewError>()
        
        onFailure { (error) in
            let newError = mapBlock(error)
            promise.reject(newError)
        }
        onSuccess { (value) in
            promise.resolve(value)
        }
        
        return promise.future
    }
    
    /**
    Mutation method. Generates a new future, similarly to `mapResult(_:)`, but uses a failable block, which allows the success case of the first future to potentially trigger a failure state for the generated future.
     
    Piggybacks on the `map(_:)` extension method on `Result`. The error type of the new future is `MapError<T,E,Q>` where Q is the desired mapped value. If the first future fails, the error for the generated future will be the `.originalError` case with the original error as an associated value. If the the first future succeeds but the map block returns nil, then the error for the generated future will be the `.mappingError` case with the unmappable value as the associated value.
     
     Example:
     ```
     let myFuture = Promise<Int, MyIntError>.future
     let myNewFuture = myFuture.flatMap { (intValue) -> String?
        return (intValue < 5) ? "\(intValue)" : nil
     }
     // Returns a future of type Future<String, MapError<Int, MyIntError, String>
     ```
    
    - Parameter mapBlock: The mapping block, which is executed on the success of the future. The block takes a single argument, which is of the success type `T` of the original future, and returns an optional `Q?` of the value of the new future. If this block returns `nil`, the generated future will fail with the error `.mappingError` with the argument of the block as an associated value. (In the example above, if `6` is passed into the block, `myNewFuture` will fail with `.mappingError(6)`.)
    - returns: The new future, as a `@discardableResult` to allow for the chaining of mutation/callback methods.
    */
    @discardableResult func flatMap<Q>(_ mapBlock:@escaping (T) -> (Q?)) -> Future<Q, MapError<T, E, Q>> {
        let promise = Promise<Q, MapError<T, E, Q>>()
        
        finally { (result) in
            result.flatMap(mapBlock).onSuccess { (value) in
                promise.resolve(value)
            }.onError { (mapError) in
                promise.reject(mapError)
            }
        }
        
        return promise.future
    }
    
    /**
    Chaining method. Takes in a block which will generate a new future, contingent upon the success of the first future. This allows for multiple, serial, asynchronous calls to be chained.
     
     This method bears some similarity to `mapResult(_:)` but in this method, the consumer is responsible for generating the second future, as this method is for *chaining* rather than merely *mapping*.
     
     Example:
     ```
     // Assuming the methods `getPhoneNumber() -> Future<Int, PhoneNumberError>`
     // and `makePhoneCall(toPhoneNumber: Int) -> Future<PhoneResponse, WrongNumberError>
     // we are able to write the following using a function pointer:
     let phoneCallFuture = getPhoneNumber().then(makePhoneCall(toPhoneNumber:))
     
     // or write The same thing using a traditional Swift block:
     let phoneCallFuture = getPhoneNumber().then { (number) in
        return makePhoneCall(toPhoneNumber: number)
     }
     ```
    
    - Parameter mapBlock: A block called on success of the original future, which takes in the success value and returns a new Future. The ideal use case is when you have two sets of asynchronous work in which one depends upon the success of the other.
    - returns: A new future, with the same value and error types as the Future returned by the map block. Returned as a `@discardableResult` to facilitate additional chaining.
    */
    @discardableResult func then<NewValue, NewError: Error>(_ mapBlock:@escaping (T)->(Future<NewValue, NewError>)) -> Future<NewValue, NewError> {
        let promise = Promise<NewValue, NewError>()
        
        onSuccess { (value) in
            let newFuture = mapBlock(value)
            promise.completeOn(future: newFuture)
        }
        
        return promise.future
    }
    
}

public extension Promise {
    
    /**
    Convenience method for completing a promise based on the result of a given future with the same generic types.
    
    - Parameter future: A future with the same success and error types as the promise. On completion of the future, the corresponding completion state will be triggered on the promise.
    */
    func completeOn(future: Future<T, E>) {
        future.finally(complete(withResult:))
    }
    
}

extension Future {
    
    /// Uses `mapError(_:)` and employs the automatic bridging to NSError that is included in Foundation's Objective-C/Swift interoperability.
    @discardableResult public func mapToNSError() -> Future<T, NSError> {
        return mapError { $0 as NSError }
    }
    
    /// Convenience method for type erasure of a future.
    @discardableResult public func typeErased() -> Future<Any, NSError> {
        return mapValue { (value) -> Any in
            return value
        }
        .mapToNSError()
    }

}
