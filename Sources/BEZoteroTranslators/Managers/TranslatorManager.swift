import Foundation

/// Enhanced translator management system using index-based URL matching
/// Expects translators folder to be populated by the app using BEZoteroTranslatorsInstaller
final class TranslatorManager {
    
    // MARK: - Types
    
    /// Enhanced translator entry from index.json
    struct EnhancedTranslatorEntry: Codable, Hashable {
        public let id: String
        public let fileName: String
        public let target: String
        public let priority: Int
        public let translatorType: Int
        
        // Implement Hashable
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        public static func == (lhs: EnhancedTranslatorEntry, rhs: EnhancedTranslatorEntry) -> Bool {
            return lhs.id == rhs.id
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
        
        /// Get translator types as array (handles combined types like 12 = Web + Search)
        public var types: [TranslatorType] {
            return TranslatorType.types(from: translatorType)
        }
        
        /// Get primary translator type (first type found, for backward compatibility)
        public var primaryType: TranslatorType {
            return types.first ?? .web
        }
        
        /// Get human-readable description of translator types
        public var typeDescription: String {
            return TranslatorType.description(for: translatorType)
        }
    }
    
    /// Translator types (matching Zotero's bit flag system)
    enum TranslatorType: Int, CaseIterable {
        case `import` = 1    // 2^0 = 1
        case export = 2      // 2^1 = 2  
        case web = 4         // 2^2 = 4
        case search = 8      // 2^3 = 8
        
        public var description: String {
            switch self {
            case .import: return "Import"
            case .export: return "Export"
            case .web: return "Web"
            case .search: return "Search"
            }
        }
        
        /// Check if this type is included in a combined type value
        /// - Parameter combinedType: The combined type value (e.g., 12 for Web + Search)
        /// - Returns: True if this type is included in the combined type
        func isIncluded(in combinedType: Int) -> Bool {
            return (combinedType & self.rawValue) != 0
        }
        
        /// Get all individual types from a combined type value
        /// - Parameter combinedType: The combined type value
        /// - Returns: Array of individual types
        static func types(from combinedType: Int) -> [TranslatorType] {
            return TranslatorType.allCases.filter { $0.isIncluded(in: combinedType) }
        }
        
        /// Get description for a combined type value
        /// - Parameter combinedType: The combined type value
        /// - Returns: Human-readable description of the combined types
        static func description(for combinedType: Int) -> String {
            let types = types(from: combinedType)
            return types.map { $0.description }.joined(separator: " + ")
        }
    }
    
    enum TranslatorError: Error, LocalizedError {
        case indexNotFound
        case invalidIndexData
        case translatorNotFound
        case invalidTranslatorData
        case translatorsNotInstalled
        
        public var errorDescription: String? {
            switch self {
            case .indexNotFound:
                return "Enhanced index.json not found - translators may not be installed"
            case .invalidIndexData:
                return "Invalid index data"
            case .translatorNotFound:
                return "Translator not found"
            case .invalidTranslatorData:
                return "Invalid translator data"
            case .translatorsNotInstalled:
                return "Translators are not installed - use BEZoteroTranslatorsInstaller first"
            }
        }
    }
    
    // MARK: - Properties
    
    /// The folder where translators are stored (expected to be populated by app)
    public let translatorsFolder: URL
    
    /// Enhanced index data for fast URL matching
    private var enhancedIndex: [EnhancedTranslatorEntry] = []
    
    /// Cache for dependency resolution
    private var dependencyCache: [String: Set<String>] = [:]
    
    // MARK: - Initialization
    
    public init(translatorsRootFolder: URL) throws {
        self.translatorsFolder = translatorsRootFolder.appendingPathComponent("Translators")
        
        // Verify translators are installed
        try verifyTranslatorsInstalled()
        
        // Load enhanced index
        try loadEnhancedIndex()
        
        print("TranslatorManager: Initialized with \(enhancedIndex.count) translators")
    }
    
    // MARK: - Public Methods
    
    /// Get translators matching a URL with dependencies
    /// Returns sorted by priority (highest first) and includes all dependencies
    public func translators(matching url: String, types: Set<TranslatorType> = Set(TranslatorType.allCases)) async throws -> [EnhancedTranslatorEntry] {
        
        // Find matching translators
        let matching = enhancedIndex.filter { entry in
            // Check if any of the entry's types match the requested types
            let entryTypes = Set(entry.types)
            guard !entryTypes.isDisjoint(with: types) else { return false }
            return entry.matches(url: url)
        }
        
        // Sort by priority (highest first)
        let sorted = matching.sorted { $0.priority > $1.priority }
        
        print("TranslatorManager: Found \(sorted.count) translators matching URL: \(url)")
        
        // Load dependencies and return all translators
        return try await loadTranslatorsWithDependencies(translators: sorted)
    }
    
