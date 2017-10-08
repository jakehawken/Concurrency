import Nimble
import Quick
import RxSwift
@testable import Concurrency


class PeriodicFetcherTests: QuickSpec {
    override func spec() {
        
        var subject: PeriodicFetcher<Int>!
        var futureGenerator: PeriodicFetcher<Int>.FutureGenerator!
        let timeInterval: Double = 500
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
            
        }
        
    }
}
