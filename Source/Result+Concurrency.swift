//  Result.swift
//  Concurrency
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation

//swiftlint:disable line_length
public extension Result {
    
    typealias SuccessBlock = (Success) -> Void
    typealias ErrorBlock = (Failure) -> Void
    
    /**
    Convenience block for adding functional-style chaining to `Result`.
    
    - Parameter successBlock: The block to be executed on success. Block takes a single argument, which is of the `Success` type of the result. Executes if success case. Does not execute if failure case.
    - returns: The future iself, as a `@discardableResult` to allow for chaining.
    */
    @discardableResult func onSuccess(_ successBlock: SuccessBlock) -> Result<Success, Failure> {
        switch self {
        case .success(let value):
            successBlock(value)
        default:
            break
        }
        return self
    }
    
    /**
    Convenience block for adding functional-style chaining to `Result`.
    
    - Parameter errorBlock: The block to be executed on failure. Block takes a single argument, which is of the `Error` type of the result. Executes if failure case. Does not execute if success case.
    - returns: The future iself, as a `@discardableResult` to allow for chaining.
    */
    @discardableResult func onError(_ errorBlock: ErrorBlock) -> Result<Success, Failure> {
        switch self {
        case .failure(let error):
            errorBlock(error)
        default:
            break
        }
        return self
    }
    
    /**
    Maps from one the given result to a new one. The generated result has an informative error type which clearly delineates if the error was in the original result or as a result of mapping. The type of the error is `MapError<T,E,Q>` where Q is the desired mapped value. If the first result is a failure, the error for the mapped result will be `.originalError` with the original error as an associated value. If the the first result is a success but the map block returns `nil`, then the error for the mapped result will be `.mappingError` with the unmappable value as the associated value (e.g. If passing `5` into the mapBlock causes the block to return nil, the error for the new result will be `.mappingError(5)`).
    
    - Parameter mapBlock: The mapping block, which is executed if the first result is a success. The block takes a single argument, which is of the success type `Success` of the original future, and returns an optional: `TargetType?`. TargetType is the desired mapped value.
    - returns: A new result where Success type is `TargetType` and the error type is `MapError<Success, Failure, TargetType>`
    */
    func flatMap<TargetType>(_ mapBlock: (Success) -> (TargetType?)) -> Result<TargetType, MapError<Success, Failure, TargetType>> {
        switch self {
        case .success(let value):
            if let transformedValue = mapBlock(value) {
                return .success(transformedValue)
            }
            else {
                return .failure(.mappingError(value))
            }
        case .failure(let previousError):
            return .failure(.originalError(previousError))
        }
    }
    
    /// Convenience property for converting the state of result into an optional `Failure`. Returns nil in success case.
    var failure: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let value):
            return value
        }
    }
    
    /// Convenience property for converting the state of result into an optional `Success`. Returns nil in failure case.
    var success: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
}

/**
 MapError is an Error type for encapsulating the mapping of one Success/Error pairing to another. Initially built for Result, but could just as well be used for Future or any other type which involves a Success/Error pair.
 
 The intended use is for capturing both the possible failure state of the original result as well as the possible failed mapping of a success value.
 
 For example, let's say we have a result of type `Result<Int, NSError>`, and wanted to map it to a result of with a Success type of `Bool`. If our first result was `.success(5)` that's not a value that can be mapped to Bool. If failure to map and failure to get the integer had different relevance, this wouuld be a good use case for a `MapError<Int, NSError, Bool>`, on which the `.success(5)` on the first result would map to the MapError state of `.mappingError(5)`
 
 For the original example, look at the usage on `Result.map<TargetType>(_:)`
*/
public enum MapError<SourceType, SourceError, TargetType>: Error, CustomStringConvertible {
    case originalError(SourceError)
    case mappingError(SourceType)
    
    public var description: String {
        switch self {
        case .originalError(let error):
            return "OriginalError: \(error)"
        case .mappingError(let itemToMap):
            let typeString = String(describing: TargetType.self)
            return "Could not map value: (\(itemToMap)) to output type: \(typeString)."
        }
    }
}

extension MapError: Equatable where SourceType: Equatable, SourceError: Equatable {
    
    public static func == (lhs: MapError, rhs: MapError) -> Bool {
        switch (lhs, rhs) {
        case (.originalError(let error1), .originalError(let error2)):
            return error1 == error2
        case (.mappingError(let value1), .mappingError(let value2)):
            return value1 == value2
        default:
            return false
        }
    }
    
}
