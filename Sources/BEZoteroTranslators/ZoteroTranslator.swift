import Foundation

public struct ZoteroTestCase: Codable {
    public let url: String
    public let items: [ZoteroItem]
}

public struct ZoteroItem: Codable {
    public let itemType: String
    public let title: String
    public let creators: [ZoteroCreator]
    public let date: String?
    public let ISSN: String?
    public let abstractNote: String?
    public let language: String?
    public let libraryCatalog: String?
    public let publicationTitle: String?
    public let blogTitle: String?
    public let url: String?
}

public struct ZoteroCreator: Codable {
    public let firstName: String
    public let lastName: String
    public let creatorType: String
}

public class ZoteroTranslator {
    public let name: String
    private let code: String
    
    public init(name: String, code: String) throws {
        self.name = name
        self.code = code
    }
    
    public func extractTestCases() throws -> [ZoteroTestCase] {
        // Find the test cases section
        guard let testCasesStart = code.range(of: "/** BEGIN TEST CASES **/"),
              let testCasesEnd = code.range(of: "/** END TEST CASES **/") else {
            throw NSError(domain: "ZoteroTranslator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find test cases in translator"])
        }
        
        // Extract the test cases section and convert to valid JSON
        let testCasesSection = code[testCasesStart.upperBound..<testCasesEnd.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "var testCases = ", with: "")
            .replacingOccurrences(of: ";", with: "")
        
        // Parse the JSON
        let decoder = JSONDecoder()
        return try decoder.decode([ZoteroTestCase].self, from: testCasesSection.data(using: .utf8)!)
    }
    
    public func getCode() -> String {
        return code
    }
} 
