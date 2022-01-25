# Concurrency

[![Version](https://img.shields.io/cocoapods/v/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)
[![License](https://img.shields.io/cocoapods/l/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)
[![Platform](https://img.shields.io/cocoapods/p/Concurrency.svg?style=flat)](http://cocoapods.org/pods/Concurrency)

Concurrency is a small toolkit for handling concurrency and encapsulating asynchronous work in the Swift programming language. There are several different paradigms for handling concurrency, and I think they each have specific use cases. Most notably, for continuous updates, subscriptions, and streams of data, [RxSwift](https://github.com/ReactiveX/RxSwift) is pretty much king. Concurrency sets out to fill out the other use cases, and, early on, I think I make a fairly solid case why you should never use the old `(ExpectedType?, Error?)->()`-style completion handler ever again.

#### Acknowledgment
Though I did not consult their source code, my implementation of Promise/Future draws inspiration from my extensive professional and personal __*use of*__ [Deferred](https://github.com/kseebaldt/deferred) and [BrightFutures](https://github.com/Thomvis/BrightFutures).

#### Table of Contents
- [Concurrency](#concurrency)
      - [Acknowledgment](#acknowledgment)
      - [Table of Contents](#table-of-contents)
  - [The First Set of Problems to Solve](#the-first-set-of-problems-to-solve)
  - [The Cast of Characters](#the-cast-of-characters)
    - [Result](#result)
      - [Both:](#both)
      - [or just one:](#or-just-one)
      - [The problem with completion blocks: BLOCKCEPTION!](#the-problem-with-completion-blocks-blockception)
      - [The Pyramid of Doom: It's not just for optional binding anymore!](#the-pyramid-of-doom-its-not-just-for-optional-binding-anymore)
    - [Promise and Future](#promise-and-future)
      - [The concept](#the-concept)
      - [Providing Futures](#providing-futures)
      - [Consuming futures](#consuming-futures)
      - [Mutation](#mutation)
        - [Map Result](#map-result)
        - [Map Value](#map-value)
        - [Map Error](#map-error)
        - [Flatmap](#flatmap)
        - [MapError&lt;T, E, Q&gt;](#maperrorltt-e-qgt)
      - [Chaining](#chaining)
        - [Then](#then)
        - [Zip](#zip)
        - [First Finished](#first-finished)
      - [One last thing...](#one-last-thing)
- [Conclusion](#conclusion)
  - [Installation](#installation)
  - [Author](#author)
  - [License](#license)

## The First Set of Problems to Solve

Let's face it: completion handlers in Swift can be pain. Really quickly, let's break down everything obnoxious about the standard callback pattern in Swift:

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

Unwrapping optionals is already something that Swift developers have to do too often anyway, and nobody likes ambiguous, potentially incoherent states of affairs, so what's the solution? Enter stage left: My good buddy Result.

## The Cast of Characters

### Result

`Result<Success, Failure>` was added in Swift 5, and the people rejoiced. "The people" in this case being everyone who hates `(Success?, Error?)->(`) completion blocks, which, after reading my excellent arguments above, now includes you. In pre-2.0 versions of Concurrency, it included a Result type, but instead it now includes a bunch of extension methods/properties on Swift's native Result.

And what do those extensions buy you? Why, *__Sweet, sweet syntactic sugar, of course!__* I've included some functional-style methods onto Result which will be very familiar to anyone who's worked with other Promise/Future libraries or with reactive frameworks like RxSwift. I've included `onSuccess(_:)` and `onError(_:)` methods which allow the consumer to implement success blocks and error blocks independently of one another. That means the consumer can implement one, the other, both, or neither. AND, since each of those methods returns a discardable reference to the Result, the consumer can easily chain them, as you can see below.

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

So, when we have to use completion blocks, these extensions on `Result` provide a nice, clean, compiler-aided, unwrap-free option.

#### The problem with completion blocks: [BLOCKCEPTION!](https://www.youtube.com/watch?v=L6aT_oEhIKo)

You see, often, asynchronous work relies on other asynchronous work. In a world of traditional completion blocks, this means, at very least, writing a method that has a completion handler, which in turn calls a method which has a completion handler. And god forbid your asynchronous method need to call multiple completion blocks in succession. Then, even if you only implement the success blocks (yikes!) you'd still end up with a nightmare like this:

```Swift
func getAStringWithTwoNumbersInIt(_ completionHandler:(Result<String, MyError>)->()) {
  getInt1 { result1 in
    result1.onSuccess { int1 in
      getInt2 { result2 in
        result1.onSuccess { int2 in
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
func askForHerPhoneNumber(_ completionHandler:(Int?, NSError?)->())
```

it would look like this, using a Future:

```Swift
func askForHerPhoneNumber() -> Future<Int, NSError>
```
#### Providing Futures

This is where `Promise<T,E>` comes in. Promise pretty much has one purpose: It vends a `Future<T,E>`, and is responsible for resolving or rejecting it. That's it.

So, if you were writing a method that returns a promise solely for the purpose of encapsulating another method that uses a traditional completion block, it might look like this:

```Swift
func goCallYourMother() -> Future<AnEarful, CallError> {
  let promise = Promise<AnEarful, CallError>()

  callYourMotherWithCompletion { (earful, error) in
    if let earful = earful {
      promise.resolve(earful)
    }
    else if let error = error {
      promise.reject(error)
    }
    else {
      let noDataError = CallError(message: "No data returned by the call.")
      promise.reject(noDataError)
    }
  }

  return promise.future
}
```

The key features here are:
1) Synchronously, you create a Promise, and then you return the promise's Future.
2) On completion of the asynchronous work, you either call the `resolve(_:)` method on the promise and pass in the success value, or the `reject(_:)` method and pass in an error of type `E`. You determine the type of error you expect when you create the Promise.

#### Consuming futures

This is where it gets fun, boys and girls!

Future has two `typealias`-ed block types, `SuccessBlock` (`(T)->()`) and `ErrorBlock` (`(E)->()`), and it has two public methods which take them as arguments. These two methods are your bread and butter:

`onSuccess(_:)` and `onError(_:)`

Calling these give the future its completion behavior. If somehow the call comes back before either of these are set, the passed in blocks will simply be executed as soon as they're passed in. Easy-peasy.

So, consuming the future is done like so:

```Swift
let future: Future<AnEarful, PhoneCallError> = goCallYourMother()
future.onSuccess { (earful) in
  self.hooBoy(earful)
}.onError { (error) in
  self.wellAtLeastITried(error)
}
```

or, if you want to be even more concise, since these methods all return `@discardableResult` references, there's no need to assign the future to a variable at all:

```Swift
goCallYourMother().onSuccess { (earful) in
  self.hooBoyWhatAn(earful)
}.onError { (error) in
  self.wellAtLeastITried(error)
}
```

__Side note:__ There's also a handy `finally(_:)` method as well, which will add a block to be executed after completion, regardless of success or failure. It executes after the given success or failure block, and is passed a `Result<T,E>` as its one argument.

The real magic about Future is that `onSuccess(_:)` and `onError(_:)` can be called as many times as needed, and each of the actions will execute in order. So, if you have a method which fetches a value and returns a promise, and there are multiple layers of the app that need to be updated with that value, you can pass that future along from method to method, tacking on success actions as you go.

Yes, I know, an example is in order. So, let's say we have that same method from earlier: `func goCallYourMother() -> Future<AnEarful, PhoneCallError>`. We could propagate it along like so:

```Swift
func callYourMomAndThenReflect() -> Future<AnEarful, PhoneCallError> {
  return goCallYourMother().onSuccess { (earful) in
    self.hooBoyWhatAn(earful) // a local action that needs to happen
  }.onError { (error) in
    self.wellAtLeastITried(error) //also a local action that needs to happen
  }
}
```

So we've called a method that gets a future, tacked on a `SuccessBlock` and an `ErrorBlock` and then immediately returned that future to whoever consumed this method. The next consumer can do the same, and on and on, and as soon as the initial call completes, it will bubble up completions or errors, all the way up the chain, in order, to the last block(s) added.

But, you ask, what if the values you need at the different layers of your application are of different types?

_Say no more. I got u, fam._

#### Mutation

Future has a swiss army knife of mutation methods, which those familiar with Rx might find familiar. These allow for the mapping of values (`T`), errors (`E`), and combinations of the two. The first of which, does a total mapping:

##### Map Result
```Swift
@discardableResult func mapResult<NewT, NewE: Error>(_ mapBlock:@escaping (Result<T, E>) -> (Result<NewT, NewE>)) -> Future<NewT, NewE>
```

This generates a new Future with potentially different success and/or error types. When you call it, you pass in a mapping block. That block is called on completion of the first  translates from a `Result<T,E>` matching the `T` and `E` of your future to a `Result<NewT, NewE>` matching the types on your new future. This automatically generates a `Future<NewT, NewE>`, which completes accordingly whenever the first future completes.

This allows you to map both types with one method, like this:

```Swift
let myIntFuture: <Int, MyIntError> = getThatInt()
let myStringFuture = myIntFuture.mapResult { (result) -> Result<String, MyStringError>
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
// myStringFuture will be of type Future<String, MyStringError>
```

##### Map Value

Now, let's imagine that we have a future that goes and gets a phone number, but it gets it as an integer. Then imagine we want to fetch that, but we want it as a string. So, we want to map the value, but don't feel the need to change the error type. 

```Swift
@discardableResult func mapValue<NewValue>(_ mapBlock:@escaping (T) -> (NewValue)) -> Future<NewValue, E>
```

This method generates a new future with the same error type as the first, but with a new value type. So, assuming we have this first method: `getPhoneNumberInt() -> Future<Int, NSError>`, we can easily map it like so:

```Swift
func getPhoneNumberString() -> Future<String, NSError> {
  return getPhoneNumberInt().mapValue { "\($0)" }
}
```

##### Map Error

Sometimes we want to pass along a value as-is, but want a more domain-specific error. For example, you might have an error that is specific to your network layer, and you want to keep that layer well encapsulated. For this, we have:

```Swift
@discardableResult func mapError<NewError: Error>(_ mapBlock:@escaping (E) -> (NewError)) -> Future<T, NewError>
```

So, if we have a method like `getTweetfacePostFromNetwork(id: String) -> Future<TweetfacePost, NetworkError>`, we can do a simple mapping to a new error type as we see fit:

```Swift
func getTweetfacePost(id: String) -> Future<TweetfacePost, TweetfaceError> {
  return getTweetfacePostFromNetwork(id: id).mapError { (networkError) -> TweetfaceError in
    switch networkError {
    case .userError:
      return TweetfaceError.badID
    case .serverError:
      return TweetfaceError.serverError
    }
  }
}
```

or use the convenience `mapToNSError() -> Future<T, NSError>` which employs `mapError(_:)` as well as Foundation's toll-free bridging of `Error` to `NSError`:

```Swift
func getTweetfacePost(id: String) -> Future<TweetfacePost, NSError> {
  return getTweetfacePostFromNetwork(id: id).mapToNSError()
}
```

##### Flatmap

If you don't want to be bothered with doing the error-mapping yourself, *__or__* you want a failable mapping, *__or__* you want to map and have detailed information about whether it was the original error or the mapping that failed, then `flatMap(_:)` is for you!

```Swift
@discardableResult func flatMap<Q>(_ mapBlock:@escaping (T) -> (Q?)) -> Future<Q, MapError<T,E,Q>>
```

There are a lot of scenarios where the success case of your first future may not correspond to a success case on the mapped future, and that's where `flatMap(_:)` comes in. It allows the success case of the first future to potentially trigger a failure on the second, if the result of the passed-in block returns nil. 

Now, you can already do this with `mapResult(_:)` and it would look something like this:

```Swift
let getTheNumber: Future<Int, IntError> = getInteger()
let writeItDown = getTheNumber.mapResult { (result) -> Result<String, StringError>
  switch result {
  case .success(let intValue):
    if intValue < 5 {
      return .success("\(intValue)")
    }
    else {
      return .failure(StringError.couldntMapInt)
    }
  case .failure(let error):
    return .failure(StringError.couldntGetInt)
  }
}
```

However, this forces you to choose one error type or another, and forces you to generate an error case in your new error type that correspons to a bad mapping (seen above as `.couldntMapInt`). With flapMap, though, it's as simple as:

```Swift
let getTheNumber: Future<Int, IntError> = getInteger()
let writeItDown = getTheNumber.flatMap { (intValue) -> String?
  return (intValue < 5) ? "\(intValue)" : nil
}
```

What, you're surely asking now, is the error type of this new future? Good question, astute reader! The answer is that it's this handy little puppy:

##### MapError<T, E, Q>

MappError represents both possible failure states of a flat-map (which can be called on a Future *__or__* a Result). As you can see here, MapError has one case for a failure on the first future, and one other case for a failed mapping.

```Swift
enum MapError<SourceType, SourceError, TargetType>: Error {
    case originalError(SourceError)
    case mappingError(SourceType)
}
```

As a result, you can get all the data about a failure you need from one unified error, and it's auto-generated so that you don't have to roll one yourself. I know, I know. You're welcome. The associated value of the `.mappingError` case will be the value that was passed into the block which resulted in `nil`. And will give you a helpful debug description like: 

> "Could not map value: (6) to output type: String."

#### Chaining

Quite often as developers, we're presented with multiple, related bits of asynchronous work that need to be grouped together and/or connected to one another. Concurrency gives you handful of tools for dealing with these as well.

##### Then

```Swift
@discardableResult func then<NewValue, NewError: Error>(_ mapBlock:@escaping (T)->(Future<NewValue, NewError>)) -> Future<NewValue, NewError>
```

Sometimes, you have bits of asynchronous work that have to happen serially, since the result of one may be needed before another can start. The `then(_:)` method allows you to do this fairly painlessly. Let's say you have to methods, one to get a phone number, `func getPhoneNumber() -> Future<Int, NSError>`, and one to call that phone number, `func call(phoneNumber: Int) -> Future<PhoneCall, PhoneError>`. You obviously can't call the latter until you have the result of the former. The best way to handle this is with the `then(_:)` method:

```Swift
let makePhoneCall = getPhoneNumber().then { (number) -> Future<PhoneCall, PhoneError>
  return call(phoneNumber: number)
}

// Or, with the beautiful interchangeability of blocks and functions in Swift, you could write it like so:

let makePhoneCall = getPhoneNumber().then(call(phoneNumber:))
```

##### Zip

Perhaps you need various bits of work to complete but they don't have to happen serially. You just need them all to be done before you can continue. Then `zip(_:)` is the tool for you! 

```Swift
static func zip(_ futures: [Future<T, E>]) -> Future<[T], E>
```

Zip takes in an array of futures of type `<T, E>` and returns a single future with type `<[T], E>`. This future will resolve if/when *all* of the futures in the array have succeeded, or will be rejected if any one of them fails.

For example, let's say you wanted to fetch several phone numbers, but you need *all* of them before you can move on (a totally real-world example, _amirite?_). So, you have several methods that return `Future<Int, NumberError>`, and you want to perform an action once they all come back. You can do this:

```Swift
let phoneNumberFutures: [Future<Int, NumberError>] = [getMomsNumber(), getDadsNumber(), getWackyPhoneNumber()]
let getPhoneNumbers = Future.zip(phoneNumberFutures)
// getPhoneNumbers will be of type Future<[Int], NumberError>
getPhoneNumbers.then { (phoneNumbers) in
  commenceZanyParentTrap(with: phoneNumbers)
}
```
_Voila!_

##### First Finished

On the other hand, you might have a bunch of similar tasks in process and just need the data from whichever one finishes first. There's *~~an app~~* a method for that!

```Swift
static func firstFinished(from futures: [Future]) -> Future
```

Whichever future (if any) succeeds first will trigger the success of the joined future, and if none of them succeed, the last one to fail will trigger the error state, and pass through its error.

#### One last thing...

Well, two last things. Before I go, I just wanted to point out these two convenience methods on Future. They are

```Swift
static func preResolved(value: T) -> Future<T, E>
```
and

```Swift
static func preRejected(error: E) -> Future<T, E>
```

These simply generated futures that are already complete on creation. There are two primary uses for these methods:

1) Testing. This collapses several lines of setup in a test down to one.
2) In a method which returns a future, if arguments passed in (or some other aspect of state) are insufficient to do the asynchronous work, then this gives you an option to immediately reject the future, and to do so without adding any needless asynchrony into the app.

# Conclusion

And that's about it! I hope you find all of this useful, or at least informative.

I'm always tweaking code, finding optimizations, and thinking about new features. Feel free to reach out] with questions, suggestions, or (if you're super awesome) *pull requests* of your own!

All files are tested. Feel free to check out the tests [here](https://github.com/jakehawken/Concurrency/tree/master/ConcurrencyTests).

And of course, keep your eye out for version updates!

## Installation

Concurrency is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```Ruby
pod "Concurrency"
```

## Author

Jake Hawken, www.github.com/jakehawken

## License

Concurrency is available under the MIT license. See the LICENSE file for more info.
