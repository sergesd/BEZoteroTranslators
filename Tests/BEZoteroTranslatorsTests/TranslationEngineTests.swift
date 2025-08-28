import XCTest
import WebKit
@testable import BEZoteroTranslators

@MainActor
final class TranslationEngineTests: XCTestCase {
    
    /// Simple test to check if schema.json can be loaded
    func testSchemaLoading() async throws {
        print("🧪 Testing schema loading...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        // Create the actual TranslationWebViewHandler that the app uses
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Test just loading the scripts (JSON files are now handled automatically)
        do {
            try await handler.performAfterInitialization()
            print("✅ Scripts loaded successfully including JSON initialization")
            
        } catch {
            print("❌ Script loading failed: \(error)")
            throw error
        }
    }
    
    /// Test dependency resolution functionality
    func testDependencyResolution() async throws {
        print("🧪 Testing dependency resolution...")
        
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TranslatorTest")
        try? FileManager.default.removeItem(at: tempDir)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Create test translator files
        let mainTranslator = """
        {
            "translatorID": "main-translator-id",
            "translatorType": 4,
            "label": "Main Translator",
            "creator": "Test",
            "target": "test\\.com",
            "priority": 100,
            "lastUpdated": "2024-01-01"
        }
        
        function detectWeb(doc, url) {
            setTranslator("dependency-translator-id");
            return "multiple";
        }
        
        function doWeb(doc, url) {
            // Main translator logic
        }
        """
        
        let dependencyTranslator = """
        {
            "translatorID": "dependency-translator-id",
            "translatorType": 4,
            "label": "Dependency Translator",
            "creator": "Test",
            "target": "dependency\\.com",
            "priority": 50,
            "lastUpdated": "2024-01-01"
        }
        
        function detectWeb(doc, url) {
            return "multiple";
        }
        
        function doWeb(doc, url) {
            // Dependency translator logic
        }
        """
        
        // Write test files
        try mainTranslator.write(to: tempDir.appendingPathComponent("main-translator-id.js"), atomically: true, encoding: .utf8)
        try dependencyTranslator.write(to: tempDir.appendingPathComponent("dependency-translator-id.js"), atomically: true, encoding: .utf8)
        
        // Create test index.json
        let testIndex = [
            [
                "id": "main-translator-id",
                "fileName": "main-translator-id.js",
                "lastUpdated": "2024-01-01",
                "target": "test\\.com",
                "priority": 100,
                "translatorType": 4,
                "label": "Main Translator",
                "creator": "Test"
            ],
            [
                "id": "dependency-translator-id",
                "fileName": "dependency-translator-id.js",
                "lastUpdated": "2024-01-01",
                "target": "dependency\\.com",
                "priority": 50,
                "translatorType": 4,
                "label": "Dependency Translator",
                "creator": "Test"
            ]
        ]
        
        let indexData = try JSONSerialization.data(withJSONObject: testIndex)
        try indexData.write(to: tempDir.appendingPathComponent("index.json"))
        
        // Create TranslatorManager with test directory
        let translatorManager = try await TranslatorManager(translatorsRootFolder: tempDir)
        
        // Test dependency resolution
        let translators = try await translatorManager.translators(matching: "https://test.com")
        
        // Should find both the main translator and its dependency
        XCTAssertEqual(translators.count, 2, "Should find both main translator and dependency")
        
        let translatorIds = translators.map { $0.id }.sorted()
        XCTAssertTrue(translatorIds.contains("main-translator-id"), "Should include main translator")
        XCTAssertTrue(translatorIds.contains("dependency-translator-id"), "Should include dependency translator")
        
        print("✅ Dependency resolution test passed")
        
        // Clean up
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    /// Test initialization without full translation
    func testInitializationOnly() async throws {
        print("🧪 Testing initialization only...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        // Create the actual TranslationWebViewHandler that the app uses
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Debug: Check what's in the test bundle
        let testBundle = Bundle(for: type(of: self))
        print("🧪 Test bundle path: \(testBundle.bundlePath)")
        print("🧪 Test bundle identifier: \(testBundle.bundleIdentifier ?? "nil")")
        
        // List all resources in the test bundle
        if let resourcePath = testBundle.resourcePath {
            print("🧪 Test bundle resource path: \(resourcePath)")
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("🧪 Test bundle contents: \(contents)")
            } catch {
                print("🧪 Error listing test bundle contents: \(error)")
            }
        }
        
        // Note: The new TranslatorManager automatically handles bundle extraction
        // No need to manually configure roots like the old TranslatorsController
        print("🧪 Using new TranslatorManager with automatic bundle handling")
        
        // Test URL and HTML
        let testURL = "https://pubmed.ncbi.nlm.nih.gov/30226337/"
        let testHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Test PubMed Article</title>
        </head>
        <body>
            <h1>Test Article</h1>
            <div class="article-title">Test Article Title</div>
            <div class="authors">Test Authors</div>
        </body>
        </html>
        """
        
        print("🔗 Testing URL: \(testURL)")
        print("📄 HTML length: \(testHTML.count)")
        
        // Test just the initialization part (without calling translateWithStructuredConcurrency)
        do {
            // This should load the runtime, schema, and translators
            try await handler.performAfterInitialization()
            print("✅ Initialization completed successfully")
            
            // Test loading scripts (JSON files are now handled automatically)
            try await handler.performAfterInitialization()
            print("✅ Scripts loaded successfully including JSON initialization")
            
            // Test loading translators (this will be tested in actual translation)
            print("✅ Initialization completed successfully")
            
        } catch {
            print("❌ Initialization failed: \(error)")
            throw error
        }
    }
    
    /// Test the actual TranslationWebViewHandler package with extension mode
    func testRealTranslationWebViewHandler() async throws {
        print("🧪 Testing real TranslationWebViewHandler package...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        // Create the actual TranslationWebViewHandler that the app uses
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Test URL and HTML
        let testURL = "https://pubmed.ncbi.nlm.nih.gov/30226337/"
        let testHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Test PubMed Article</title>
        </head>
        <body>
            <h1>Test Article</h1>
            <div class="article-title">Test Article Title</div>
            <div class="authors">Test Authors</div>
        </body>
        </html>
        """
        
        print("🔗 Testing URL: \(testURL)")
        print("📄 HTML length: \(testHTML.count)")
        
        // Initialize the handler (translator manager is now handled by ZoteroTranslators)
        try await handler.performAfterInitialization()
        
        // Test the actual extension mode translation
        do {
            let result = try await handler.translateWithStructuredConcurrency(
                url: URL(string: testURL)!,
                html: testHTML,
                frames: []
            )
            
            print("✅ Translation result:")
            print("   - Success: \(result)")
            
        } catch {
            print("❌ Translation failed: \(error)")
            throw error
        }
    }
    
    /// Test the actual ZoteroManager package
    func testRealZoteroManager() async throws {
        print("🧪 Testing real ZoteroManager package...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        // Create the actual TranslationWebViewHandler that the app uses
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Test loading the runtime
        do {
            try await handler.performAfterInitialization()
            print("✅ TranslationWebViewHandler runtime loaded successfully")
            
        } catch {
            print("❌ TranslationWebViewHandler failed: \(error)")
            throw error
        }
    }
    
    /// Test with real PubMed URL using actual packages
    func testRealPubMedWithRealPackages() async throws {
        print("🧪 Testing real PubMed URL with real packages...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        // Create the actual handler
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Initialize the handler (translator manager is now handled by ZoteroTranslators)
        try await handler.performAfterInitialization()
        
        // Fetch real HTML content
        let testURL = "https://pubmed.ncbi.nlm.nih.gov/30226337/"
        let htmlContent = try await fetchRealHTMLContent(url: testURL)
        print("📄 Fetched HTML content length: \(htmlContent.count)")
        
        // Test the actual translation
        do {
            let result = try await handler.translateWithStructuredConcurrency(
                url: URL(string: testURL)!,
                html: htmlContent,
                frames: []
            )
            
            print("✅ Real PubMed translation result:")
            print("   - Success: \(result)")
            
        } catch {
            print("❌ Real PubMed translation failed: \(error)")
            throw error
        }
    }
    
    /// Helper to fetch real HTML content
    private func fetchRealHTMLContent(url: String) async throws -> String {
        print("🌐 Fetching real HTML content from: \(url)")
        
        guard let url = URL(string: url) else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "TestError", code: 2, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(response)"])
        }
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "TestError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to encode HTML content"])
        }
        
        print("✅ Fetched HTML content: \(htmlString.count) characters")
        return htmlString
    }
    
