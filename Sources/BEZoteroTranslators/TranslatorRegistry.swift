import Foundation

public class TranslatorRegistry {
    public static let shared = TranslatorRegistry()
    
    private var translators: [String: ZoteroTranslator] = [:]
    
    private init() {}
    
    /// Register a translator with the given name and code
    public func registerTranslator(name: String, code: String) throws {
        let translator = try ZoteroTranslator(name: name, code: code)
        translators[name] = translator
    }
    
    /// Register a translator from a file
    public func registerTranslatorFromFile(name: String, fileURL: URL) throws {
        let code = try String(contentsOf: fileURL)
        try registerTranslator(name: name, code: code)
    }
    
    /// Get a registered translator by name
    public func getTranslator(name: String) -> ZoteroTranslator? {
        return translators[name]
    }
    
    /// Get all registered translator names
    public var registeredTranslatorNames: [String] {
        return Array(translators.keys)
    }
    
    /// Clear all registered translators
    public func clearTranslators() {
        translators.removeAll()
    }
} 