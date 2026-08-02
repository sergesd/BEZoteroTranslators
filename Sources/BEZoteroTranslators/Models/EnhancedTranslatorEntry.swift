import Foundation

/// Enhanced translator entry with cached data
struct EnhancedTranslatorEntry: Hashable, Decodable {
    public let id: String
    public let fileName: String
    public let target: String
    public let priority: Int
    public let translatorType: Int
    public var dependencies: Set<EnhancedTranslatorEntry>? = nil
    public var code: String? = nil // Cached JS code
    public var metadata: [String: Any]? = nil // Cached metadata from file
    
    /// Custom initializer
    public init(id: String, fileName: String, target: String, priority: Int, translatorType: Int, dependencies: Set<EnhancedTranslatorEntry>? = nil, code: String? = nil, metadata: [String: Any]? = nil) {
        self.id = id
        self.fileName = fileName
        self.target = target
        self.priority = priority
        self.translatorType = translatorType
        self.dependencies = dependencies
        self.code = code
        self.metadata = metadata
    }
    
    /// Get translator types as an array
    public var types: [TranslatorType] {
        return TranslatorType.types(from: translatorType)
    }
    
    /// Get human-readable description of translator types
    public var typeDescription: String {
        return TranslatorType.description(for: translatorType)
    }
    
    /// Check if this translator can handle the given URL
    public func matches(url: String) -> Bool {
        guard !target.isEmpty else { return false }
        
        do {
            let regex = try NSRegularExpression(pattern: target)
            let range = NSRange(url.startIndex..<url.endIndex, in: url)
            return regex.firstMatch(in: url, range: range) != nil
        } catch {
            print("TranslatorManager: Invalid regex pattern '\(target)' for translator '\(id)': \(error)")
            return false
        }
    }
    
    // MARK: - Equatable & Hashable Implementation
    
    /// Equatable conformance - compares only by unique ID
    public static func == (lhs: EnhancedTranslatorEntry, rhs: EnhancedTranslatorEntry) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Hashable conformance - hashes only by unique ID
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Codable Implementation
    
    /// Coding keys for JSON serialization (excludes cached data)
    private enum CodingKeys: String, CodingKey {
        case id, fileName, target, priority
        case translatorType = "type"
    }
    
    /// Custom decoder - only decodes basic properties, sets cached data to nil
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.target = try container.decode(String.self, forKey: .target)
        self.priority = try container.decode(Int.self, forKey: .priority)
        self.translatorType = try container.decode(Int.self, forKey: .translatorType)
        self.dependencies = nil
        self.code = nil
        self.metadata = nil
    }
}

// MARK: - EnhancedTranslatorEntry Extension

extension EnhancedTranslatorEntry {
    /// Load code and dependencies for this translator
    mutating func loadCodeAndDependencies(
        translatorsFolder: URL,
        cache: inout [String: EnhancedTranslatorEntry],
        enhancedIndex: [EnhancedTranslatorEntry]
    ) async throws {
        // Load code from file (always needed for uncached translators)
        let translatorFile = translatorsFolder.appendingPathComponent(self.fileName)
        guard let data = try? Data(contentsOf: translatorFile),
              let content = String(data: data, encoding: .utf8) else {
            throw TranslatorError.invalidTranslatorData
        }
        
        // Parse metadata from JSON header
        self.metadata = try Self.parseMetadata(from: content)
        
        // Store the entire raw content as code (like ZShare does)
        self.code = content
        
        // Load dependencies
        let dependencyIds = try Self.parseDependencyIds(from: self.code!)
        var dependencyEntries = Set<EnhancedTranslatorEntry>()
        
        for dependencyId in dependencyIds {
            // Check cache first
            if let cached = cache[dependencyId] {
                dependencyEntries.insert(cached)
            } else {
                // Load from enhancedIndex and recurse
                guard let entry = enhancedIndex.first(where: { $0.id == dependencyId }) else {
                    continue
                }
                var dependency = entry
                try await dependency.loadCodeAndDependencies(
                    translatorsFolder: translatorsFolder,
                    cache: &cache,
                    enhancedIndex: enhancedIndex
                )
                cache[dependencyId] = dependency
                dependencyEntries.insert(dependency)
            }
        }
        
        self.dependencies = dependencyEntries
    }
    
    /// Parse metadata from JSON header at the top of translator file
    static func parseMetadata(from content: String) throws -> [String: Any] {
        guard let metadataEndIndex = findMetadataEndIndex(from: content),
              let metadataData = content[content.startIndex..<metadataEndIndex].data(using: .utf8) else {
            throw TranslatorError.invalidTranslatorData
        }
        
        do {
            let metadata = try JSONSerialization.jsonObject(with: metadataData, options: .allowFragments)
            guard let metadataDict = metadata as? [String: Any] else {
                throw TranslatorError.invalidTranslatorData
            }
            return metadataDict
        } catch {
            throw TranslatorError.invalidTranslatorData
        }
    }
    
    /// Find the end index of the JSON metadata block at the top of the file
    /// Uses brace counting to find the closing brace of the JSON object
    private static func findMetadataEndIndex(from string: String) -> String.Index? {
        var count = 0
        for (index, character) in string.enumerated() {
            if character == "{" {
                count += 1
            } else if character == "}" {
                count -= 1
            }
            
            if count == 0 {
                return string.index(string.startIndex, offsetBy: index + 1)
            }
        }
        return nil
    }
    
    /// Extract only the executable JS code from a translator file
    /// Removes: Test cases (everything after /** BEGIN TEST CASES **/)
    static func extractExecutableCode(from content: String) throws -> String {
        // Find the test cases marker
        if let testCasesStart = content.range(of: "/** BEGIN TEST CASES **/") {
            // Return everything before the test cases marker
            let executableCode = String(content[..<testCasesStart.lowerBound])
            return executableCode.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // No test cases marker found, return the whole file
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// Parse dependency IDs from translator code
    static func parseDependencyIds(from code: String) throws -> Set<String> {
        // Regex pattern to match setTranslator() calls with UUIDs
        // Pattern: setTranslator(['\"]([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})['\"]\)
        let pattern = #"setTranslator\(['\"]([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})['\"]\)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Set<String>()
        }
        
        let range = NSRange(code.startIndex..<code.endIndex, in: code)
        let matches = regex.matches(in: code, range: range)
        
        var dependencies = Set<String>()
        for match in matches {
            if match.numberOfRanges >= 2 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: code) {
                    let dependencyId = String(code[swiftRange])
                    dependencies.insert(dependencyId)
                }
            }
        }
        
        return dependencies
    }
}
