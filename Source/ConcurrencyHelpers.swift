//  ConcurrencyHelpers.swift
//  Concurrency
//  Created by Jake Hawken on 10/10/17.
//  Copyright © 2017 Jacob Hawken. All rights reserved.

import Foundation


extension NSError {
    static func cantMap<T,Q>(value:T, toType: Q.Type) -> NSError {
        let typeString = String(describing: type(of: Q.self)).replacingOccurrences(of: ".Type", with: "")
        let description = "Could not map value (\(value)) to type \(typeString)."
        return NSError(domain: description, code: 0, userInfo: nil)
    }
}
