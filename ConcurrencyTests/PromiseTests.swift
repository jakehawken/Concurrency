import Quick
import Nimble

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

    }

  }

}

extension Date {
    func isAfter(_ otherDate: Date) -> Bool {
        return timeIntervalSince(otherDate) > 0
    }
}
