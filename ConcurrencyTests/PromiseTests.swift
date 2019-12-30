@testable import Concurrency
import Nimble
import Quick

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
class PromiseTests: QuickSpec {
  // swiftlint:disable:next function_body_length
  override func spec() {

    var subject: Promise<Int, NSError>!
    let noBuenoError = NSError(domain: "No bueno", code: 666, userInfo: nil)

    describe("Promise") {

        beforeEach {
            subject = Promise<Int, NSError>()
        }
        
        it("should contain an unresolved future") {
            expect(subject.future.isComplete).to(beFalse())
            expect(subject.future.succeeded).to(beFalse())
            expect(subject.future.failed).to(beFalse())
        }
        
        describe("completing the promise") {
            context("when resolving the promise") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the internal promise") {
                    expect(subject.future.isComplete).to(beTrue())
                    expect(subject.future.succeeded).to(beTrue())
                    expect(subject.future.failed).to(beFalse())
                }
            }
            
            context("when rejecting the promise") {
                beforeEach {
                    subject.reject(noBuenoError)
                }
                
                it("should reject the internal promise") {
                    expect(subject.future.isComplete).to(beTrue())
                    expect(subject.future.succeeded).to(beFalse())
                    expect(subject.future.failed).to(beTrue())
                }
            }
        }
        
        describe("using onSuccess, onFailure, and finally blocks") {
            var successValue: Int?
            var errorValue: NSError?
            var primaryTimestamp: Date?
            var finallyHappened: Bool = false
            
            beforeEach {
                successValue = nil
                errorValue = nil
                finallyHappened = false
                
                subject = Promise<Int, NSError>()
                
                subject.future.onSuccess { (value) in
                    primaryTimestamp = Date()
                    successValue = value
                }.onFailure { (error) in
                  errorValue = error as NSError
                }.finally { (_) in
                    finallyHappened = true
                }
            }
            
            context("when the promise is rejected") {
                beforeEach {
                    subject.reject(noBuenoError)
                }
                
                it("should hit the error block, and not the success block") {
                    expect(errorValue).toNotEventually(beNil())
                    expect(errorValue).to(equal(noBuenoError))
                    expect(successValue).to(beNil())
                }
                
                it("should call the finally block no matter what") {
                    expect(finallyHappened).to(beTrue())
                }
            }
            
            context("when the promise is resolved") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should hit the error block, and not the success block") {
                    expect(errorValue).to(beNil())
                    expect(successValue).toNotEventually(beNil())
                    expect(successValue).to(equal(3))
                }
                