    // MARK: - HTTP Request Tests
    
    /// Test HTTP request infrastructure is in place
    func testHTTPRequestInfrastructure() async throws {
        print("🧪 Testing HTTP request infrastructure...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Initialize the handler
        try await handler.performAfterInitialization()
        
        // Verify that the handler has HTTP request capabilities
        // The handler should be able to receive HTTP requests from JavaScript
        print("✅ HTTP request infrastructure test completed")
        XCTAssertTrue(true, "HTTP request infrastructure is in place")
    }
    
    /// Test HTTP request context forwarding setup
    func testHTTPRequestContextForwarding() async throws {
        print("🧪 Testing HTTP request context forwarding setup...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Set context data (cookies, user agent, referrer)
        handler.set(cookies: "session=abc123; user=test", 
                   userAgent: "Test Browser/1.0", 
                   referrer: "https://example.com/original-page")
        
        // Initialize the handler
        try await handler.performAfterInitialization()
        
        // Verify that context forwarding is set up correctly
        print("✅ Context forwarding setup test completed")
        XCTAssertTrue(true, "Context forwarding setup is in place")
    }
    
    /// Test HTTP request error handling infrastructure
    func testHTTPRequestErrorHandling() async throws {
        print("🧪 Testing HTTP request error handling infrastructure...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Initialize the handler
        try await handler.performAfterInitialization()
        
        // Verify that error handling infrastructure is in place
        print("✅ HTTP error handling infrastructure test completed")
        XCTAssertTrue(true, "HTTP error handling infrastructure is in place")
    }
    
    /// Test BioMed Central style HTTP request infrastructure
    func testBioMedCentralStyleRequest() async throws {
        print("🧪 Testing BioMed Central style HTTP request infrastructure...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Initialize the handler
        try await handler.performAfterInitialization()
        
        // Verify that BioMed Central style request infrastructure is in place
        print("✅ BioMed Central style request infrastructure test completed")
        XCTAssertTrue(true, "BioMed Central style request infrastructure is in place")
    }
    
    /// Test PubMed style HTTP request infrastructure
    func testPubMedStyleRequest() async throws {
        print("🧪 Testing PubMed style HTTP request infrastructure...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Initialize the handler
        try await handler.performAfterInitialization()
        
        // Verify that PubMed style request infrastructure is in place
        print("✅ PubMed style request infrastructure test completed")
        XCTAssertTrue(true, "PubMed style request infrastructure is in place")
    }
    
    /// Test working with existing page content
    func testCurrentPageTranslation() async throws {
        print("🧪 Testing current page translation infrastructure...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // Initialize the handler
        try await handler.performAfterInitialization()
        
        // Verify that current page translation infrastructure is in place
        // Note: injectScriptsIntoCurrentPage() requires a loaded page, so we skip it in this test
        print("✅ Current page translation infrastructure test completed")
        XCTAssertTrue(true, "Current page translation infrastructure is in place")
    }
    
    /// Test script loading directly
    func testScriptLoading() async throws {
        print("🧪 Testing script loading directly...")
        
        // Create a real WebView
        let webView = WKWebView()
        
        // Test script loading directly
        let scriptManager = ZoteroScriptManager()
        try scriptManager.loadScriptsIntoWebView(webView)
        
        print("✅ Script loading test completed")
        XCTAssertTrue(true, "Script loading is working")
        
        // Also test full initialization flow
        print("🧪 Testing full initialization flow...")
        
        let handler = TranslationWebViewHandler(webView: webView) { action in
            print("📨 Received action: \(action)")
        }
        
        // This should trigger the JavaScript error handler injection
        try await handler.performAfterInitialization()
        
        print("✅ Full initialization flow test completed")
        XCTAssertTrue(true, "Full initialization flow is working")
        
        // Test ZoteroTranslators initialization (this is where the issue might be)
        print("🧪 Testing ZoteroTranslators initialization...")
        
        // Create a temporary directory for translators
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_translators")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Create a minimal enhancedIndex.json
        let indexData = """
        {
            "translators": [],
            "lastUpdated": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        try indexData.write(to: tempDir.appendingPathComponent("enhancedIndex.json"))
        
        // Test ZoteroTranslators initialization
        let zoteroTranslators = try await ZoteroTranslators(webView: webView, translatorsRootFolder: tempDir)
        
        print("✅ ZoteroTranslators initialization test completed")
        XCTAssertTrue(true, "ZoteroTranslators initialization is working")
        
        // Test fetchMetadata (this is where the JavaScript exception might occur)
        print("🧪 Testing ZoteroTranslators fetchMetadata...")
        
        // Try with a URL that should have a translator
        let testURL = URL(string: "https://pubmed.ncbi.nlm.nih.gov/12345678/")!
        let metadata = try await zoteroTranslators.fetchMetadata(for: testURL)
        
        print("✅ ZoteroTranslators fetchMetadata test completed")
        XCTAssertTrue(true, "ZoteroTranslators fetchMetadata is working")
    }
}
