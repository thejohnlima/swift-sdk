//
//  Copyright © 2018 Iterable. All rights reserved.
//

import OHHTTPStubs
import XCTest

@testable import IterableSDK

class DeepLinkTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    private let iterableRewriteURL = "http://links.iterable.com/a/60402396fbd5433eb35397b47ab2fb83?_e=joneng%40iterable.com&_m=93125f33ba814b13a882358f8e0852e0"
    private let iterableNoRewriteURL = "http://links.iterable.com/u/60402396fbd5433eb35397b47ab2fb83?_e=joneng%40iterable.com&_m=93125f33ba814b13a882358f8e0852e0"
    
    private let redirectRequest = "https://httpbin.org/redirect-to?url=http://example.com"
    private let exampleUrl = "http://example.com"
    
    func testTrackUniversalDeepLinkRewrite() {
        let expectation1 = expectation(description: "testUniversalDeepLinkRewrite")
        
        let redirectLocation = "https://links.iterable.com/api/docs#!/email"
        let campaignId = 83306
        let templateId = 124_348
        let messageId = "93125f33ba814b13a882358f8e0852e0"
        
        setupRedirectStubResponse(location: redirectLocation, campaignId: campaignId, templateId: templateId, messageId: messageId)
        
        let mockUrlDelegate = MockUrlDelegate(returnValue: true)
        mockUrlDelegate.callback = { url, context in
            XCTAssertEqual(url.absoluteString, redirectLocation)
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(context.action.type, IterableAction.actionTypeOpenUrl)
            expectation1.fulfill()
        }
        
        let deepLinkManager = IterableDeepLinkManager()
        
        _ = deepLinkManager.handleUniversalLink(URL(string: iterableRewriteURL)!,
                                                urlDelegate: mockUrlDelegate,
                                                urlOpener: MockUrlOpener())
        
        wait(for: [expectation1], timeout: testExpectationTimeout)
    }
    
    func testTrackUniversalDeepLinkNoRewrite() {
        let expectation1 = expectation(description: "testUniversalDeepLinkNoRewrite")
        
        setupStubResponse()

        let mockUrlDelegate = MockUrlDelegate(returnValue: true)
        mockUrlDelegate.callback = { url, context in
            XCTAssertEqual(url.absoluteString, self.iterableNoRewriteURL)
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(context.action.type, IterableAction.actionTypeOpenUrl)
            expectation1.fulfill()
        }
        
        let deepLinkManager = IterableDeepLinkManager()
        
        _ = deepLinkManager.handleUniversalLink(URL(string: iterableNoRewriteURL)!,
                                                urlDelegate: mockUrlDelegate,
                                                urlOpener: MockUrlOpener())

        wait(for: [expectation1], timeout: testExpectationTimeout)
    }
    
    func testHandleUniversalLinkRewrite() {
        let expectation1 = expectation(description: "urlDelegate is called")
        
        let redirectLocation = "https://links.iterable.com/api/docs#!/email"
        let campaignId = 83306
        let templateId = 124_348
        let messageId = "93125f33ba814b13a882358f8e0852e0"
        
        setupRedirectStubResponse(location: redirectLocation, campaignId: campaignId, templateId: templateId, messageId: messageId)
        
        let mockUrlDelegate = MockUrlDelegate(returnValue: false)
        mockUrlDelegate.callback = { url, context in
            XCTAssertEqual(url.absoluteString, redirectLocation)
            XCTAssertEqual(context.action.type, IterableAction.actionTypeOpenUrl)
            expectation1.fulfill()
        }
        
        let config = IterableConfig()
        config.urlDelegate = mockUrlDelegate
        let internalAPI = InternalIterableAPI.initializeForTesting(config: config)
        
        internalAPI.handleUniversalLink(URL(string: iterableRewriteURL)!)
        
        wait(for: [expectation1], timeout: testExpectationTimeout)
    }
    
    func testHandleUniversalLinkAttributionInfo() {
        let expectation1 = expectation(description: "testHandleUniversalLinkAttributionInfo")
        
        let redirectLocation = "https://links.iterable.com/api/docs#!/email"
        let campaignId = 83306
        let templateId = 124_348
        let messageId = "93125f33ba814b13a882358f8e0852e0"
        
        setupRedirectStubResponse(location: redirectLocation, campaignId: campaignId, templateId: templateId, messageId: messageId)
        
        let internalAPI = InternalIterableAPI.initializeForTesting()
        internalAPI.handleUniversalLink(URL(string: iterableRewriteURL)!)
        internalAPI.attributionInfo = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(internalAPI.attributionInfo?.campaignId, NSNumber(value: campaignId))
            XCTAssertEqual(internalAPI.attributionInfo?.templateId, NSNumber(value: templateId))
            XCTAssertEqual(internalAPI.attributionInfo?.messageId, messageId)
            expectation1.fulfill()
        }
        
        wait(for: [expectation1], timeout: testExpectationTimeout)
    }
    
    /// this is a service that automatically redirects if that url is hit, make sure we are not actually hitting the url but our servers
    func testNoURLRedirect() {
        let expectation1 = expectation(description: "testNoURLRedirect")
        
        setupStubResponse()
        
        let mockUrlDelegate = MockUrlDelegate(returnValue: false)
        mockUrlDelegate.callback = { redirectUrl, context in
            XCTAssertNotEqual(redirectUrl.absoluteString, self.exampleUrl)
            XCTAssertEqual(redirectUrl.absoluteString, self.redirectRequest)
            
            expectation1.fulfill()
        }
        
        let deepLinkManager = IterableDeepLinkManager()
        
        _ = deepLinkManager.handleUniversalLink(URL(string: redirectRequest)!,
                                                urlDelegate: mockUrlDelegate,
                                                urlOpener: MockUrlOpener())
        
        wait(for: [expectation1], timeout: testExpectationTimeout)
    }
    
    private func setupRedirectStubResponse(location: String, campaignId: Int, templateId: Int, messageId: String) {
        HTTPStubs.stubRequests(passingTest: { (_) -> Bool in
            true
        }) { (_) -> HTTPStubsResponse in
            HTTPStubsResponse(data: try! JSONSerialization.data(withJSONObject: [:], options: []), statusCode: 301, headers: [
                "Location": location,
                "Set-Cookie": self.createCookieValue(nameValuePairs: "iterableEmailCampaignId", campaignId, "iterableTemplateId", templateId, "iterableMessageId", messageId),
            ])
        }
    }
    
    private func setupStubResponse() {
        HTTPStubs.stubRequests(passingTest: { (_) -> Bool in
            true
        }) { (_) -> HTTPStubsResponse in
            HTTPStubsResponse(data: try! JSONSerialization.data(withJSONObject: [:], options: []), statusCode: 200, headers: nil)
        }
    }
    
    private func createCookieValue(nameValuePairs values: Any...) -> String {
        values.take(2).map { "\($0[0])=\($0[1])" }.joined(separator: ";,")
    }
}