                it("should call the finally block no matter what") {
                    expect(finallyHappened).to(beTrue())
                }
            }
            
            context("when there are multiple then blocks") {
                var secondarySuccessValue: String?
                var secondaryTimeStamp: Date?
                var tertiarySuccessValue: Float?
                var tertiaryTimeStamp: Date?
                
                beforeEach {
                    subject.future.onSuccess { (value) in
                        secondaryTimeStamp = Date()
                        secondarySuccessValue = "\(value)"
                    }
                    
                    subject.future.onSuccess { (value) in
                        tertiaryTimeStamp = Date()
                        tertiarySuccessValue = Float(value)
                    }
                    
                    subject.resolve(5)
                }
                
                it("should execute the then blocks in order") {
                    expect(successValue).to(equal(5))
                    expect(secondarySuccessValue).to(equal("5"))
                    expect(secondaryTimeStamp?.isAfter(primaryTimestamp!)).to(beTrue())
                    expect(tertiarySuccessValue).to(equal(5))
                    expect(tertiaryTimeStamp?.isAfter(secondaryTimeStamp)).to(beTrue())
                }
                
            }

        }
        
        describe("using preResolved(_) and preRejected(_)") {
            var future: Future<Int, NSError>?

            context("when using preResolved") {
                beforeEach {
                    future = Future.preResolved(value: 7)
                }

                it("should return a synchronously rejected future") {
                    expect(future?.isComplete).to(beTrue())
                    expect(future?.failed).to(beFalse())
                    expect(future?.succeeded).to(beTrue())
                    expect(future?.value).to(equal(7))
                    expect(future?.error).to(beNil())
                }
            }

            context("when using preRejected") {
                beforeEach {
                    future = Future.preRejected(error: noBuenoError)
                }

                it("should return a synchronously rejected future") {
                    expect(future?.isComplete).to(beTrue())
                    expect(future?.failed).to(beTrue())
                    expect(future?.succeeded).to(beFalse())
                    expect(future?.value).to(beNil())
                    expect(future?.error).toNot(beNil())
                }
            }
        }
        
        describe("mapping result") {
            var returnedFuture: Future<String, NSError>!
            
            beforeEach {
                returnedFuture = subject.future.mapResult { (result) -> (Result<String, NSError>) in
                    switch result {
                    case .success(let intVal):
                        return .success("\(intVal)")
                    case .failure(let nsError):
                        return .failure(nsError)
                    }
                }
            }
            
            context("when the first future fails") {
                var couldntGetIntError: NSError!
                
                beforeEach {
                    couldntGetIntError = NSError(domain: "No int.", code: 0, userInfo: nil)
                    subject.reject(couldntGetIntError)
                }
                
                it("should reject the second future") {
                    expect(returnedFuture.failed).to(beTrue())
                    expect(returnedFuture.error?.equals(couldntGetIntError)).to(beTrue())
                }
            }
            
            context("when the first future succeeds") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the returned future") {
                    expect(returnedFuture.succeeded).to(beTrue())
                    expect(returnedFuture.error).to(beNil())
                    expect(returnedFuture.value).to(equal("3"))
                }
            }
        }
        
        describe("mapping value") {
            var returnedFuture: Future<String, NSError>!
            
            beforeEach {
                returnedFuture = subject.future.mapValue { "\($0)" }
            }
            
            context("when the first future fails") {
                var couldntGetIntError: NSError!
                
                beforeEach {
                    couldntGetIntError = NSError(domain: "No int.", code: 0, userInfo: nil)
                    subject.reject(couldntGetIntError)
                }
                
                it("should reject the second future") {
                    expect(returnedFuture.failed).to(beTrue())
                    expect(returnedFuture.error?.equals(couldntGetIntError)).to(beTrue())
                }
            }
            
            context("when the first future succeeds") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the returned future with the mapped success") {
                    expect(returnedFuture.succeeded).to(beTrue())
                    expect(returnedFuture.error).to(beNil())
                    expect(returnedFuture.value).to(equal("3"))
                }
            }
        }
        
        describe("mapping error") {
            var returnedFuture: Future<Int, BasicTestingError>!
            
            beforeEach {
                returnedFuture = subject.future.mapError { (_) -> BasicTestingError in
                    return BasicTestingError(message: "Yuh-oh!")
                }
            }
            
            context("when the first future fails") {
                var couldntGetIntError: NSError!
                
                beforeEach {
                    couldntGetIntError = NSError(domain: "No int.", code: 0, userInfo: nil)
                    subject.reject(couldntGetIntError)
                }
                
                it("should reject the second future with the mapped error") {
                    expect(returnedFuture.failed).to(beTrue())
                    expect(returnedFuture.error?.equals(couldntGetIntError)).toNot(beTrue())
                    expect(returnedFuture.error?.message).to(equal("Yuh-oh!"))
                }
            }
            
            context("when the first future succeeds") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the returned future") {
                    expect(returnedFuture.succeeded).to(beTrue())
                    expect(returnedFuture.error).to(beNil())
                    expect(returnedFuture.value).to(equal(3))
                }
            }
        }
        
        describe("flat-mapping") {
            var future: Future<Int, NSError>!
            var mappedFuture: Future<String, MapError<Int, NSError, String>>!
            
            beforeEach {
                subject = Promise<Int, NSError>()
                future = subject.future
            }
            
            context("when the map block results in nil") {
                beforeEach {
                    subject.resolve(3)
                    mappedFuture = future.flatMap { (_) -> (String?) in
                        return nil
                    }
                }
                
                it("should return a promise that gets rejected") {
                    expect(mappedFuture.isComplete).to(beTrue())
                    expect(mappedFuture.succeeded).to(beFalse())
                    expect(mappedFuture.failed).to(beTrue())
                    expect(mappedFuture.error?.description).to(equal("Could not map value: (3) to output type: String."))
                    expect(mappedFuture.value).to(beNil())
                }
            }
            
            context("when the map block results in non-nil") {
                beforeEach {
                    mappedFuture = future.flatMap { (intValue) -> (String?) in
                        return "\(intValue)"
                    }
                }
                
                context("if the initial future was a success") {
                    beforeEach {
                        subject.resolve(3)
                    }
                    
                    it("should return a promise that gets rejected") {
                        expect(mappedFuture.isComplete).to(beTrue())
                        expect(mappedFuture.succeeded).to(beTrue())
                        expect(mappedFuture.failed).to(beFalse())
                        expect(mappedFuture.value).to(equal("3"))
                        expect(mappedFuture.error).to(beNil())
                    }
                }
                
                context("if the initial future was a failure") {
                    beforeEach {
                        subject.reject(noBuenoError)
                    }
                    
                    it("should propagate the original error through") {
                        expect(mappedFuture.isComplete).to(beTrue())
                        expect(mappedFuture.succeeded).to(beFalse())
                        expect(mappedFuture.failed).to(beTrue())
                        expect(mappedFuture.error).to(equal(.originalError(noBuenoError)))
                        expect(mappedFuture.value).to(beNil())
                    }
                }
            }
        }
        
        describe("zipping") {
            var future: Future<[Int], NSError>!
            let genericError = NSError(domain: "Oops!", code: 0, userInfo: nil)
            let otherError = NSError(domain: "Uh-oh!", code: 1, userInfo: nil)
            var successValues: [Int]?
            var errorFromFuture: Error?
            
            beforeEach {
                successValues = nil
                errorFromFuture = nil
            }
            
            context("when all of the values succeed") {
                beforeEach {
                    let intFutures: [Future<Int, NSError>] = [Future.preResolved(value: 5),
                                                              Future.preResolved(value: 3),
                                                              Future.preResolved(value: 7)]
                    future = Future.zip(intFutures).onSuccess { (values) in
                        successValues = values
                    }.onFailure { (error) in
                        errorFromFuture = error
                    }
                }
                
                it("should resolve the future with an array of the success values") {
                    expect(successValues).to(contain([5, 3, 7]))
                    expect(future.succeeded).to(beTrue())
                }
            }
            
            context("when all of the values fail") {
                beforeEach {
                    let intFutures: [Future<Int, NSError>] = [Future.preRejected(error: otherError),
                                                     Future.preRejected(error: genericError),
                                                     Future.preRejected(error: genericError)]
                    future = Future.zip(intFutures).onSuccess { (values) in
                        successValues = values
                    }.onFailure { (error) in
                        errorFromFuture = error
                    }
                }
                
                it("should reject the future with the first error encountered") {
                    expect(successValues).to(beNil())
                    expect(errorFromFuture?.equals(otherError)).to(beTrue())
                    expect(future.failed).to(beTrue())
                }
            }
            
            context("when one or more of the values fail") {
                beforeEach {
                    let intFutures: [Future<Int, NSError>] = [Future.preResolved(value: 5),
                                                     Future.preRejected(error: genericError),
                                                     Future.preResolved(value: 7)]
                    future = Future.zip(intFutures).onSuccess { (values) in
                        successValues = values
                    }.onFailure { (error) in
                        errorFromFuture = error
                    }
                }
                
                it("should resolve the future with an array of the success values") {
                    expect(successValues).to(beNil())
                    expect(errorFromFuture?.equals(genericError)).to(beTrue())
                    expect(future.failed).to(beTrue())
                }
            }
        }
        
        describe("firstFinished(from:)") {
            var promise1: Promise<Int, NSError>!
            var promise2: Promise<Int, NSError>!
            var promise3: Promise<Int, NSError>!
            var futures: [Future<Int, NSError>]!
            var joinedFuture: Future<Int, NSError>!
            
            beforeEach {
                promise1 = Promise<Int, NSError>()
                promise2 = Promise<Int, NSError>()
                promise3 = Promise<Int, NSError>()
                futures = [promise1.future, promise2.future, promise3.future]
                joinedFuture = Future.firstFinished(from: futures)
            }
            
            context("when the first finishes first") {
                beforeEach {
                    promise1.resolve(1)
                    promise2.resolve(2)
                    promise3.resolve(3)
                }
                
                it("should resolve the joined future with the first value") {
                    expect(joinedFuture.isComplete).to(beTrue())
                    expect(joinedFuture.succeeded).to(beTrue())
                    expect(joinedFuture.value).to(equal(1))
                }
            }
            
            context("when the second finishes first") {
                beforeEach {
                    promise2.resolve(2)
                    promise1.resolve(1)
                    promise3.resolve(3)
                }
                
                it("should resolve the joined future with the second value") {
                    expect(joinedFuture.isComplete).to(beTrue())
                    expect(joinedFuture.succeeded).to(beTrue())
                    expect(joinedFuture.value).to(equal(2))
                }
            }
            
            context("when the third finishes first") {
                beforeEach {
                    promise3.resolve(3)
                    promise1.resolve(1)
                    promise2.resolve(2)
                }
                
                it("should resolve the joined future with the third value") {
                    expect(joinedFuture.isComplete).to(beTrue())
                    expect(joinedFuture.succeeded).to(beTrue())
                    expect(joinedFuture.value).to(equal(3))
                }
            }
        }

    }

  }

}

extension Date {
    func isAfter(_ otherDate: Date) -> Bool {
        return timeIntervalSince(otherDate) > 0
    }
}

struct BasicTestingError: Error {
    let message: String
}
