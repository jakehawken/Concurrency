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
        
        var valuesAndTimes = [(value: Int, time: Date)]()
        let alternateSucceedAndFailGenerator: PeriodicFetcher<Int>.FutureGenerator = {
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
                valuesAndTimes.removeAll()
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
                
                describe("when uninterupted") {
                    beforeEach {
                        futureIndex = 0
                        futureGenerator = alternateSucceedAndFailGenerator
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
                
                describe("when interrupted immediately") {
                    
                    beforeEach {
                        futureIndex = 0
                        futureGenerator = alternateSucceedAndFailGenerator
                        timeInterval = 0.1
                        
                        testStart = Date()
                        subject.startPeriodicFetch()
                        subject.stopPeriodicFetch()
                    }
                    
                    it("should stop emitting data after being told to stop fetching") {
                        expect(streamStates.count).toEventually(equal(1))
                        expect(streamStates.count).toNotEventually(equal(2))
                        expect(streamStates.last).to(equal(StreamState.noData))
                        expect(subject.isFetching).to(equal(false))
                    }
                }
                
                describe("when interrupted mid-stream") {
                    
                    beforeEach {
                        futureIndex = 0
                        futureGenerator = {
                            if futureIndex > 3 {
                                subject.stopPeriodicFetch()
                            }
                            let promise = Promise<Int>()
                            promise.resolve(futureIndex)
                            futureIndex += 1
                            return promise.future
                        }
                        timeInterval = 0.1
                        
                        testStart = Date()
                        subject.startPeriodicFetch()
                    }
                    
                    it("should stop emitting data after being told to stop fetching") {
                        expect(streamStates.count).toEventually(equal(3))
                        expect(streamStates.count).toNotEventually(equal(4))
                        expect(streamStates.last).toEventually(equal(StreamState.newData(2)))
                        expect(subject.isFetching).toEventually(equal(false))
                    }
                }
                
            }
            
        }
        
    }
}
