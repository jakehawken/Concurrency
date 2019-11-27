//  Result.swift
//  Concurrency
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation

extension Result {
    public typealias SuccessBlock = (Success) -> Void
    public typealias ErrorBlock = (Failure) -> Void
    
    @discardableResult public func onSuccess(_ successBlock: SuccessBlock) -> Result<Success, Failure> {
        switch self {
        case .success(let value):
            successBlock(value)
        default:
            break
        }
        return self
    }
    
    @discardableResult public func onError(_ errorBlock: ErrorBlock) -> Result<Success, Failure> {
        switch self {
        case .failure(let error):
            errorBlock(error)
        default:
            break
        }
        return self
    }
    
    public func map<TargetType>(_ mapBlock: (Success) -> (TargetType?)) -> Result<TargetType, MapError<TargetType>> {
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
    
    var failure: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let value):
            return value
        }
    }
    
    var success: Success? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
}

extension Result {
    public enum MapError<TargetType>: Error, CustomStringConvertible {
        
        case originalError(Failure)
        case mappingError(Success)
        
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
}

extension Result.MapError: Equatable where Failure: Equatable, Success: Equatable {
    public static func == (lhs: Result<Success, Failure>.MapError<TargetType>, rhs: Result<Success, Failure>.MapError<TargetType>) -> Bool {
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
