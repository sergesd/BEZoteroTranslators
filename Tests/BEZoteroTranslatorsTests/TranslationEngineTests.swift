import XCTest
import WebKit
@testable import BEZoteroTranslators

@MainActor
final class TranslationEngineTests: XCTestCase {
    
    /// Test PubMed single reference fetch
    func testPubMedOneRefFetch() async throws {
        print("🧪 Testing PubMed single reference fetch...")
        
        // Get test translators folder
        let testBundle = Bundle(for: type(of: self))
        guard let translatorsRootFolder = testBundle.resourceURL?
            .appendingPathComponent("Translators") else {
            XCTFail("Could not find test translators folder")
            return
        }
        
        // Create temp attachments folder
//        let tempAttachmentsFolder = FileManager.default.temporaryDirectory
//            .appendingPathComponent("Test-Attachments-\(UUID().uuidString)")
//        try FileManager.default.createDirectory(at: tempAttachmentsFolder, withIntermediateDirectories: true)
//        
//        defer {
//            // Clean up
//            try? FileManager.default.removeItem(at: tempAttachmentsFolder)
//        }
        
        let zoteroTranslators = try await ZoteroTranslators(
            translatorsRootFolder: translatorsRootFolder,
            enableAttachmentDownloading: false,
            attachmentsFolderURL: nil
        )
        
        // Set up expectations
        var translationCompleted = false
        var receivedItem: [String: Any]?
        
        zoteroTranslators.onTranslationResult = { item in
            print("✅ Translation completed with item: \(item)")
            translationCompleted = true
            receivedItem = item
        }
        
        zoteroTranslators.onSelectItems = { items in
            print("🔧 Items available for selection: \(items)")
            // For single reference test, we shouldn't get here
            XCTFail("Should not need item selection for single reference")
        }
        
        zoteroTranslators.onTranslationProgress = { progress in
            print("🔄 Translation progress: \(progress)")
        }
        
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
        
        // Process the web page
        try await zoteroTranslators.processWeb(
            title: "Test Page Title",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/30226337/")!,
            html: testHTML,
            cookies: "session=abc123",
            frames: [],
            userAgent: "Mozilla/5.0...",
            referrer: "https://google.com"
        )
        
        // Add assertions
        XCTAssertTrue(translationCompleted, "Translation should complete")
        XCTAssertNotNil(receivedItem, "Should receive a translation result")
        
        print("✅ PubMed single reference test completed")
    }
}
