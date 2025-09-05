import Foundation

/// Enhanced translator management system using index-based URL matching
/// Expects translators folder to be populated by the app using BEZoteroTranslatorsInstaller
final class TranslatorManager {
    
    /// The folder where translators are stored (expected to be populated by app)
    public let translatorsFolder: URL
    
    /// Enhanced index data for fast URL matching
    private var enhancedIndex: [EnhancedTranslatorEntry] = []
    
    /// Cache for loaded translators (for faster URL matching and dependency resolution)
    private var translatorsCache: [String: EnhancedTranslatorEntry] = [:]
    
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
        
        // First, check cached translators for matches (much faster!)
        let cachedMatching = translatorsCache.values.filter { entry in
            // Check if any of the entry's types match the requested types
            let entryTypes = Set(entry.types)
            guard !entryTypes.isDisjoint(with: types) else { return false }
            return entry.matches(url: url)
        }
        
        var allMatching = cachedMatching
        
        // If no matches in cache, check the full index
        if cachedMatching.isEmpty {
            let fullMatching = enhancedIndex.filter { entry in
                // Check if any of the entry's types match the requested types
                let entryTypes = Set(entry.types)
                guard !entryTypes.isDisjoint(with: types) else { return false }
                return entry.matches(url: url)
            }
            allMatching = fullMatching
        }
        
        // Sort by priority (highest first)
        let sorted = allMatching.sorted { $0.priority > $1.priority }
        
        print("TranslatorManager: Found \(sorted.count) translators matching URL: \(url) (cached: \(cachedMatching.count))")
        
        // Load matching translators (dependencies are loaded automatically by loadTranslator)
        var loadedTranslators: [EnhancedTranslatorEntry] = []
        for translator in sorted {
            let loadedTranslator = try await loadTranslator(id: translator.id)
            loadedTranslators.append(loadedTranslator)
        }
        
        return loadedTranslators
    }
    
    /// Load a specific translator by ID (returns EnhancedTranslatorEntry with dependencies, code, and metadata loaded)
    public func loadTranslator(id: String) async throws -> EnhancedTranslatorEntry {
        // Check cache first
        if let cached = translatorsCache[id] {
            return cached
        }
        
        guard var translator = enhancedIndex.first(where: { $0.id == id }) else {
            throw TranslatorError.translatorNotFound
        }
        
        // Load code and dependencies (always needed for uncached translators)
        try await translator.loadCodeAndDependencies(
            translatorsFolder: translatorsFolder,
            cache: &translatorsCache,
            enhancedIndex: enhancedIndex
        )
        
        // Cache the result
        translatorsCache[id] = translator
        
        // Limit cache size to prevent unlimited memory growth
        if translatorsCache.count > 100 {
            // Remove oldest entries (simple approach: remove first 20 entries)
            let keysToRemove = Array(translatorsCache.keys.prefix(20))
            for key in keysToRemove {
                translatorsCache.removeValue(forKey: key)
            }
        }
        
        return translator
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

