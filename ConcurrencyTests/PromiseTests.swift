@testable import Concurrency
import Nimble
import Quick

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
                    expect(subject.future.isComplete).toEventually(beTrue())
                    expect(subject.future.succeeded).toEventually(beTrue())
                    expect(subject.future.failed).toEventually(beFalse())
                }
            }
            
            context("when rejecting the promise") {
                beforeEach {
                    subject.reject(noBuenoError)
                }
                
                it("should reject the internal promise") {
                    expect(subject.future.isComplete).toEventually(beTrue())
                    expect(subject.future.succeeded).toEventually(beFalse())
                    expect(subject.future.failed).toEventually(beTrue())
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
                    expect(errorValue).toEventually(equal(noBuenoError))
                    expect(successValue).toEventually(beNil())
                }
                
                it("should call the finally block no matter what") {
                    expect(finallyHappened).toEventually(beTrue())
                }
            }
            
            context("when the promise is resolved") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should hit the error block, and not the success block") {
                    expect(errorValue).toEventually(beNil())
                    expect(successValue).toNotEventually(beNil())
                    expect(successValue).toEventually(equal(3))
                }
                
                it("should call the finally block no matter what") {
                    expect(finallyHappened).toEventually(beTrue())
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
                    expect(successValue).toEventually(equal(5))
                    expect(secondarySuccessValue).toEventually(equal("5"))
                    expect(secondaryTimeStamp?.isAfter(primaryTimestamp!)).toEventually(beTrue())
                    expect(tertiarySuccessValue).toEventually(equal(5))
                    expect(tertiaryTimeStamp?.isAfter(secondaryTimeStamp)).toEventually(beTrue())
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
        
        describe("mapping") {
            var returnedFuture: Future<String, NSError>!
            
            beforeEach {
                returnedFuture = subject.future.map { (result) -> (Result<String, NSError>) in
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
                    expect(returnedFuture.error?.equals(couldntGetIntError)).toEventually(beTrue())
                }
            }
            
            context("when the first future succeeds") {
                beforeEach {
                    subject.resolve(3)
                }
                
                it("should resolve the returned future") {
                    expect(returnedFuture.succeeded).toEventually(beTrue())
                    expect(returnedFuture.error).to(beNil())
                    expect(returnedFuture.value).to(equal("3"))
                }
            }
        }
        
        describe("auto-mapping") {
            var future: Future<Int, NSError>!
            var mappedFuture: Future<String, Result<Int, NSError>.MapError<String>>!
            
            beforeEach {
                subject = Promise<Int, NSError>()
                future = subject.future
            }
            
            context("when the map block results in nil") {
                beforeEach {
                    subject.resolve(3)
                    mappedFuture = future.autoMap { (_) -> (String?) in
                        return nil
                    }
                }
                
                it("should return a promise that gets rejected") {
                    expect(mappedFuture.isComplete).toEventually(beTrue())
                    expect(mappedFuture.succeeded).toEventually(beFalse())
                    expect(mappedFuture.failed).toEventually(beTrue())
                    expect(mappedFuture.error?.description).toEventually(equal("Could not map value: (3) to output type: String."))
                    expect(mappedFuture.value).toEventually(beNil())
                }
            }
            
            context("when the map block results in non-nil") {
                beforeEach {
                    mappedFuture = future.autoMap { (intValue) -> (String?) in
                        return "\(intValue)"
                    }
                }
                
                context("if the initial future was a success") {
                    beforeEach {
                        subject.resolve(3)
                    }
                    
                    it("should return a promise that gets rejected") {
                        expect(mappedFuture.isComplete).toEventually(beTrue())
                        expect(mappedFuture.succeeded).toEventually(beTrue())
                        expect(mappedFuture.failed).toEventually(beFalse())
                        expect(mappedFuture.value).toEventually(equal("3"))
                        expect(mappedFuture.error).toEventually(beNil())
                    }
                }
                
                context("if the initial future was a failure") {
                    beforeEach {
                        subject.reject(noBuenoError)
                    }
                    
                    it("should propagate the original error through") {
                        expect(mappedFuture.isComplete).toEventually(beTrue())
                        expect(mappedFuture.succeeded).toEventually(beFalse())
                        expect(mappedFuture.failed).toEventually(beTrue())
                        expect(mappedFuture.error).toEventually(equal(.originalError(noBuenoError)))
                        expect(mappedFuture.value).toEventually(beNil())
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
                    expect(successValues).toEventually(contain([5, 3, 7]))
                    expect(future.succeeded).toEventually(beTrue())
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
                    expect(successValues).toEventually(beNil())
                    expect(errorFromFuture?.equals(otherError)).toEventually(beTrue())
                    expect(future.failed).toEventually(beTrue())
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
                    expect(successValues).toEventually(beNil())
                    expect(errorFromFuture?.equals(genericError)).toEventually(beTrue())
                    expect(future.failed).toEventually(beTrue())
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
