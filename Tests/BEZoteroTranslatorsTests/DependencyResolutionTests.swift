import XCTest
@testable import BEZoteroTranslators

@MainActor
final class DependencyResolutionTests: XCTestCase {
    
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
}
