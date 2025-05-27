import XCTest
import WebKit
@testable import BEZoteroTranslators

final class BEZoteroTranslatorsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Clear any previously registered translators
        TranslatorRegistry.shared.clearTranslators()
        
        // Register the Washington Post translator from the test target
        guard let translatorURL = Bundle.module.url(forResource: "Washington Post", withExtension: "js", subdirectory: "Translators") else {
            XCTFail("Could not find Washington Post translator in test bundle")
            return
        }
        
        do {
            try TranslatorRegistry.shared.registerTranslatorFromFile(name: "Washington Post", fileURL: translatorURL)
        } catch {
            XCTFail("Failed to register Washington Post translator: \(error)")
        }
    }
    
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
    
    func testWashingtonPostArticle() throws {
        // Get the translator from registry
        guard let translator = TranslatorRegistry.shared.getTranslator(name: "Washington Post") else {
            XCTFail("Washington Post translator not found")
            return
        }
        
        print("Got translator from registry")
        
        // Get test cases from the translator
        let testCases = try translator.extractTestCases()
        XCTAssertFalse(testCases.isEmpty, "No test cases found in translator")
        
        print("Found \(testCases.count) test cases")
        
        // Temporary flag to only run the first test case
        let runOnlyFirstTestCase = true
        
        // Run each test case
        for (index, testCase) in testCases.enumerated() {
            if runOnlyFirstTestCase && index > 0 {
                print("Skipping test case \(index + 1)")
                continue
            }
            
            print("Running test case \(index + 1) of \(testCases.count)")
            
            let webView = ZoteroWebView()
            let delegate = MockZoteroWebViewDelegate()
            webView.zoteroDelegate = delegate
            
            // Load the translator
            print("Loading translator...")
            webView.loadTranslator(translator.getCode())
            
            // Load the test article
            let expectation = XCTestExpectation(description: "Scrape article")
            delegate.onScrapeComplete = { items in
                print("Scrape complete callback received with \(items.count) items")
                XCTAssertEqual(items.count, testCase.items.count, "Test case \(index): Expected \(testCase.items.count) items, got \(items.count)")
                
                // Compare each item
                for (itemIndex, (scrapedItem, expectedItem)) in zip(items, testCase.items).enumerated() {
                    XCTAssertEqual(scrapedItem["itemType"] as? String, expectedItem.itemType, "Test case \(index), item \(itemIndex): Wrong item type")
                    XCTAssertEqual(scrapedItem["title"] as? String, expectedItem.title, "Test case \(index), item \(itemIndex): Wrong title")
                    
                    // Compare creators
                    if let scrapedCreators = scrapedItem["creators"] as? [[String: Any]] {
                        XCTAssertEqual(scrapedCreators.count, expectedItem.creators.count, "Test case \(index), item \(itemIndex): Wrong number of creators")
                        
                        for (creatorIndex, (scrapedCreator, expectedCreator)) in zip(scrapedCreators, expectedItem.creators).enumerated() {
                            XCTAssertEqual(scrapedCreator["firstName"] as? String, expectedCreator.firstName, "Test case \(index), item \(itemIndex), creator \(creatorIndex): Wrong first name")
                            XCTAssertEqual(scrapedCreator["lastName"] as? String, expectedCreator.lastName, "Test case \(index), item \(itemIndex), creator \(creatorIndex): Wrong last name")
                            XCTAssertEqual(scrapedCreator["creatorType"] as? String, expectedCreator.creatorType, "Test case \(index), item \(itemIndex), creator \(creatorIndex): Wrong creator type")
                        }
                    }
                    
                    // Compare other fields
                    XCTAssertEqual(scrapedItem["date"] as? String, expectedItem.date, "Test case \(index), item \(itemIndex): Wrong date")
                    XCTAssertEqual(scrapedItem["ISSN"] as? String, expectedItem.ISSN, "Test case \(index), item \(itemIndex): Wrong ISSN")
                    XCTAssertEqual(scrapedItem["language"] as? String, expectedItem.language, "Test case \(index), item \(itemIndex): Wrong language")
                    XCTAssertEqual(scrapedItem["libraryCatalog"] as? String, expectedItem.libraryCatalog, "Test case \(index), item \(itemIndex): Wrong library catalog")
                    
                    // Compare blog-specific fields if present
                    if let blogTitle = expectedItem.blogTitle {
                        XCTAssertEqual(scrapedItem["blogTitle"] as? String, blogTitle, "Test case \(index), item \(itemIndex): Wrong blog title")
                    }
                }
                
                expectation.fulfill()
            }
            
            // Load the test article URL
            guard let url = URL(string: testCase.url) else {
                XCTFail("Invalid URL: \(testCase.url)")
                return
            }
            print("Loading URL: \(url)")
            let request = URLRequest(url: url)
            webView.load(request)
            
            // Wait for the page to load and scraping to complete
            print("Waiting for page to load...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                print("Starting page scrape...")
                webView.scrapePage()
            }
            
            // Wait for scraping to complete
            print("Waiting for scraping to complete...")
            wait(for: [expectation], timeout: 30.0)
        }
    }
}

// MARK: - Mock Delegate
class MockZoteroWebViewDelegate: NSObject, ZoteroWebViewDelegate {
    var detectedType: String?
    var scrapedItems: [[String: Any]]?
    var error: Error?
    var onScrapeComplete: ([[String: Any]]) -> Void = { _ in }
    
    func zoteroWebView(_ webView: ZoteroWebView, didDetectType type: String) {
        detectedType = type
    }
    
    func zoteroWebView(_ webView: ZoteroWebView, didScrapeItems items: [[String: Any]]) {
        scrapedItems = items
        onScrapeComplete(items)
    }
    
    func zoteroWebView(_ webView: ZoteroWebView, didFailWithError error: Error) {
        self.error = error
    }
} 