    /// Load a specific translator by ID
    public func loadTranslator(id: String) async throws -> String {
        
        guard let entry = enhancedIndex.first(where: { $0.id == id }) else {
            throw TranslatorError.translatorNotFound
        }
        
        let translatorFile = translatorsFolder.appendingPathComponent(entry.fileName)
        
        guard let data = try? Data(contentsOf: translatorFile),
              let content = String(data: data, encoding: .utf8) else {
            throw TranslatorError.invalidTranslatorData
        }
        
        return content
    }
    
    /// Load translator metadata (JSON header) from translator code
    public func loadTranslatorMetadata(from code: String) throws -> [String: Any] {
        // Find the first JSON object in the translator code (the header)
        guard let startIndex = code.firstIndex(of: "{") else {
            throw TranslatorError.invalidTranslatorData
        }
        
        var braceCount = 0
        var endIndex = startIndex
        
        for (index, char) in code[startIndex...].enumerated() {
            if char == "{" {
                braceCount += 1
            } else if char == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    endIndex = code.index(startIndex, offsetBy: index)
                    break
                }
            }
        }
        
        let jsonString = String(code[startIndex...endIndex])
        
        guard let jsonData = jsonString.data(using: .utf8),
              let metadata = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw TranslatorError.invalidTranslatorData
        }
        
        return metadata
    }
    
    /// Get all translator IDs (including dependencies) for a given URL
    public func translatorIds(matching url: String, types: Set<TranslatorType> = Set(TranslatorType.allCases)) async throws -> [String] {
        let translators = try await self.translators(matching: url, types: types)
        return translators.map { $0.id }
    }
    
    // MARK: - Private Methods
    
    private func verifyTranslatorsInstalled() throws {
        let indexFile = translatorsFolder.appendingPathComponent("index.json")
        let commitHashFile = translatorsFolder.appendingPathComponent("commit_hash")
        
        guard FileManager.default.fileExists(atPath: indexFile.path) && 
              FileManager.default.fileExists(atPath: commitHashFile.path) else {
            throw TranslatorError.translatorsNotInstalled
        }
    }
    
    private func findDependencies(for translator: EnhancedTranslatorEntry) async throws -> Set<String> {
        // Check cache first
        if let cached = dependencyCache[translator.id] {
            return cached
        }
        
        let translatorCode = try await loadTranslator(id: translator.id)
        
        // Regex pattern to match setTranslator() calls with UUIDs
        // Pattern: setTranslator(['"]([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})['"])
        let pattern = #"setTranslator\(['"]([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})['"]\)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Set<String>()
        }
        
        let range = NSRange(translatorCode.startIndex..<translatorCode.endIndex, in: translatorCode)
        let matches = regex.matches(in: translatorCode, range: range)
        
        var dependencies = Set<String>()
        for match in matches {
            if match.numberOfRanges > 1 {
                let dependencyRange = match.range(at: 1)
                if let range = Range(dependencyRange, in: translatorCode) {
                    let dependencyId = String(translatorCode[range])
                    dependencies.insert(dependencyId)
                }
            }
        }
        
        // Cache the result
        dependencyCache[translator.id] = dependencies
        
        print("TranslatorManager: Found \(dependencies.count) dependencies for translator \(translator.id)")
        return dependencies
    }
    
    /// Load translators with dependencies recursively
    private func loadTranslatorsWithDependencies(translators: [EnhancedTranslatorEntry]) async throws -> [EnhancedTranslatorEntry] {
        var allTranslators = Set<EnhancedTranslatorEntry>()
        var processedIds = Set<String>()
        
        func loadDependenciesRecursively(for translator: EnhancedTranslatorEntry) async throws {
            guard !processedIds.contains(translator.id) else { return }
            processedIds.insert(translator.id)
            
            // Add the translator itself
            allTranslators.insert(translator)
            
            // Find and load dependencies
            let dependencies = try await findDependencies(for: translator)
            for dependencyId in dependencies {
                if let dependencyEntry = enhancedIndex.first(where: { $0.id == dependencyId }) {
                    try await loadDependenciesRecursively(for: dependencyEntry)
                }
            }
        }
        
        // Load all translators and their dependencies
        for translator in translators {
            try await loadDependenciesRecursively(for: translator)
        }
        
        return Array(allTranslators)
    }
    
    private func loadEnhancedIndex() throws {
        let indexFile = translatorsFolder.appendingPathComponent("index.json")
        
        guard let data = try? Data(contentsOf: indexFile) else {
            throw TranslatorError.indexNotFound
        }
        
        do {
            enhancedIndex = try JSONDecoder().decode([EnhancedTranslatorEntry].self, from: data)
             
            print("TranslatorManager: Loaded \(enhancedIndex.count) translators from enhanced index")
            
        } catch {
            throw TranslatorError.invalidIndexData
        }
    }
}
