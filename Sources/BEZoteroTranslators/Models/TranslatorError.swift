import Foundation

/// Translator-specific errors
enum TranslatorError: Error, LocalizedError {
    case translatorsNotInstalled
    case indexNotFound
    case invalidIndexData
    case translatorNotFound
    case invalidTranslatorData
    case dependencyNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .translatorsNotInstalled:
            return "Translators are not installed. Please install them first."
        case .indexNotFound:
            return "Translator index file not found."
        case .invalidIndexData:
            return "Invalid translator index data."
        case .translatorNotFound:
            return "Translator not found."
        case .invalidTranslatorData:
            return "Invalid translator data."
        case .dependencyNotFound(let id):
            return "Dependency translator not found: \(id)"
        }
    }
}
