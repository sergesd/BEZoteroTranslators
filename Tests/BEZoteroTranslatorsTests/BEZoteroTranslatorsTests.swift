import XCTest
import WebKit
@testable import BEZoteroTranslators

final class BEZoteroTranslatorsTests: XCTestCase {
    func testZoteroWebViewInitialization() {
        let webView = ZoteroWebView(frame: .zero, configuration: WKWebViewConfiguration())
        XCTAssertNotNil(webView)
    }
    
    func testZoteroWebViewDelegate() {
        let webView = ZoteroWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let delegate = MockZoteroWebViewDelegate()
        webView.zoteroDelegate = delegate
        
        XCTAssertNotNil(webView.zoteroDelegate)
    }
    
    func testWashingtonPostArticle() {
        let webView = ZoteroWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let delegate = MockZoteroWebViewDelegate()
        webView.zoteroDelegate = delegate
        
        // Load the test article
        guard let testArticleURL = Bundle.module.url(forResource: "washington_post_test", withExtension: "html", subdirectory: "TestArticles") else {
            XCTFail("Could not find test article HTML file")
            return
        }
        let request = URLRequest(url: testArticleURL)
        
        let expectation = XCTestExpectation(description: "Article scraping completed")
        
        // Load the Washington Post translator by name
        webView.loadTranslatorByName("Washington Post")
        
        // Load the test article
        webView.load(request)
        
        // Wait for the page to load and scraping to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            webView.scrapePage()
        }
        
        // Wait for the delegate to receive the scraped items
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            XCTAssertNotNil(delegate.scrapedItems)
            if let items = delegate.scrapedItems {
                XCTAssertEqual(items.count, 1)
                
                // Load expected results
                guard let expectedResultsPath = Bundle.module.path(forResource: "washington_post_test", ofType: "json", inDirectory: "TestArticles"),
                      let expectedResultsData = try? Data(contentsOf: URL(fileURLWithPath: expectedResultsPath)),
                      let expectedResults = try? JSONSerialization.jsonObject(with: expectedResultsData) as? [String: Any],
                      let expectedItems = expectedResults["items"] as? [[String: Any]],
                      let expectedItem = expectedItems.first else {
                    XCTFail("Could not load expected results")
                    return
                }
                
                // Compare scraped item with expected item
                let scrapedItem = items[0]
                XCTAssertEqual(scrapedItem["title"] as? String, expectedItem["title"] as? String)
                XCTAssertEqual(scrapedItem["date"] as? String, expectedItem["date"] as? String)
                XCTAssertEqual(scrapedItem["ISSN"] as? String, expectedItem["ISSN"] as? String)
                
                // Compare creators
                if let scrapedCreators = scrapedItem["creators"] as? [[String: Any]],
                   let expectedCreators = expectedItem["creators"] as? [[String: Any]] {
                    XCTAssertEqual(scrapedCreators.count, expectedCreators.count)
                    XCTAssertEqual(scrapedCreators[0]["firstName"] as? String, expectedCreators[0]["firstName"] as? String)
                    XCTAssertEqual(scrapedCreators[0]["lastName"] as? String, expectedCreators[0]["lastName"] as? String)
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Mock Delegate
class MockZoteroWebViewDelegate: NSObject, ZoteroWebViewDelegate {
    var detectedType: String?
    var scrapedItems: [[String: Any]]?
    var error: Error?
    
    func zoteroWebView(_ webView: ZoteroWebView, didDetectType type: String) {
        detectedType = type
    }
    
    func zoteroWebView(_ webView: ZoteroWebView, didScrapeItems items: [[String: Any]]) {
        scrapedItems = items
    }
    
    func zoteroWebView(_ webView: ZoteroWebView, didFailWithError error: Error) {
        self.error = error
    }
} 
