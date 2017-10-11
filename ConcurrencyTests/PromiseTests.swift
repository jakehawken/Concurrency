import Nimble
import Quick
@testable import Concurrency


class PromiseTests: QuickSpec {
  override func spec() {

    var subject: Promise<Int>!
    let noBuenoError = NSError(domain: "No bueno", code: 666, userInfo: nil)

    describe("Promise") {

        beforeEach {
            subject = Promise<Int>()
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
        
        describe("using then() add error() blocks") {
            var successValue: Int?
            var errorValue: NSError?
            var primaryTimestamp: Date?
            
            beforeEach {
                successValue = nil
                errorValue = nil
                
                subject.future.then({ (value) in
                    primaryTimestamp = Date()
                    successValue = value
                }).error({ (error) in
                  errorValue = error as NSError
                })
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
            }
            
            context("when there are multiple then blocks") {
                var secondarySuccessValue: String?
                var secondaryTimeStamp: Date?
                var tertiarySuccessValue: Float?
                var tertiaryTimeStamp: Date?
                
                beforeEach {
                    subject.future.then({ (value) in
                        secondaryTimeStamp = Date()
                        secondarySuccessValue = "\(value)"
                    })
                    
                    subject.future.then({ (value) in
                        tertiaryTimeStamp = Date()
                        tertiarySuccessValue = Float(value)
                    })
                    
                    subject.resolve(5)
                }
                
                it("should execute the then blocks in order") {
                    expect(successValue).toEventually(equal(5))
                    expect(secondarySuccessValue).toEventually(equal("5"))
                    expect(secondaryTimeStamp?.isAfter(primaryTimestamp!)).toEventually(beTrue())
                    expect(tertiarySuccessValue).toEventually(equal(5))
                    expect(tertiaryTimeStamp?.isAfter(secondaryTimeStamp!)).toEventually(beTrue())
                }
                
            }

        }
        
        describe("using preResolved(_) and preRejected(_)") {
            var future: Future<Int>?

            context("when using preResolved") {
                beforeEach {
                    future = Future.preResolved(value:7)
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
                    future = Future.preRejected(error:noBuenoError)
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
        
        describe("flat-mapping") {
            var future: Future<Int>!
            var mappedFuture: Future<String>!
            
            beforeEach {
                subject = Promise<Int>()
                future = subject.future
            }
            
            context("when the map block results in nil") {
                beforeEach {
                    subject.resolve(3)
                    mappedFuture = future.flatMap({ (intValue) -> (String?) in
                        return nil
                    })
                }
                
                it("should return a promise that gets rejected") {
                    expect(mappedFuture.isComplete).toEventually(beTrue())
                    expect(mappedFuture.succeeded).toEventually(beFalse())
                    expect(mappedFuture.failed).toEventually(beTrue())
                    expect(item(mappedFuture.error, isA: NSError.self, and: {$0.domain == "Could not map value (3) to type String."})).toEventually(beTrue())
                    expect(mappedFuture.value).toEventually(beNil())
                }
            }
            
            context("when the map block results in non-nil") {
                beforeEach {
                    mappedFuture = future.flatMap({ (intValue) -> (String?) in
                        return "\(intValue)"
                    })
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
                        expect(item(mappedFuture.error, isA: NSError.self, and: {$0 == noBuenoError})).toEventually(beTrue())
                        expect(mappedFuture.value).toEventually(beNil())
                    }
                }
            }
        }

    }

  }

}
