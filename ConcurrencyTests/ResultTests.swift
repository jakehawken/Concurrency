import Quick
import Nimble

@testable import Concurrency

class ResultTests: QuickSpec {
    override func spec() {
        
        var subject: Result<Int>!
        let noBuenoError = NSError(domain: "No bueno", code: 666, userInfo: nil)
        
        describe("Result") {
            
            describe("onSuccess and onError syntactic sugar") {
                
                context("when the case is success") {
                    var resultString = ""
                    
                    beforeEach {
                        subject = .success(3)
                        subject.onSuccess({ (value) in
                            resultString = "Success: \(value)"
                        })
                        subject.onError({ (_) in
                            resultString = "Oopsie!"
                        })
                    }
                    
                    it("should respond to the onSuccess block") {
                        expect(resultString).to(equal("Success: 3"))
                    }
                }
                
                context("when the case is error") {
                    var resultString = ""
                    
                    beforeEach {
                        subject = .error(noBuenoError)
                        subject.onSuccess({ (value) in
                            resultString = "Success: \(value)"
                        })
                        subject.onError({ (_) in
                            resultString = "Oopsie!"
                        })
                    }
                    
                    it("should respond to the onError block") {
                        expect(resultString).to(equal("Oopsie!"))
                    }
                }
                
            }
            
        }
        
    }
}

