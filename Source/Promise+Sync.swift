//  Promise+Sync.swift
//  Concurrency
//  Created by Jake Hawken on 11/27/19.
//  Copyright © 2019 Jacob Hawken. All rights reserved.

import Foundation

private func blockTilCompletionOf<T, E: Error>(future: Future<T, E>, timeout: TimeInterval) {
    let semaphore = DispatchSemaphore(value: 0)
    future.finally { (_) in
        semaphore.signal()
    }
    Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { (timer) in
        timer.invalidate()
        semaphore.signal()
    }
    semaphore.wait()
}

public extension Future {
    @discardableResult func block(timeout: TimeInterval = 2) -> Future<T, E> {
        blockTilCompletionOf(future: self, timeout: timeout)
        return self
    }
}
