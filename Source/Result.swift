//  Result.swift
//  Concurrency
//  Created by Jacob Hawken on 10/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.

import Foundation


public enum Result<T> {
    
    public typealias SuccessBlock = (T)->()
    public typealias ErrorBlock = (Error)->()
    
    case success(T)
    case error(Error)
    
    @discardableResult public func onSuccess(_ successBlock: SuccessBlock) -> Result<T> {
        switch self {
        case .success(let value):
            successBlock(value)
        default:
            break
        }
        return self
    }
    
    @discardableResult public func onError(_ errorBlock: ErrorBlock) -> Result<T> {
        switch self {
        case .error(let error):
            errorBlock(error)
        default:
            break
        }
        return self
    }
    
    public func map<Q>(_ mapBlock: (T)->(Q?)) -> MapResult<Q> {
        switch self {
        case .success(let value):
            if let transformedValue = mapBlock(value) {
                return .success(transformedValue)
            }
            else {
                return .mappingError(value)
            }
        case .error(let previousError):
            return .originalError(previousError)
        }
    }
    
    public func mapSimple<Q>(_ mapBlock: (T)->(Q?)) -> Result<Q> {
        return self.map(mapBlock).simple()
    }
    
    public enum MapResult<Q>: Error, CustomStringConvertible {
        case success(Q)
        case originalError(Error)
        case mappingError(T)
        
        public var description: String {
            switch self {
            case .success:
                return "success"
            case .originalError(let error):
                return "OriginalError: \(error)"
            case .mappingError(let value):
                return "Could not map value: \(value) to output type: \(type(of: Q.self))"
            }
        }
        
        public func simple() -> Result<Q> {
            switch self {
            case .success(let value):
                return .success(value)
            case .originalError(let error):
                return .error(error)
            case .mappingError(let value):
                let error = NSError.cantMap(value: value, toType: Q.self)
                return .error(error)
            }
        }
    }
}
