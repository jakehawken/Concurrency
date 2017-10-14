# Concurrency

[![Version](https://img.shields.io/cocoapods/v/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)
[![License](https://img.shields.io/cocoapods/l/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)
[![Platform](https://img.shields.io/cocoapods/p/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)

Concurrency is a small toolkit for handling concurrency and encapsulating asynchronous work in the Swift programming language. There are several different paradigms for handling concurrency, and I think they each have specific use cases. Most notably, for continuous updates, subscriptions, and streams of data, [RxSwift](https://github.com/ReactiveX/RxSwift) is pretty much king. Concurrency sets out to fill out the other use cases, and, early on, I think I make a fairly solid case why you should never use the old `(ExpectedType?, Error?)->()`-style completion handler ever again.

__Table of Contents__
* [The Cast of Characters](#the-cast-of-characters)
* [The First Set of Problems to Solve](#the-first-set-of-problems-to-solve)
* [`Result<T>`](#result)
* [`Promise<T>` and `Future<T>`](#promise-and-future)
* [`Periodic Fetcher`](#periodic-fetcher)

## The Cast of Characters
Concurrency contains three main types: `Promise`, `Result`, and `PeriodicFetcher`.

`Result` is a [result type](https://en.wikipedia.org/wiki/Result_type) for encapsulating the success/error state of a callback.

`Promise` is a promise/future implementation inspired by [BrightFutures](https://github.com/Thomvis/BrightFutures) and [Deferred](https://github.com/kseebaldt/deferred).

And finally, `PeriodicFetcher`is a tool for taking a single async operation and turning it into a recurring operation which emits an RxSwift stream.

## The First Set of Problems to Solve

Let's face it: completion handlers in Swift are a total pain. Really quickly, let's break down everything obnoxious about the standard callback pattern in Swift:

```Swift
func getAString(_ completionHandler: (String?, Error?)->())
```

First off, this requires the consumer of this function to have to unrwap two different values to figure out the actual state of affairs, which ends up resulting in the user having to implement a lengthy `switch` or `if`/`else if`/`else` block to handle it.

```Swift
getAString { (string, error) in
  if let string = string {
    self.doSuccessThingy(string)
  }
  else if let error = error {
    self.doErrorThingy(error)
  }
}
```

The user has to type this all this logic out by hand, gets no autocomplete, and no help from the compiler about missed logical cases.

This also reveals the other major problem with this pattern: Did you notice there's no else case? Despite covering the two logically expected result states, this is an incomplete logical statement. Horrifyingly, the nature of the callback's signature allows for the possibility of both arguments to be nil, which is a state that makes absolutely no sense to the consumer. But the fact that it's possible means that they're kind of forced to handle it.

Unwrapping optionals is already something that Swift developers have to do too often anyway, and nobody likes ambiguous, potentially incoherent states of affairs, so what's the solution? Enter stage left: My good buddy `Result<T>`.

### Result

Swift enums to the rescue! Seriously, Swift's immensely powerful enums are probably my favorite part of the language. And `Result` is an excellent example of why. In the example above, the method signature has a callback that passes back two optional values. `Result` allows you to collapse that down to a single, non-optional value, like so:

```Swift
func getAString(_ completionHandler: (Result<String>)->())
```

`Result` is a generically typed enum with two cases. A success case with an associated value of whatever the generic type is, and an error case with an associated value of anything conforming to the `Error` protocol.

This allows the handling of the callback to take one of a couple different forms. Firstly, a switch statement:

```Swift
getAString { (result) in
  switch result {
  case .success(let value):
    self.doSuccessThingy(value)
  case .error(let error):
    self.doErrorThingy(error)
  }
}
```

While not objectively much more concise than the previous example, a lot of this will be autocompleted by Xcode, and the compiler will let you know if your switch statement is missing a case.

However, this brings me to the other option `Result` gives you. __Sweet, sweet syntactic sugar!__ I've included some functional-style methods on `Result` which will be very familiar to anyone who's worked with RxSwift before. I've included `onSuccess` and `onError` methods which allow the consumer to implement success blocks and error blocks independently of one another, so they can do one, the other, or both.

#### Both:

```Swift
getAString { (result) in
  result.onSuccess { (value) in
    self.doSuccessThingy(value)
  }.onError { (error) in
    self.doErrorThingy(error)
  }
}
```

#### or just one:

```Swift
getAString { (result) in
  result.onSuccess { (value) in
    self.doSuccessThingy(value)
  }
}
```

So, when we have to use completion blocks, `Result` is a nice, clean, compiler-aided, unwrap-free option. But if there something beyond completion handlers?

#### The other problem with completion blocks: [BLOCKCEPTION!](https://www.youtube.com/watch?v=L6aT_oEhIKo)

Often, asynchronous work relies on other asynchronous work. In a world of traditional completion blocks, this means, at very least, writing a method that has a completion handler, which calls a method which has a completion handler. And god forbid your asynchronous method need to call multiple completion blocks in succession. Then, even if you only implement the success blocks (yikes!) you'd still end up with a nightmare like this:

```Swift
func getAStringWithTwoNumbersInIt(_ completionHandler:(Result<String>)->()) {
  getString1 { result1 in
    result1.onSuccess { int1 in
      get String2 { result2 in
        result1. onSuccess { int2 in
           completionHandler(.success("I got \(int1) and \(int2)! Yay!"))
        }
      }
    }
  }
}
```

#### The Pyramid of Doom: It's not just for optional binding anymore! So, how do we solve this?

### Promise and Future

[STILL BEING WRITTEN]

## Requirements

`PeriodicFetcher` uses the [RxSwift](https://github.com/ReactiveX/RxSwift) library. This is included as a dependency and requires no extra setup other than running the 'pod install' command.
The included Rakefile makes use of the [Synx](https://github.com/venmo/synx) tool by Venmo as well as [XCPretty](https://github.com/supermarin/xcpretty). Running `rake setup` will install these dependencies.

## Installation

Concurrency is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Concurrency"
```

## Author

Jake Hawken, www.github.com/jakehawken

## License

Concurrency is available under the MIT license. See the LICENSE file for more info.
