import XCTest
import WebKit
@testable import BEZoteroTranslators

final class BEZoteroTranslatorsTests: XCTestCase {
    private var webView: WKWebView!
    private var manager: ZoteroManager!
    private var pageLoadExpectation: XCTestExpectation?
    
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
    
    override func tearDown() {
        super.tearDown()
        // Clean up any remaining translators
        TranslatorRegistry.shared.clearTranslators()
        manager?.cleanup()
        manager = nil
        webView = nil
        pageLoadExpectation = nil
    }
    
    func testZoteroManagerInitialization() async throws {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        manager = ZoteroManager(webView: webView)
        XCTAssertNotNil(manager)
        
        // Wait for runtime to load
        try await manager.loadZoteroRuntime()
    }
    
    func testWashingtonPostArticle() async throws {
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
            
            // Create new instances for each test case
            webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
            manager = ZoteroManager(webView: webView)
            
            // Load the translator
            print("Loading translator...")
            try await manager.loadTranslator(translator.getCode())
            
            // Load the test article URL
            guard let url = URL(string: testCase.url) else {
                XCTFail("Invalid URL: \(testCase.url)")
                return
            }
            print("Loading URL: \(url)")
            
            // Create expectation for page load
            pageLoadExpectation = expectation(description: "Page load completed")
            
            // Load the page
            let request = URLRequest(url: url)
            webView.load(request)
            
            // Wait for page load with timeout
            await fulfillment(of: [pageLoadExpectation!], timeout: 30.0)
            
            // Start scraping (this will now wait for the page to load)
            print("Starting page scrape...")
            let items = try await manager.scrapePage()
            
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
        }
    }
    
    func testPageLoadError() async throws {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        manager = ZoteroManager(webView: webView)
        
        // Create expectation for page load failure
        pageLoadExpectation = expectation(description: "Page load failed")
        
        // Try to load an invalid URL
        let request = URLRequest(url: URL(string: "https://invalid-url-that-does-not-exist.com")!)
        webView.load(request)
        
        // Wait for page load failure with timeout
        await fulfillment(of: [pageLoadExpectation!], timeout: 30.0)
        
        // Attempt to scrape should fail with page load error
        do {
            _ = try await manager.scrapePage()
            XCTFail("Expected page load error")
        } catch ZoteroError.pageLoadFailed {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - WKNavigationDelegate
extension BEZoteroTranslatorsTests: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoadExpectation?.fulfill()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pageLoadExpectation?.fulfill()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        pageLoadExpectation?.fulfill()
    }
} 
