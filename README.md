# Concurrency

[![Version](https://img.shields.io/cocoapods/v/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)
[![License](https://img.shields.io/cocoapods/l/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)
[![Platform](https://img.shields.io/cocoapods/p/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)

Concurrency is a small toolkit for handling concurrency and encapsulating asynchronous work in the Swift programming language. There are several different paradigms for handling concurrency, and I think they each have specific use cases. Most notably, for continuous updates, subscriptions, and streams of data, [RxSwift](https://github.com/ReactiveX/RxSwift) is pretty much king. Concurrency sets out to fill out the other use cases, and, early on, I think I make a fairly solid case why you should never use the old `(ExpectedType?, Error?)->()`-style completion handler ever again.

#### Acknowledgment:
Though I did not consult their source code, my implementation of Promise/Future draws inspiration from my extensive professional and personal __*use of*__ [Deferred](https://github.com/kseebaldt/deferred) and, to a lesser extent, [BrightFutures](https://github.com/Thomvis/BrightFutures).

#### Table of Contents
* [The First Set of Problems to Solve](#the-first-set-of-problems-to-solve)
* [The Cast of Characters](#the-cast-of-characters)
  * [`Result<T>`](#result)
  * [`Promise<T>` and `Future<T>`](#promise-and-future)
    * [The concept](#the-concept)
    * [Providing Futures](#providing-futures)
  * [`Periodic Fetcher`](#periodic-fetcher)
* [Requirements & Dependencies](#requirements-and-dependencies)
* [Installation](#installation)
* [Author](#author)
* [License](#license)

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

This also reveals the other major problem with this pattern: Did you notice there's no `else` case? Despite covering the two logically expected result states, this is an incomplete logical statement. Horrifyingly, the nature of the callback's signature allows for the possibility of both arguments to be nil, which is a state that makes absolutely no sense to the consumer. But the fact that it's possible means that they're kind of forced to handle it.

Unwrapping optionals is already something that Swift developers have to do too often anyway, and nobody likes ambiguous, potentially incoherent states of affairs, so what's the solution? Enter stage left: My good buddy `Result<T>`.

## The Cast of Characters

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

However, this brings me to the other option `Result` gives you. __Sweet, sweet syntactic sugar!__ I've included some functional-style methods on `Result` which will be very familiar to anyone who's worked with RxSwift. I've included `onSuccess` and `onError` methods which allow the consumer to implement success blocks and error blocks independently of one another. That means the consumer can implement one, the other, both, or neither. AND, since each of those methods returns a discardable reference to the Result, the consumer can easily chain them, as you can see below.

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

So, when we have to use completion blocks, `Result` is a nice, clean, compiler-aided, unwrap-free option. But is there something beyond completion handlers? More on that in a moment.

#### The other problem with completion blocks: [BLOCKCEPTION!](https://www.youtube.com/watch?v=L6aT_oEhIKo)

You see, often, asynchronous work relies on other asynchronous work. In a world of traditional completion blocks, this means, at very least, writing a method that has a completion handler, which in turn calls a method which has a completion handler. And god forbid your asynchronous method need to call multiple completion blocks in succession. Then, even if you only implement the success blocks (yikes!) you'd still end up with a nightmare like this:

```Swift
func getAStringWithTwoNumbersInIt(_ completionHandler:(Result<String>)->()) {
  getString1 { result1 in
    result1.onSuccess { int1 in
      getString2 { result2 in
        result1. onSuccess { int2 in
           completionHandler(.success("I got \(int1) and \(int2)! Yay!"))
        }
      }
    }
  }
}
```

#### The Pyramid of Doom: It's not just for optional binding anymore!
So, how do we solve this?

### Promise and Future

If you've never been exposed to the concept of [promises and/or futures](https://en.wikipedia.org/wiki/Futures_and_promises), hoo boy am I absolutely delighted to be the one to tell you about them!

#### The concept

The concept is fairly simple: A future (in some paradigms called a "delay" or an "eventual") is an object that acts as a stand-in for a future result. So if you write an asynchronous method that uses futures instead of completion blocks, the future is returned synchronously. The future represents the chunk of asynchronous work being performed by the method that returned it, and is responsible for handling its completion.

So, if you had a method that looked like this with a completion block:

```Swift
func askForHerPhoneNumber(_ completionHandler:(Int?, Error?)->())
```

it would look like this, using a `Future`:

```Swift
func askForHerPhoneNumber() -> Future<Int>
```
#### Providing Futures

This is where `Promise<T>` comes in. `Promise` pretty much has one purpose: It vends a `Future`, and is responsible for resolving or rejecting it. That's it.

So, if you were writing a method that returns a promise solely for the purpose of encapsulating another method that uses a traditional completion block, it might look like this:

```Swift
func goCallYourMother() -> Future<AnEarful> {
  let promise = Promise<AnEarful>()
  
  callYourMotherWithCompletion { (earful, error) in
    if let earful = earful {
      promise.resolve(earful)
    }
    else if let error = error {
      promise.reject(error)
    }
    else {
      let noDataError = NSError(domain: "Somehow, this happened. Seriously.", code: 666, userInfo: nil)
      promise.reject(noDataError)
    }
  }
  
  return promise.future
}
```

The key features here are: 
1) Synchronously, you create a Promise, and then you return the promise's Future.
2) On completion of the asynchronous work, you either call the `resolve(_:)` method on the promise and pass in the success value, or the `reject(_:)` method and pass in an `Error`.

#### Consuming futures

This is where it gets fun, boys and girls!

`Future` has two `typealias`ed block types, `ThenBlock` (`(T)->()`) and `ErrorBlock` (`(Error)->()`), and it has two public methods which take them as arguments. These two methods are your bread and butter:

`then(_:)` and `error(_:)`

Calling these give the future its completion behavior. If somehow the call comes back before either of these are set, they'll simply be called as soon as they're set. Easy-peasy.

So, consuming the future is done like so:

```Swift
let future: Future<AnEarful> = goCallYourMother()
future.then { (earful) in
  self.hooBoy(earful)
}.error { (error) in
  self.wellAtLeastITried(error)
}
```

or, if you want to be even more concise, there's no need to assign the future to a variable:

```Swift
goCallYourMother().then { (earful) in
  self.hooBoyWhatAn(earful)
}.error { (error) in
  self.wellAtLeastITried(error)
}
```

As you can see, much like the `onSuccess(_:)` and `onError(_:)` methods on [`Result`](#result), these return discardable references to the promise and can thus be chained and used together or independently of one another.

[MORE TO COME]

### Periodic Fetcher

[MORE TO COME]

## Requirements and Dependencies

`PeriodicFetcher` uses the [RxSwift](https://github.com/ReactiveX/RxSwift) library. This is included as a dependency and requires no extra setup other than running the 'pod install' command found below.

The Rakefile in this repo makes use of the [Synx](https://github.com/venmo/synx) tool by Venmo as well as [XCPretty](https://github.com/supermarin/xcpretty). Running `rake setup` will install these dependencies.

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
