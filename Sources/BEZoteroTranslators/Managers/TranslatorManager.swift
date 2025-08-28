import Foundation
import CryptoKit
import ZIPFoundation

/// Enhanced translator management system using index-based URL matching
/// Handles folder management and fast URL lookup using enhanced index.json
@MainActor
public final class TranslatorManager: ObservableObject {
    
    // MARK: - Types
    
    /// Enhanced translator entry from index.json
    public struct EnhancedTranslatorEntry: Codable, Hashable {
        public let id: String
        public let fileName: String
        public let lastUpdated: String
        public let target: String
        public let priority: Int
        public let translatorType: Int
        public let label: String
        public let creator: String
        
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
                print("TranslatorManager: Invalid regex pattern '\(target)' for translator '\(label)': \(error)")
                return false
            }
        }
        
        /// Get translator type as enum
        public var type: TranslatorType {
            return TranslatorType(rawValue: translatorType) ?? .web
        }
    }
    
    /// Translator types (matching Zotero's enum)
    public enum TranslatorType: Int, CaseIterable {
        case `import` = 1
        case export = 2
        case search = 3
        case web = 4
        
        public var description: String {
            switch self {
            case .import: return "Import"
            case .export: return "Export"
            case .search: return "Search"
            case .web: return "Web"
            }
        }
    }
    

    
    public enum TranslatorError: Error, LocalizedError {
        case folderCreationFailed
        case bundleExtractionFailed
        case indexNotFound
        case invalidIndexData
        case translatorNotFound
        case invalidTranslatorData
        
        public var errorDescription: String? {
            switch self {
            case .folderCreationFailed:
                return "Failed to create translators folder"
            case .bundleExtractionFailed:
                return "Failed to extract translators from bundle"
            case .indexNotFound:
                return "Enhanced index.json not found"
            case .invalidIndexData:
                return "Invalid index data"
            case .translatorNotFound:
                return "Translator not found"
            case .invalidTranslatorData:
                return "Invalid translator data"
            }
        }
    }
    
    // MARK: - Properties
    
    /// The folder where translators are stored
    public let translatorsFolder: URL
    
    /// Enhanced index data for fast URL matching
    private var enhancedIndex: [EnhancedTranslatorEntry] = []
    
    /// Cache for fast URL lookups
    private var urlPatternCache: [String: [EnhancedTranslatorEntry]] = [:]
    
    /// Cache for dependency resolution
    private var dependencyCache: [String: Set<String>] = [:]
    
    /// Bundle containing translator resources
    private let bundle: Bundle = Bundle.module
        
    // MARK: - Initialization
    
    public init(translatorsRootFolder: URL) async throws {
        self.translatorsFolder = translatorsRootFolder.appendingPathComponent("Translators")
        
        print("TranslatorManager: Initializing with folder: \(self.translatorsFolder.path)")
        
        // Create translators folder if needed
        try createTranslatorsFolderIfNeeded()
        
        // Extract translators from bundle if needed
        try await extractTranslatorsFromBundleIfNeeded()
        
        // Load enhanced index
        try loadEnhancedIndex()
        
        print("TranslatorManager: Initialization complete")
    }
    

    
    /// Get translators matching a URL with dependencies
    /// Returns sorted by priority (highest first) and includes all dependencies
    public func translators(matching url: String, types: Set<TranslatorType> = Set(TranslatorType.allCases)) async throws -> [EnhancedTranslatorEntry] {
        
        // Check cache first
        if let cached = urlPatternCache[url] {
            let filtered = cached.filter { types.contains($0.type) }
            // Load dependencies for cached results
            return try await loadTranslatorsWithDependencies(translators: filtered)
        }
        
        // Find matching translators
        let matching = enhancedIndex.filter { entry in
            guard types.contains(entry.type) else { return false }
            return entry.matches(url: url)
        }
        
        // Sort by priority (highest first)
        let sorted = matching.sorted { $0.priority > $1.priority }
        
        // Cache the result
        urlPatternCache[url] = sorted
        
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
    
    /// Find dependencies for a translator by scanning for setTranslator() calls
    /// Uses regex pattern to detect UUID references in setTranslator() calls
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
        
        print("TranslatorManager: Found \(dependencies.count) dependencies for translator \(translator.label)")
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
    
    /// Get all translator IDs (including dependencies) for a given URL
    public func translatorIds(matching url: String, types: Set<TranslatorType> = Set(TranslatorType.allCases)) async throws -> [String] {
        let translators = try await self.translators(matching: url, types: types)
        return translators.map { $0.id }
    }
    

    
    // MARK: - Private Methods
    

    
    private func createTranslatorsFolderIfNeeded() throws {
        let fileManager = FileManager.default
        
        // Create main translators folder
        if !fileManager.fileExists(atPath: translatorsFolder.path) {
            try fileManager.createDirectory(at: translatorsFolder, withIntermediateDirectories: true)
            print("TranslatorManager: Created translators folder")
        }
    }
    
    private func extractTranslatorsFromBundleIfNeeded() async throws {
        let indexFile = translatorsFolder.appendingPathComponent("index.json")
        let commitHashFile = translatorsFolder.appendingPathComponent("commit_hash")
        
        // Check if we already have the files and get current commit hash
        var currentCommitHash: String?
        if FileManager.default.fileExists(atPath: indexFile.path) && FileManager.default.fileExists(atPath: commitHashFile.path) {
            currentCommitHash = try? String(contentsOf: commitHashFile).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Get bundle commit hash
        guard let bundleCommitHashFile = bundle.url(forResource: "commit_hash", withExtension: nil, subdirectory: "Resources/translators") else {
            throw TranslatorError.bundleExtractionFailed
        }
        
        let bundleCommitHash = (try? String(contentsOf: bundleCommitHashFile))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        
        // Check if we need to update (no files exist or commit hash differs)
        if let currentHash = currentCommitHash, currentHash == bundleCommitHash {
            print("TranslatorManager: Translators already extracted and up to date (commit: \(currentHash))")
            return
        }
        
        if let currentHash = currentCommitHash {
            print("TranslatorManager: Updating translators from commit \(currentHash) to \(bundleCommitHash)")
        } else {
            print("TranslatorManager: Extracting translators for the first time (commit: \(bundleCommitHash))")
        }
        
        // Clear existing files if updating
        if currentCommitHash != nil {
            try clearExistingTranslators()
        }
        
        // Extract from bundle
        guard let bundleZipURL = bundle.url(forResource: "translators", withExtension: "zip", subdirectory: "Resources/translators") else {
            throw TranslatorError.bundleExtractionFailed
        }
        
        print("TranslatorManager: Extracting translators from bundle")
        
        // Extract zip using ZIPFoundation
        try FileManager.default.unzipItem(at: bundleZipURL, to: translatorsFolder)
        
        print("TranslatorManager: Translators extracted successfully")
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
    
    private func clearExistingTranslators() throws {
        let fileManager = FileManager.default
        
        // Get all files in the translators folder
        let contents = try fileManager.contentsOfDirectory(at: translatorsFolder, includingPropertiesForKeys: nil)
        
        // Remove all files except the folder itself
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
        
        print("TranslatorManager: Cleared existing translator files")
    }
    
    // MARK: - Zip Extraction
    
    // Note: Zip extraction is now handled by ZipExtractor utility class
}
