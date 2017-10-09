import Nimble
import Quick
import RxSwift
@testable import Concurrency


class PeriodicFetcherTests: QuickSpec {
    override func spec() {
        
        var subject: PeriodicFetcher<Int>!
        var futureGenerator: PeriodicFetcher<Int>.FutureGenerator!
        var timeInterval: Double = 0.1
        var disposable: Disposable!
        var streamStates = [StreamState<Int>]()
        var showsIsFetching = false
        var futureIndex = 0
        let alwaysSucceedGenerator: PeriodicFetcher<Int>.FutureGenerator = {
            let promise = Promise<Int>()
            promise.resolve(futureIndex)
            futureIndex += 1
            return promise.future
        }
        
        describe("PeriodicFetcher") {
            
            beforeEach {
                futureIndex = 0
                futureGenerator = alwaysSucceedGenerator
                
                subject = PeriodicFetcher(futureGenerator: { () -> (Future<Int>) in
                    return futureGenerator()
                }, timeInterval: { () -> (Double) in
                    return timeInterval
                })
                
                disposable = subject.observable().subscribe(onNext: { (streamState) in
                    streamStates.append(streamState)
                    showsIsFetching = subject.isFetching
                }, onError: nil, onCompleted: nil, onDisposed: nil)
            }
            
            afterEach {
                subject.stopPeriodicFetch()
                streamStates.removeAll()
                futureGenerator = nil
                showsIsFetching = false
                disposable?.dispose()
                disposable = nil
            }
            
            it("should begin in the non-fetching state") {
                expect(subject.isFetching).to(equal(false))
                expect(streamStates.count).to(equal(1))
                expect(streamStates.first).to(equal(.noData))
            }
            
            describe("fetching once (without periodic fetching)") {
                
                beforeEach {
                    subject.fetchOnce()
                }
                
                it("should only fetch once (plus initial .noData)") {
                    expect(streamStates.count).toEventually(equal(2))
                    expect(streamStates.first).to(equal(StreamState.noData))
                    expect(streamStates.last).to(equal(StreamState.newData(0)))
                    expect(showsIsFetching).to(equal(false))
                }
            }
            
            describe("periodic fetching") {
                var testStart: Date!
                var valuesAndTimes = [(value: Int, time: Date)]()
                
                describe("when uninterupted") {
                    beforeEach {
                        futureIndex = 0
                        
                        futureGenerator = {
                            let date = Date()
                            let promise = Promise<Int>()
                            
                            if futureIndex == 0 || futureIndex % 2 == 0 {
                                promise.resolve(futureIndex)
                            }
                            else {
                                let error = NSError(domain: "Fail.", code: futureIndex, userInfo: nil)
                                promise.reject(error)
                            }
                            
                            valuesAndTimes.append((value: futureIndex, time: date))
                            futureIndex += 1
                            return promise.future
                        }
                        
                        timeInterval = 0.3
                        
                        testStart = Date()
                        subject.startPeriodicFetch()
                    }
                    
                    it("should execute all the calls at the expected interval") {
                        expect(streamStates.count).toEventually(equal(4))
                        let interval1 = Int(valuesAndTimes[0].time.timeIntervalSince(testStart) * 10)
                        let interval2 = Int(valuesAndTimes[1].time.timeIntervalSince(testStart) * 10)
                        let interval3 = Int(valuesAndTimes[2].time.timeIntervalSince(testStart) * 10)
                        expect(interval1).to(equal(0))
                        expect(interval2).to(equal(3))
                        expect(interval3).to(equal(6))
                        expect(showsIsFetching).to(equal(true))
                    }
                }
                
            }
            
        }
        
    }
}
