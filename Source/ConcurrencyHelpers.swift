//  ConcurrencyHelpers.swift
//  Concurrency
//  Created by Jake Hawken on 10/10/17.
//  Copyright © 2017 Jacob Hawken. All rights reserved.

import Foundation

public extension NSError {
    static func cantMap<T, Q>(value: T, toType: Q.Type) -> NSError {
        return CantMapError(value: value, toType: toType)
    }
}

private class CantMapError<Q, T>: NSError {
    private var descriptionString: String
    
    init(value: T, toType: Q.Type) {
        let typeString = String(describing: type(of: Q.self)).replacingOccurrences(of: ".Type", with: "")
        let description = "Concurrency: Could not map value (\(value)) to type \(typeString)."
        self.descriptionString = description
        
        super.init(domain: "com.concurrency.map", code: 0, userInfo: ["description": description])
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.descriptionString = "Mapping Error"
        
        super.init(coder: aDecoder)
        
        if let unarchivedDescription = self.userInfo["description"] as? String {
            self.descriptionString = unarchivedDescription
        }
    }
    
    override var description: String {
        return descriptionString
    }
    
    public static func == (lhs: CantMapError, rhs: CantMapError) -> Bool {
        return lhs.description == rhs.description
    }
}
