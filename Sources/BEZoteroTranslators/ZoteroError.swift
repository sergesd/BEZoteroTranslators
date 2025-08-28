import Foundation

public enum ZoteroError: LocalizedError {
    case runtimeLoadFailed(String)
    case translatorLoadFailed(String)
    case detectionFailed(String)
    case scrapingFailed(String)
    case pageLoadFailed(String)
    case invalidURL(String)
    case noTranslatorFound(String)
    case translationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .runtimeLoadFailed(let message):
            return "Failed to load Zotero runtime: \(message)"
        case .translatorLoadFailed(let message):
            return "Failed to load translator: \(message)"
        case .detectionFailed(let message):
            return "Failed to detect page type: \(message)"
        case .scrapingFailed(let message):
            return "Failed to scrape page: \(message)"
        case .pageLoadFailed(let message):
            return "Failed to load page: \(message)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .noTranslatorFound(let url):
            return "No translator found for URL: \(url)"
        case .translationFailed(let reason):
            return "Translation failed: \(reason)"
        }
    }
} 