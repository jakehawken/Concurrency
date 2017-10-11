//  TestHelpers.swift
//  ConcurrencyTests
//  Created by Jake Hawken on 10/11/17.
//  Copyright © 2017 Jacob Hawken. All rights reserved.

import Foundation


func item<T>(_ item: Any?, isA: T.Type, and evalBlock:(T)->(Bool)) -> Bool {
    if let unwrapped = item as? T {
        return evalBlock(unwrapped)
    }
    else {
        return false
    }
}
